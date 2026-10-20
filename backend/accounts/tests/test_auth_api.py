import base64
import json
import re
from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.sessions.models import Session
from django.core import mail
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import EmailChallenge


@override_settings(
    EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
    EMAIL_RESEND_COOLDOWN_SECONDS=0,
)
class AuthApiTestCase(TestCase):
    """Exercise the browser contract, including the anonymous CSRF boundary."""

    base_url = "/api/v1/auth/"
    password = "A-Strong-Student-Password!47"
    email = "student@example.com"

    def setUp(self):
        cache.clear()
        mail.outbox = []
        self.client = APIClient(enforce_csrf_checks=True)
        self.csrf_token = self.get_csrf(self.client)

    def get_csrf(self, client):
        response = client.get(self.base_url + "csrf/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("csrf_token", response.data)
        return response.data["csrf_token"]

    def post(self, endpoint, data=None, *, client=None, csrf_token=None, **request_options):
        return (client or self.client).post(
            self.base_url + endpoint + "/",
            data or {},
            format="json",
            HTTP_X_CSRFTOKEN=csrf_token or self.csrf_token,
            **request_options,
        )

    def registration_data(self, **overrides):
        data = {
            "email": self.email,
            "student_code": "B240001",
            "first_name": "Бат",
            "last_name": "Болд",
            "course": 2,
            "password": self.password,
            "password_confirm": self.password,
        }
        data.update(overrides)
        return data

    def email_code(self):
        self.assertTrue(mail.outbox, "The verification code must be emailed.")
        match = re.search(r"\b(\d{6})\b", mail.outbox[-1].body)
        self.assertIsNotNone(match, "The email must contain a six-digit code.")
        return match.group(1)

    def register(self, **overrides):
        response = self.post("register", self.registration_data(**overrides))
        self.assertEqual(response.status_code, 202, response.data)
        return response

    def verify_email(self, code, *, password=None, email=None, **request_options):
        return self.post(
            "verify-email",
            {"email": email or self.email, "code": code, "password": password or self.password},
            **request_options,
        )

    def create_verified_user(self, **overrides):
        data = {
            "email": self.email,
            "display_name": "Тест Оюутан",
            "password": self.password,
            "email_verified_at": timezone.now(),
        }
        data.update(overrides)
        return get_user_model().objects.create_user(**data)

    def login(self, *, remember_me=False):
        response = self.post(
            "login",
            {
                "email": self.email,
                "password": self.password,
                "remember_me": remember_me,
            },
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.csrf_token = response.data["csrf_token"]
        return response


class RegistrationTests(AuthApiTestCase):
    def test_registration_requires_csrf_even_for_an_anonymous_visitor(self):
        client = APIClient(enforce_csrf_checks=True)
        response = client.post(
            self.base_url + "register/", self.registration_data(), format="json"
        )
        self.assertEqual(response.status_code, 403)
        self.assertFalse(get_user_model().objects.exists())
        self.assertEqual(len(mail.outbox), 0)

    def test_every_anonymous_auth_mutation_enforces_csrf_before_validation(self):
        client = APIClient(enforce_csrf_checks=True)
        for endpoint in ("verify-email", "resend-verification"):
            with self.subTest(endpoint=endpoint):
                response = client.post(self.base_url + endpoint + "/", {}, format="json")
                self.assertEqual(response.status_code, 403)

    def test_registration_hashes_password_and_emails_a_hashed_challenge(self):
        self.register(email="STUDENT@EXAMPLE.COM")
        user = get_user_model().objects.get(email=self.email)
        self.assertIsNone(user.email_verified_at)
        self.assertEqual(user.role, "student")
        self.assertNotEqual(user.password, self.password)
        self.assertTrue(user.check_password(self.password))
        self.assertEqual(mail.outbox[-1].to, [self.email])

        challenge = EmailChallenge.objects.get(user=user, purpose="verify_email")
        code = self.email_code()
        self.assertNotEqual(challenge.code_digest, code)
        self.assertRegex(challenge.code_digest, r"^[0-9a-f]{64}$")
        self.assertIsNone(challenge.consumed_at)
        self.assertGreater(challenge.expires_at, timezone.now())

    def test_registration_stores_student_profile_and_uses_the_normalized_email(self):
        response = self.register(
            email=" STUDENT@EXAMPLE.COM ", student_code=" b24_0001-a ",
            first_name=" Бат ", last_name=" Болд ", course=4,
        )
        user = get_user_model().objects.get(email=self.email)
        self.assertEqual(response.data["email"], self.email)
        self.assertEqual(user.student_code, "B24_0001-A")
        self.assertEqual(user.first_name, "Бат")
        self.assertEqual(user.last_name, "Болд")
        self.assertEqual(user.display_name, "Болд Бат")
        self.assertEqual(user.course, 4)
        self.assertEqual(mail.outbox[-1].to, [self.email])

    def test_registration_requires_each_student_profile_field(self):
        for field in ("student_code", "first_name", "last_name", "course", "email"):
            with self.subTest(field=field):
                data = self.registration_data()
                data.pop(field)
                response = self.post("register", data)
                self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(get_user_model().objects.exists())
        self.assertEqual(len(mail.outbox), 0)

    def test_student_code_must_be_a_valid_identifier(self):
        for code in ("", " ", "-B240001", "B 240001", "B@240001", "B" * 33):
            with self.subTest(code=code):
                response = self.post("register", self.registration_data(student_code=code))
                self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(get_user_model().objects.exists())
        self.assertEqual(len(mail.outbox), 0)

    def test_course_must_be_a_whole_number_between_one_and_six(self):
        for course in (-1, 0, 7, 1.5, "invalid", ""):
            with self.subTest(course=course):
                response = self.post("register", self.registration_data(course=course))
                self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(get_user_model().objects.exists())
        self.assertEqual(len(mail.outbox), 0)

    def test_names_cannot_be_blank_or_exceed_the_field_limit(self):
        for field in ("first_name", "last_name"):
            for name in (" ", "Б" * 151):
                with self.subTest(field=field, name_length=len(name)):
                    response = self.post("register", self.registration_data(**{field: name}))
                    self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(get_user_model().objects.exists())
        self.assertEqual(len(mail.outbox), 0)

    def test_student_code_is_unique_across_email_addresses_ignoring_case(self):
        self.register()
        response = self.post(
            "register", self.registration_data(email="another@example.com", student_code="b240001"),
        )
        self.assertEqual(response.status_code, 400, response.data)
        self.assertEqual(get_user_model().objects.count(), 1)
        self.assertEqual(len(mail.outbox), 1)

    def test_display_name_is_derived_and_cannot_be_supplied_by_the_client(self):
        response = self.post("register", self.registration_data(display_name="Other name"))
        self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(get_user_model().objects.exists())

    def test_role_cannot_be_chosen_during_public_registration(self):
        response = self.post("register", self.registration_data(role="admin"))
        self.assertEqual(response.status_code, 400)
        self.assertFalse(get_user_model().objects.exists())

    def test_email_delivery_failure_rolls_back_registration_and_allows_retry(self):
        with patch("accounts.services.send_mail", side_effect=OSError("SMTP unavailable")):
            response = self.post("register", self.registration_data())
        self.assertEqual(response.status_code, 503, response.data)
        self.assertEqual(response.data["error"]["code"], "email_delivery_failed")
        self.assertFalse(get_user_model().objects.exists())
        self.assertFalse(EmailChallenge.objects.exists())
        self.assertEqual(len(mail.outbox), 0)
        self.assertNotIn("pending_verification", self.client.session)
        self.register()
        self.assertEqual(get_user_model().objects.count(), 1)
        self.assertEqual(len(mail.outbox), 1)

    def test_password_confirmation_and_password_strength_are_validated(self):
        response = self.post(
            "register", self.registration_data(password_confirm="different")
        )
        self.assertEqual(response.status_code, 400)
        response = self.post(
            "register", self.registration_data(password="123", password_confirm="123")
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(get_user_model().objects.exists())

    def test_duplicate_registration_has_the_same_public_response(self):
        first = self.register()
        user = get_user_model().objects.get(email=self.email)
        second = self.register(
            password="Another-Strong-Password!99",
            password_confirm="Another-Strong-Password!99",
            first_name="Өөр", last_name="Нэр", student_code="B240002", course=5,
        )
        self.assertEqual(second.data, first.data)
        self.assertEqual(get_user_model().objects.count(), 1)
        user.refresh_from_db()
        self.assertTrue(user.check_password(self.password))
        self.assertEqual(user.student_code, "B240001")
        self.assertEqual(user.first_name, "Бат")
        self.assertEqual(user.last_name, "Болд")
        self.assertEqual(user.course, 2)

    def test_email_verification_consumes_code_without_logging_in(self):
        self.register()
        code = self.email_code()
        response = self.verify_email(code)
        self.assertEqual(response.status_code, 200, response.data)
        user = get_user_model().objects.get(email=self.email)
        self.assertIsNotNone(user.email_verified_at)
        challenge = EmailChallenge.objects.get(user=user, purpose="verify_email")
        self.assertIsNotNone(challenge.consumed_at)
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertNotIn("pending_verification", self.client.session)
        self.assertIn(self.client.get(self.base_url + "me/").status_code, (401, 403))
        replay = self.verify_email(code)
        self.assertEqual(replay.status_code, 400)

    def test_verified_registration_can_log_in_repeatedly_without_more_email(self):
        self.register()
        response = self.verify_email(self.email_code())
        self.assertEqual(response.status_code, 200, response.data)
        self.login()
        self.assertEqual(self.post("logout").status_code, 200)
        self.csrf_token = self.get_csrf(self.client)
        self.login()
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(EmailChallenge.objects.count(), 1)

    def test_unverified_account_cannot_log_in(self):
        self.register()
        initial_email_count = len(mail.outbox)
        response = self.post("login", {"email": self.email, "password": self.password})
        self.assertEqual(response.status_code, 403)
        self.assertEqual(len(mail.outbox), initial_email_count)
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertEqual(self.client.session["pending_verification"]["email"], self.email)

    def test_expired_verification_code_cannot_verify_an_account(self):
        self.register()
        code = self.email_code()
        EmailChallenge.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        new_password = "A-Different-Unverified-Password!99"
        response = self.verify_email(code, password=new_password)
        self.assertEqual(response.status_code, 400)
        user = get_user_model().objects.get(email=self.email)
        self.assertIsNone(user.email_verified_at)
        self.assertTrue(user.check_password(self.password))
        self.assertFalse(user.check_password(new_password))

    def test_resend_rejects_another_email_and_invalidates_the_previous_code(self):
        self.register()
        previous = EmailChallenge.objects.get(purpose="verify_email")
        unknown = self.post("resend-verification", {"email": "unknown@example.com"})
        self.assertEqual(unknown.status_code, 400, unknown.data)
        self.assertEqual(unknown.data["error"]["code"], "verification_email_mismatch")
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(EmailChallenge.objects.count(), 1)
        previous_code = self.email_code()
        different_code = (int(previous_code) + 1) % 1_000_000
        with patch("accounts.services.secrets.randbelow", return_value=different_code):
            known = self.post("resend-verification", {"email": self.email.upper()})
        self.assertEqual(known.status_code, 202)
        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(mail.outbox[-1].to, [self.email])
        previous.refresh_from_db()
        self.assertIsNotNone(previous.consumed_at)
        active = EmailChallenge.objects.get(
            user=previous.user, purpose="verify_email", consumed_at__isnull=True
        )
        self.assertNotEqual(active.pk, previous.pk)
        rejected = self.verify_email(previous_code)
        self.assertEqual(rejected.status_code, 400, rejected.data)
        response = self.verify_email(self.email_code())
        self.assertEqual(response.status_code, 200, response.data)

    def test_verification_attempt_limit_cannot_be_bypassed_with_the_correct_code(self):
        self.register()
        code = self.email_code()
        wrong_code = "000000" if code != "000000" else "999999"
        new_password = "A-Different-Unverified-Password!99"
        for _ in range(5):
            response = self.verify_email(wrong_code, password=new_password)
            self.assertEqual(response.status_code, 400)
        self.assertEqual(EmailChallenge.objects.get().attempts, 5)
        response = self.verify_email(code, password=new_password)
        self.assertEqual(response.status_code, 400)
        self.assertEqual(EmailChallenge.objects.get().attempts, 5)
        user = get_user_model().objects.get(email=self.email)
        self.assertIsNone(user.email_verified_at)
        self.assertTrue(user.check_password(self.password))
        self.assertFalse(user.check_password(new_password))

    def test_failed_resend_preserves_the_previous_usable_verification_code(self):
        self.register()
        code = self.email_code()
        challenge = EmailChallenge.objects.get()
        with patch("accounts.services.send_mail", side_effect=OSError("SMTP unavailable")):
            response = self.post("resend-verification", {"email": self.email})
        self.assertEqual(response.status_code, 503, response.data)
        challenge.refresh_from_db()
        self.assertIsNone(challenge.consumed_at)
        self.assertEqual(EmailChallenge.objects.count(), 1)
        self.assertEqual(len(mail.outbox), 1)
        verified = self.verify_email(code)
        self.assertEqual(verified.status_code, 200, verified.data)

    @override_settings(EMAIL_RESEND_COOLDOWN_SECONDS=60)
    def test_resend_cooldown_returns_retry_after_without_replacing_the_code(self):
        self.register()
        response = self.post("resend-verification", {"email": self.email})
        self.assertEqual(response.status_code, 429, response.data)
        self.assertGreater(int(response["Retry-After"]), 0)
        self.assertLessEqual(int(response["Retry-After"]), 60)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(EmailChallenge.objects.count(), 1)
        self.assertIsNone(EmailChallenge.objects.get().consumed_at)

    def test_mailbox_owner_sets_the_final_password_despite_an_existing_registration(self):
        self.register()
        final_password = "The-Mailbox-Owners-New-Password!91"
        self.register(password=final_password, password_confirm=final_password)
        resent = self.post("resend-verification", {"email": self.email})
        self.assertEqual(resent.status_code, 202, resent.data)
        verified = self.verify_email(self.email_code(), password=final_password)
        self.assertEqual(verified.status_code, 200, verified.data)
        rejected = self.post("login", {"email": self.email, "password": self.password})
        self.assertEqual(rejected.status_code, 401)
        accepted = self.post("login", {"email": self.email, "password": final_password})
        self.assertEqual(accepted.status_code, 200, accepted.data)
        user = get_user_model().objects.get(email=self.email)
        self.assertTrue(user.check_password(final_password))
        self.assertFalse(user.check_password(self.password))

    def test_email_verification_requires_a_strong_final_password(self):
        self.register()
        code = self.email_code()
        missing = self.post("verify-email", {"email": self.email, "code": code})
        self.assertEqual(missing.status_code, 400)
        weak = self.verify_email(code, password="123")
        self.assertEqual(weak.status_code, 400)
        self.assertIsNone(get_user_model().objects.get(email=self.email).email_verified_at)
        self.assertIsNone(EmailChallenge.objects.get().consumed_at)

    def test_resend_returns_generic_response_if_account_changes_during_delivery(self):
        from accounts.services import InvalidChallengeError

        self.register()
        with patch("accounts.views.issue_challenge", side_effect=InvalidChallengeError):
            response = self.post("resend-verification", {"email": self.email})
        self.assertEqual(response.status_code, 202, response.data)


class VerificationBindingTests(AuthApiTestCase):
    def test_registration_stores_only_an_anonymous_account_binding_in_the_session(self):
        response = self.register()
        user = get_user_model().objects.get(email=self.email)
        pending = self.client.session["pending_verification"]
        self.assertEqual(set(pending), {"user_id", "email", "started_at"})
        self.assertEqual(pending["user_id"], str(user.pk))
        self.assertEqual(pending["email"], self.email)
        self.assertLess(abs(pending["started_at"] - timezone.now().timestamp()), 10)
        serialized_session = json.dumps(dict(self.client.session))
        self.assertNotIn(self.password, serialized_session)
        self.assertNotIn(user.password, serialized_session)
        self.assertNotIn(json.dumps(self.email_code()), serialized_session)
        self.assertNotIn("_auth_user_id", self.client.session)
        self.assertTrue(response.cookies["sessionid"]["httponly"])

    def test_a_fresh_session_cannot_verify_or_resend_for_a_known_address(self):
        self.register()
        code = self.email_code()
        client = APIClient(enforce_csrf_checks=True)
        csrf_token = self.get_csrf(client)
        verify = self.verify_email(code, client=client, csrf_token=csrf_token)
        resend = self.post(
            "resend-verification", {"email": self.email}, client=client, csrf_token=csrf_token,
        )
        for response in (verify, resend):
            self.assertEqual(response.status_code, 400, response.data)
            self.assertEqual(response.data["error"]["code"], "verification_required")
        self.assertEqual(len(mail.outbox), 1)
        self.assertIsNone(EmailChallenge.objects.get().consumed_at)
        self.assertEqual(EmailChallenge.objects.get().attempts, 0)
        self.assertEqual(self.verify_email(code).status_code, 200)

    def test_bound_session_rejects_another_account_even_with_its_valid_code(self):
        self.register()
        original_code = self.email_code()
        other_client = APIClient(enforce_csrf_checks=True)
        other_token = self.get_csrf(other_client)
        other_email = "other.student@example.com"
        registered = self.post(
            "register", self.registration_data(email=other_email, student_code="B240002"),
            client=other_client, csrf_token=other_token,
        )
        self.assertEqual(registered.status_code, 202, registered.data)
        other_code = self.email_code()
        verify = self.verify_email(other_code, email=other_email)
        resend = self.post("resend-verification", {"email": other_email})
        for response in (verify, resend):
            self.assertEqual(response.status_code, 400, response.data)
            self.assertEqual(response.data["error"]["code"], "verification_email_mismatch")
        other_user = get_user_model().objects.get(email=other_email)
        other_challenge = EmailChallenge.objects.get(user=other_user)
        self.assertIsNone(other_user.email_verified_at)
        self.assertIsNone(other_challenge.consumed_at)
        self.assertEqual(other_challenge.attempts, 0)
        self.assertEqual(len(mail.outbox), 2)
        self.assertEqual(self.client.session["pending_verification"]["email"], self.email)
        self.assertEqual(self.verify_email(original_code).status_code, 200)

    def test_new_registration_replaces_the_binding_without_transferring_the_old_code(self):
        with patch("accounts.services.secrets.randbelow", side_effect=[111111, 222222]):
            self.register()
            other_email = "other.student@example.com"
            self.register(email=other_email, student_code="B240002")
        wrong_address = self.verify_email("111111")
        self.assertEqual(wrong_address.status_code, 400, wrong_address.data)
        self.assertEqual(wrong_address.data["error"]["code"], "verification_email_mismatch")
        wrong_code = self.verify_email("111111", email=other_email)
        self.assertEqual(wrong_code.status_code, 400, wrong_code.data)
        self.assertIsNone(get_user_model().objects.get(email=self.email).email_verified_at)
        success = self.verify_email("222222", email=other_email)
        self.assertEqual(success.status_code, 200, success.data)
        self.assertIsNotNone(get_user_model().objects.get(email=other_email).email_verified_at)
        self.assertNotIn("pending_verification", self.client.session)

    def test_expired_registration_context_cannot_send_email_or_consume_a_valid_code(self):
        self.register()
        code = self.email_code()
        session = self.client.session
        pending = session["pending_verification"]
        pending["started_at"] = (timezone.now() - timedelta(minutes=31)).timestamp()
        session["pending_verification"] = pending
        session.save()
        resend = self.post("resend-verification", {"email": self.email})
        verify = self.verify_email(code)
        for response in (resend, verify):
            self.assertEqual(response.status_code, 400, response.data)
            self.assertEqual(response.data["error"]["code"], "verification_required")
        self.assertEqual(len(mail.outbox), 1)
        self.assertIsNone(EmailChallenge.objects.get().consumed_at)
        self.assertIsNone(get_user_model().objects.get(email=self.email).email_verified_at)
        self.assertNotIn("pending_verification", self.client.session)

    def test_only_a_correct_unverified_password_can_resume_a_registration(self):
        self.register()
        client = APIClient(enforce_csrf_checks=True)
        csrf_token = self.get_csrf(client)
        wrong = self.post(
            "login", {"email": self.email, "password": "wrong"},
            client=client, csrf_token=csrf_token,
        )
        self.assertEqual(wrong.status_code, 401, wrong.data)
        self.assertNotIn("pending_verification", client.session)
        resumed = self.post(
            "login", {"email": self.email.upper(), "password": self.password},
            client=client, csrf_token=csrf_token,
        )
        self.assertEqual(resumed.status_code, 403, resumed.data)
        self.assertEqual(resumed.data["error"]["code"], "email_not_verified")
        self.assertEqual(client.session["pending_verification"]["email"], self.email)
        self.assertNotIn("_auth_user_id", client.session)
        self.assertEqual(len(mail.outbox), 1)
        resend = self.post(
            "resend-verification", {"email": self.email}, client=client, csrf_token=csrf_token,
        )
        self.assertEqual(resend.status_code, 202, resend.data)
        self.assertEqual(mail.outbox[-1].to, [self.email])
        verified = self.verify_email(self.email_code(), client=client, csrf_token=csrf_token)
        self.assertEqual(verified.status_code, 200, verified.data)
        self.assertNotIn("pending_verification", client.session)

    def test_a_verified_account_cannot_reuse_another_pending_session(self):
        self.register()
        code = self.email_code()
        other_client = APIClient(enforce_csrf_checks=True)
        other_token = self.get_csrf(other_client)
        resumed = self.post(
            "login", {"email": self.email, "password": self.password},
            client=other_client, csrf_token=other_token,
        )
        self.assertEqual(resumed.status_code, 403, resumed.data)
        self.assertIn("pending_verification", other_client.session)
        self.assertEqual(self.verify_email(code).status_code, 200)
        before = get_user_model().objects.get(email=self.email).password
        resend = self.post(
            "resend-verification", {"email": self.email},
            client=other_client, csrf_token=other_token,
        )
        verify = self.verify_email(
            code, password="Another-Strong-Password!99", client=other_client, csrf_token=other_token,
        )
        self.assertEqual(resend.status_code, 400, resend.data)
        self.assertEqual(verify.status_code, 400, verify.data)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(EmailChallenge.objects.count(), 1)
        self.assertEqual(get_user_model().objects.get(email=self.email).password, before)

    def test_login_and_profile_return_the_registered_student_fields(self):
        self.register()
        verified = self.verify_email(self.email_code())
        self.assertEqual(verified.status_code, 200, verified.data)
        login_response = self.login()
        profile = self.client.get(self.base_url + "me/")
        self.assertEqual(profile.status_code, 200, profile.data)
        expected = {
            "student_code": "B240001", "first_name": "Бат", "last_name": "Болд",
            "course": 2, "display_name": "Болд Бат", "email": self.email,
        }
        for field, value in expected.items():
            with self.subTest(field=field):
                self.assertEqual(profile.data["user"][field], value)
                self.assertEqual(login_response.data["user"][field], value)


class LoginSessionTests(AuthApiTestCase):
    def setUp(self):
        super().setUp()
        self.user = self.create_verified_user()

    def test_password_login_requires_csrf(self):
        client = APIClient(enforce_csrf_checks=True)
        response = client.post(
            self.base_url + "login/",
            {"email": self.email, "password": self.password},
            format="json",
        )
        self.assertEqual(response.status_code, 403)
        self.assertFalse(EmailChallenge.objects.exists())

    def test_unknown_email_and_wrong_password_return_the_same_error(self):
        wrong_password = self.post("login", {"email": self.email, "password": "wrong"})
        unknown_email = self.post(
            "login", {"email": "unknown@example.com", "password": "wrong"}
        )
        self.assertEqual(wrong_password.status_code, 401)
        self.assertEqual(unknown_email.status_code, 401)
        self.assertEqual(wrong_password.data, unknown_email.data)
        self.assertEqual(len(mail.outbox), 0)
        self.assertFalse(EmailChallenge.objects.exists())

    def test_verified_user_logs_in_with_password_without_another_email(self):
        response = self.login()
        self.assertEqual(response.data["user"]["email"], self.email)
        self.assertEqual(response.data["user"]["role"], "student")
        self.assertTrue(response.data["user"]["email_verified"])
        self.assertIsNone(response.data["user"]["student_code"])
        self.assertIsNone(response.data["user"]["course"])
        self.assertEqual(response.data["user"]["first_name"], "")
        self.assertEqual(response.data["user"]["last_name"], "")
        self.assertNotIn("password", response.data["user"])
        self.assertIn("csrf_token", response.data)
        me = self.client.get(self.base_url + "me/")
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.data["user"], response.data["user"])
        self.assertEqual(len(mail.outbox), 0)
        self.assertFalse(EmailChallenge.objects.exists())

    def test_normal_login_uses_an_http_only_browser_session(self):
        response = self.login()
        cookie = response.cookies["sessionid"]
        self.assertTrue(cookie["httponly"])
        self.assertEqual(cookie["samesite"].lower(), "lax")
        self.assertEqual(cookie["max-age"], "")
        self.assertEqual(cookie["expires"], "")
        self.assertTrue(self.client.session.get_expire_at_browser_close())
        self.assertLessEqual(self.client.session.get_expiry_age(), 8 * 60 * 60)

    def test_remember_me_uses_a_thirty_day_session(self):
        response = self.login(remember_me=True)
        cookie = response.cookies["sessionid"]
        self.assertTrue(cookie["httponly"])
        self.assertEqual(int(cookie["max-age"]), 30 * 24 * 60 * 60)
        self.assertTrue(cookie["expires"])
        self.assertFalse(self.client.session.get_expire_at_browser_close())
        self.assertLessEqual(self.client.session.get_expiry_age(), 30 * 24 * 60 * 60)

    def test_login_replaces_the_preexisting_anonymous_session_key(self):
        session = self.client.session
        session["anonymous_visit"] = True
        session.save()
        old_session_key = session.session_key
        self.login()
        self.assertNotEqual(self.client.session.session_key, old_session_key)
        self.assertFalse(Session.objects.filter(session_key=old_session_key).exists())

    def test_login_rotates_csrf_and_rejects_the_prelogin_token(self):
        old_csrf_token = self.csrf_token
        self.login()
        old_token_response = self.post("logout", csrf_token=old_csrf_token)
        self.assertEqual(old_token_response.status_code, 403)
        self.assertEqual(self.client.get(self.base_url + "me/").status_code, 200)
        self.assertEqual(self.post("logout").status_code, 200)

    @patch("accounts.throttles.AuthEmailThrottle.get_rate", return_value="2/min")
    def test_login_email_throttle_applies_across_ips_and_email_case(self, _get_rate):
        for index in range(2):
            response = self.post(
                "login", {"email": self.email, "password": "wrong"},
                REMOTE_ADDR=f"192.0.2.{index + 1}",
            )
            self.assertEqual(response.status_code, 401)
        response = self.post(
            "login", {"email": self.email.upper(), "password": "wrong"},
            REMOTE_ADDR="192.0.2.3",
        )
        self.assertEqual(response.status_code, 429)
        self.assertGreater(int(response["Retry-After"]), 0)
        self.assertNotIn("sessionid", response.cookies)

    @patch("accounts.throttles.AuthIPThrottle.get_rate", return_value="2/min")
    def test_login_ip_throttle_applies_across_different_email_addresses(self, _get_rate):
        for index in range(2):
            response = self.post(
                "login", {"email": f"unknown{index}@example.com", "password": "wrong"}
            )
            self.assertEqual(response.status_code, 401)
        response = self.post(
            "login", {"email": "another@example.com", "password": "wrong"}
        )
        self.assertEqual(response.status_code, 429)
        self.assertGreater(int(response["Retry-After"]), 0)
        self.assertNotIn("sessionid", response.cookies)

    def test_logout_requires_csrf_and_invalidates_the_session(self):
        self.login()
        session_key = self.client.session.session_key
        missing_csrf = self.client.post(self.base_url + "logout/", {}, format="json")
        self.assertEqual(missing_csrf.status_code, 403)
        self.assertEqual(self.client.get(self.base_url + "me/").status_code, 200)

        response = self.post("logout")
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.cookies["sessionid"]["max-age"], 0)
        self.assertIn(self.client.get(self.base_url + "me/").status_code, (401, 403))
        self.assertFalse(Session.objects.filter(session_key=session_key).exists())

    def test_basic_credentials_do_not_authenticate_the_session_endpoint(self):
        client = APIClient(enforce_csrf_checks=True)
        credentials = base64.b64encode(f"{self.email}:{self.password}".encode()).decode()
        response = client.get(self.base_url + "me/", HTTP_AUTHORIZATION=f"Basic {credentials}")
        self.assertIn(response.status_code, (401, 403))

    def test_inactive_account_cannot_log_in(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        response = self.post("login", {"email": self.email, "password": self.password})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(len(mail.outbox), 0)

    def test_deactivating_an_account_revokes_its_existing_session(self):
        self.login()
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        response = self.client.get(self.base_url + "me/")
        self.assertIn(response.status_code, (401, 403))
