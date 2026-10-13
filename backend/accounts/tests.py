"""Authentication API and security regression tests; no external mail server required."""
import re
from datetime import timedelta
from io import StringIO
from smtplib import SMTPException
from unittest.mock import patch

from django.core import mail
from django.core.cache import cache
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework.throttling import SimpleRateThrottle

from .models import AuthSession, EmailChallenge, TrustedDevice, User


@override_settings(
    EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend",
    PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
    AUTH_CODE_MAX_ATTEMPTS=5,
    AUTH_CODE_MAX_SENDS=5,
    AUTH_CODE_RESEND_SECONDS=0,
)
class AuthenticationAPITests(TestCase):
    password = "BlueMoon!River9847"
    email = "student@example.com"

    def setUp(self):
        cache.clear()
        self.client = APIClient()
        # DRF captures this attribute at import, so override_settings alone does
        # not replace it. Keep security flow tests independent of rate limits.
        throttle_patch = patch.object(
            SimpleRateThrottle,
            "THROTTLE_RATES",
            {"auth_ip": "10000/min", "auth_email": "10000/hour"},
        )
        throttle_patch.start()
        self.addCleanup(throttle_patch.stop)

    def post(self, route, payload):
        return self.client.post(f"/api/auth/{route}/", payload, format="json")

    def assert_denied(self, response, statuses=(400, 401, 403, 429)):
        self.assertIn(response.status_code, statuses, response.content)
        self.assertNotIn("token", response.json())

    def latest_code(self):
        self.assertTrue(mail.outbox)
        match = re.search(r"\b(\d{6})\b", mail.outbox[-1].body)
        self.assertIsNotNone(match, mail.outbox[-1].body)
        return match.group(1)

    def register(self, **changes):
        payload = {
            "email": self.email,
            "password": self.password,
            "full_name": "Test Student",
            **changes,
        }
        response = self.post("register", payload)
        self.assertIn(response.status_code, (200, 201, 202), response.content)
        data = response.json()
        self.assertTrue(data["verification_required"])
        self.assertEqual(data["purpose"], "register")
        return data, self.latest_code()

    def verify_registration(self, challenge, code):
        return self.post(
            "register/verify", {"challenge_id": challenge["challenge_id"], "code": code}
        )

    def verified_user(self, email=None, **changes):
        return User.objects.create_user(
            email=email or self.email,
            password=self.password,
            full_name="Test Student",
            email_verified=True,
            **changes,
        )

    def start_login(self, **changes):
        return self.post(
            "login", {"email": self.email, "password": self.password, **changes}
        )

    def complete_login(self, **changes):
        response = self.start_login(**changes)
        self.assertIn(response.status_code, (200, 202), response.content)
        challenge = response.json()
        self.assertTrue(challenge["verification_required"])
        response = self.post(
            "login/verify",
            {"challenge_id": challenge["challenge_id"], "code": self.latest_code()},
        )
        self.assertEqual(response.status_code, 200, response.content)
        return response.json()

    def authorize(self, token):
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_registration_creates_verified_user_only_after_email_confirmation(self):
        challenge, code = self.register(email="STUDENT@Example.COM")
        self.assertFalse(User.objects.exists())
        self.assertEqual(mail.outbox[-1].to, [self.email])
        response = self.verify_registration(challenge, code)
        self.assertIn(response.status_code, (200, 201), response.content)
        data = response.json()
        user = User.objects.get()
        self.assertEqual(user.email, self.email)
        self.assertEqual(user.full_name, "Test Student")
        self.assertTrue(user.email_verified)
        self.assertTrue(user.check_password(self.password))
        self.assertNotEqual(user.password, self.password)
        self.assertTrue(data["user"]["email_verified"])
        self.assertEqual(data["token_type"], "Bearer")
        self.assertGreater(data["expires_in"], 0)
        self.authorize(data["token"])
        response = self.client.get("/api/auth/me/")
        self.assertEqual(response.status_code, 200, response.content)

    def test_verified_email_cannot_be_registered_again_in_another_case(self):
        self.verified_user()
        response = self.post(
            "register",
            {"email": "STUDENT@EXAMPLE.COM", "password": self.password, "full_name": "Other"},
        )
        self.assert_denied(response, statuses=(409,))
        self.assertEqual(User.objects.count(), 1)
        self.assertFalse(EmailChallenge.objects.exists())

    def test_registration_rejects_invalid_email_and_weak_password(self):
        for changes in ({"email": "invalid"}, {"password": "12345678"}):
            with self.subTest(changes=changes):
                response = self.post(
                    "register",
                    {"email": self.email, "password": self.password, "full_name": "Test", **changes},
                )
                self.assertEqual(response.status_code, 400, response.content)
        self.assertFalse(User.objects.exists())
        self.assertFalse(EmailChallenge.objects.exists())

    def test_wrong_registration_code_preserves_attempt_count_and_creates_no_user(self):
        challenge, code = self.register()
        wrong = "000000" if code != "000000" else "111111"
        self.assert_denied(self.verify_registration(challenge, wrong))
        stored = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertEqual(stored.attempts, 1)
        self.assertFalse(User.objects.exists())

    def test_registration_code_cannot_be_replayed(self):
        challenge, code = self.register()
        self.assertIn(self.verify_registration(challenge, code).status_code, (200, 201))
        self.assert_denied(self.verify_registration(challenge, code))
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(AuthSession.objects.count(), 1)

    def test_expired_code_creates_no_user(self):
        challenge, code = self.register()
        EmailChallenge.objects.filter(pk=challenge["challenge_id"]).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        self.assert_denied(self.verify_registration(challenge, code))
        self.assertFalse(User.objects.exists())

    def test_attempt_limit_rejects_even_the_correct_code(self):
        challenge, code = self.register()
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(5):
            self.assert_denied(self.verify_registration(challenge, wrong))
        self.assert_denied(self.verify_registration(challenge, code))
        stored = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertEqual(stored.attempts, 5)
        self.assertFalse(User.objects.exists())

    @override_settings(AUTH_CODE_RESEND_SECONDS=60)
    def test_resend_cooldown_does_not_send_another_email(self):
        challenge, _ = self.register()
        self.assert_denied(self.post("resend-code", {"challenge_id": challenge["challenge_id"]}))
        self.assertEqual(len(mail.outbox), 1)

    @override_settings(AUTH_CODE_RESEND_SECONDS=60)
    def test_creating_another_login_challenge_cannot_bypass_the_cooldown(self):
        self.verified_user()
        response = self.start_login()
        self.assertEqual(response.status_code, 202, response.content)
        challenge = response.json()
        code = self.latest_code()
        response = self.start_login(email="STUDENT@EXAMPLE.COM")
        self.assertEqual(response.status_code, 429, response.content)
        self.assertGreater(response.json()["retry_after"], 0)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(EmailChallenge.objects.count(), 1)
        response = self.post("login/verify", {"challenge_id": challenge["challenge_id"], "code": code})
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(self.start_login().status_code, 429)
        self.assertEqual(len(mail.outbox), 1)

    @override_settings(AUTH_CODE_RESEND_SECONDS=0)
    @patch("accounts.services.secrets.randbelow", side_effect=(123456, 654321))
    def test_resend_invalidates_old_code_and_preserves_failed_attempts(self, _random):
        challenge, old_code = self.register()
        wrong = "000000" if old_code != "000000" else "111111"
        self.assert_denied(self.verify_registration(challenge, wrong))
        response = self.post("resend-code", {"challenge_id": challenge["challenge_id"]})
        self.assertIn(response.status_code, (200, 202), response.content)
        new_code = self.latest_code()
        self.assertNotEqual(new_code, old_code)
        stored = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertEqual(stored.attempts, 1)
        self.assertEqual(stored.sends, 2)
        self.assert_denied(self.verify_registration(challenge, old_code))
        self.assertIn(self.verify_registration(challenge, new_code).status_code, (200, 201))

    @override_settings(AUTH_CODE_RESEND_SECONDS=0)
    def test_resend_limit_cannot_reset_attempt_budget(self):
        challenge, code = self.register()
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(4):
            self.assert_denied(self.verify_registration(challenge, wrong))
            response = self.post("resend-code", {"challenge_id": challenge["challenge_id"]})
            self.assertIn(response.status_code, (200, 202), response.content)
            code = self.latest_code()
            wrong = "000000" if code != "000000" else "111111"
        self.assert_denied(self.post("resend-code", {"challenge_id": challenge["challenge_id"]}))
        self.assert_denied(self.verify_registration(challenge, wrong))
        self.assert_denied(self.verify_registration(challenge, code))
        stored = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertEqual(stored.sends, 5)
        self.assertEqual(stored.attempts, 5)

    def test_mail_failure_returns_503_and_no_usable_registration_challenge(self):
        with patch("django.core.mail.message.EmailMessage.send", side_effect=SMTPException("offline")):
            response = self.post(
                "register", {"email": self.email, "password": self.password, "full_name": "Test"}
            )
        self.assertEqual(response.status_code, 503, response.content)
        self.assertFalse(User.objects.exists())
        self.assertFalse(EmailChallenge.objects.filter(consumed_at__isnull=True).exists())

    def test_failed_resend_keeps_the_previous_code_and_send_budget(self):
        challenge, code = self.register()
        before = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        with patch("django.core.mail.message.EmailMessage.send", side_effect=SMTPException("offline")):
            response = self.post("resend-code", {"challenge_id": challenge["challenge_id"]})
        self.assertEqual(response.status_code, 503, response.content)
        after = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertEqual(after.sends, before.sends)
        self.assertEqual(after.code_hash, before.code_hash)
        self.assertEqual(after.expires_at, before.expires_at)
        self.assertIn(self.verify_registration(challenge, code).status_code, (200, 201))

    def test_login_requires_email_code_before_a_session_is_created(self):
        self.verified_user()
        response = self.start_login()
        self.assertIn(response.status_code, (200, 202), response.content)
        challenge = response.json()
        self.assertTrue(challenge["verification_required"])
        self.assertEqual(challenge["purpose"], "login")
        self.assertNotIn("token", challenge)
        self.assertFalse(AuthSession.objects.exists())
        code = self.latest_code()
        response = self.post("login/verify", {"challenge_id": challenge["challenge_id"], "code": code})
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(AuthSession.objects.count(), 1)
        self.assertNotIn("device_token", response.json())
        self.assertFalse(TrustedDevice.objects.exists())
        self.assert_denied(self.post("login/verify", {"challenge_id": challenge["challenge_id"], "code": code}))

    def test_registration_and_login_codes_cannot_be_used_for_the_other_purpose(self):
        challenge, code = self.register()
        self.assert_denied(self.post("login/verify", {"challenge_id": challenge["challenge_id"], "code": code}))
        self.assertFalse(User.objects.exists())
        self.assertIn(self.verify_registration(challenge, code).status_code, (200, 201))
        response = self.start_login()
        self.assertIn(response.status_code, (200, 202), response.content)
        challenge = response.json()
        code = self.latest_code()
        self.assert_denied(self.verify_registration(challenge, code))

    def test_wrong_password_and_unknown_email_send_no_code(self):
        self.verified_user()
        for changes in ({"password": "WrongPassword!123"}, {"email": "unknown@example.com"}):
            with self.subTest(changes=changes):
                self.assert_denied(self.start_login(**changes))
        self.assertFalse(EmailChallenge.objects.exists())
        self.assertFalse(AuthSession.objects.exists())
        self.assertFalse(mail.outbox)

    def test_inactive_and_unverified_users_cannot_log_in(self):
        user = self.verified_user()
        user.is_active = False
        user.save(update_fields=["is_active"])
        self.assert_denied(self.start_login())
        user.is_active = True
        user.email_verified = False
        user.save(update_fields=["is_active", "email_verified"])
        self.assert_denied(self.start_login())
        self.assertFalse(AuthSession.objects.exists())
        self.assertFalse(EmailChallenge.objects.exists())

    def test_login_mail_failure_creates_no_usable_challenge_or_session(self):
        self.verified_user()
        with patch("django.core.mail.message.EmailMessage.send", side_effect=SMTPException("offline")):
            response = self.start_login()
        self.assertEqual(response.status_code, 503, response.content)
        self.assertFalse(EmailChallenge.objects.filter(consumed_at__isnull=True).exists())
        self.assertFalse(AuthSession.objects.exists())

    def test_remembered_device_can_skip_code_only_with_the_correct_password(self):
        self.verified_user()
        data = self.complete_login(remember_device=True, device_name="Student laptop")
        self.assertIn("device_token", data)
        self.assertGreater(data["device_expires_in"], 0)
        self.assertEqual(TrustedDevice.objects.count(), 1)
        sent = len(mail.outbox)
        response = self.start_login(device_token=data["device_token"])
        self.assertEqual(response.status_code, 200, response.content)
        self.assertIn("token", response.json())
        self.assertEqual(len(mail.outbox), sent)
        self.assertEqual(AuthSession.objects.count(), 2)
        self.assert_denied(self.start_login(device_token=data["device_token"], password="wrong"))
        self.assertEqual(AuthSession.objects.count(), 2)

    def test_expired_or_unknown_device_requires_a_new_email_code(self):
        self.verified_user()
        data = self.complete_login(remember_device=True)
        TrustedDevice.objects.filter(pk=data["device_id"]).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        for device_token in (data["device_token"], "unknown-device-token"):
            with self.subTest(device_token=device_token):
                response = self.start_login(device_token=device_token)
                self.assertIn(response.status_code, (200, 202), response.content)
                self.assertTrue(response.json()["verification_required"])
                self.assertNotIn("token", response.json())

    def test_another_users_device_token_cannot_bypass_email_verification(self):
        self.verified_user()
        data = self.complete_login(remember_device=True)
        self.verified_user(email="other@example.com")
        response = self.start_login(email="other@example.com", device_token=data["device_token"])
        self.assertIn(response.status_code, (200, 202), response.content)
        self.assertTrue(response.json()["verification_required"])
        self.assertNotIn("token", response.json())

    def test_device_list_exposes_no_secret_and_revoke_invalidates_linked_sessions(self):
        self.verified_user()
        data = self.complete_login(remember_device=True, device_name="Student laptop")
        second = self.start_login(device_token=data["device_token"]).json()
        self.authorize(data["token"])
        response = self.client.get("/api/auth/devices/")
        self.assertEqual(response.status_code, 200, response.content)
        content = response.content.decode()
        self.assertIn("Student laptop", content)
        self.assertNotIn(data["device_token"], content)
        self.assertNotIn("token_hash", content)
        response = self.client.delete(f"/api/auth/devices/{data['device_id']}/")
        self.assertIn(response.status_code, (200, 204), response.content)
        for token in (data["token"], second["token"]):
            self.authorize(token)
            self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))
        self.client.credentials()
        response = self.start_login(device_token=data["device_token"])
        self.assertTrue(response.json()["verification_required"])

    def test_user_cannot_revoke_another_users_device(self):
        self.verified_user()
        first = self.complete_login(remember_device=True)
        self.verified_user(email="other@example.com")
        other = self.complete_login(email="other@example.com")
        self.authorize(other["token"])
        response = self.client.delete(f"/api/auth/devices/{first['device_id']}/")
        self.assertEqual(response.status_code, 404, response.content)
        self.client.credentials()
        response = self.start_login(device_token=first["device_token"])
        self.assertIn("token", response.json())

    def test_cleanup_revokes_expired_device_sessions_and_keeps_ordinary_sessions(self):
        self.verified_user()
        ordinary = self.complete_login()
        remembered = self.complete_login(remember_device=True)
        TrustedDevice.objects.filter(pk=remembered["device_id"]).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        self.authorize(remembered["token"])
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401,))
        self.assertEqual(AuthSession.objects.count(), 2)
        call_command("cleanup_auth", stdout=StringIO())
        self.assertFalse(TrustedDevice.objects.filter(pk=remembered["device_id"]).exists())
        self.assertEqual(AuthSession.objects.count(), 1)
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401,))
        self.authorize(ordinary["token"])
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 200)

    def test_direct_device_deletion_revokes_linked_sessions_only(self):
        self.verified_user()
        ordinary = self.complete_login()
        remembered = self.complete_login(remember_device=True)
        second = self.start_login(device_token=remembered["device_token"]).json()
        self.assertEqual(AuthSession.objects.count(), 3)
        TrustedDevice.objects.get(pk=remembered["device_id"]).delete()
        self.assertEqual(AuthSession.objects.count(), 1)
        for token in (remembered["token"], second["token"]):
            self.authorize(token)
            self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401,))
        self.authorize(ordinary["token"])
        self.assertEqual(self.client.get("/api/auth/me/").status_code, 200)

    def test_expired_session_and_invalid_bearer_token_are_rejected(self):
        self.verified_user()
        data = self.complete_login()
        AuthSession.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
        for token in (data["token"], "not-a-real-session"):
            with self.subTest(token=token):
                self.authorize(token)
                self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))

    def test_inactive_or_unverified_user_cannot_keep_using_a_session(self):
        user = self.verified_user()
        data = self.complete_login()
        self.authorize(data["token"])
        user.is_active = False
        user.save(update_fields=["is_active"])
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))
        user.is_active = True
        user.email_verified = False
        user.save(update_fields=["is_active", "email_verified"])
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))

    def test_logout_revokes_session_but_can_preserve_remembered_device(self):
        self.verified_user()
        data = self.complete_login(remember_device=True)
        self.authorize(data["token"])
        response = self.post("logout", {})
        self.assertIn(response.status_code, (200, 204), response.content)
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))
        self.client.credentials()
        response = self.start_login(device_token=data["device_token"])
        self.assertIn("token", response.json())

    def test_logout_forget_device_revokes_all_its_sessions_and_trust(self):
        self.verified_user()
        data = self.complete_login(remember_device=True)
        second = self.start_login(device_token=data["device_token"]).json()
        self.authorize(data["token"])
        response = self.post("logout", {"forget_device": True})
        self.assertIn(response.status_code, (200, 204), response.content)
        self.authorize(second["token"])
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))
        self.client.credentials()
        response = self.start_login(device_token=data["device_token"])
        self.assertTrue(response.json()["verification_required"])

    def test_codes_passwords_and_bearer_tokens_are_not_stored_in_plaintext(self):
        challenge, code = self.register()
        stored = EmailChallenge.objects.get(pk=challenge["challenge_id"])
        self.assertNotEqual(stored.password_hash, self.password)
        self.assertNotEqual(stored.code_hash, code)
        self.assertTrue(stored.password_hash)
        self.assertEqual(len(stored.code_hash), 64)
        self.assertIn(self.verify_registration(challenge, code).status_code, (200, 201))
        data = self.complete_login(remember_device=True)
        session = AuthSession.objects.order_by("-created_at").first()
        device = TrustedDevice.objects.get(pk=data["device_id"])
        self.assertNotEqual(session.token_hash, data["token"])
        self.assertNotEqual(device.token_hash, data["device_token"])
        self.assertNotIn(data["token"], repr(list(AuthSession.objects.values())))
        self.assertNotIn(data["device_token"], repr(list(TrustedDevice.objects.values())))

    def test_missing_credentials_and_malformed_challenges_are_rejected(self):
        self.assert_denied(self.client.get("/api/auth/me/"), statuses=(401, 403))
        self.assert_denied(self.client.get("/api/auth/devices/"), statuses=(401, 403))
        self.assert_denied(self.post("logout", {}), statuses=(401, 403))
        for route, payload in (
            ("register", {}),
            ("login", {}),
            ("register/verify", {"challenge_id": "bad-uuid", "code": "123456"}),
            ("login/verify", {"challenge_id": "bad-uuid", "code": "123456"}),
            ("resend-code", {"challenge_id": "bad-uuid"}),
            ("register/verify", {"challenge_id": "00000000-0000-0000-0000-000000000000", "code": "abc"}),
        ):
            with self.subTest(route=route, payload=payload):
                self.assertEqual(self.post(route, payload).status_code, 400)

    def test_challenges_tokens_and_auth_errors_are_not_cacheable(self):
        response = self.post("register", {"email": self.email, "password": self.password})
        self.assertEqual(response.status_code, 202, response.content)
        self.assertEqual(response["Cache-Control"], "no-store")
        response = self.verify_registration(response.json(), self.latest_code())
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(self.client.get("/api/auth/me/")["Cache-Control"], "no-store")

    def test_email_throttle_normalizes_case_and_covers_different_client_ips(self):
        self.verified_user()
        rates = {"auth_ip": "10000/min", "auth_email": "2/hour"}
        with patch.object(SimpleRateThrottle, "THROTTLE_RATES", rates):
            for index, email in enumerate((self.email, "STUDENT@EXAMPLE.COM", "Student@Example.Com")):
                response = self.client.post(
                    "/api/auth/login/",
                    {"email": email, "password": "wrong"},
                    format="json",
                    REMOTE_ADDR=f"192.0.2.{index + 1}",
                )
                self.assertEqual(response.status_code, 401 if index < 2 else 429, response.content)
        self.assertEqual(response.json()["error"], "throttled")
        self.assertGreater(int(response["Retry-After"]), 0)
        self.assertFalse(EmailChallenge.objects.exists())
        self.assertFalse(AuthSession.objects.exists())

    def test_ip_throttle_does_not_trust_client_supplied_forwarded_headers(self):
        rates = {"auth_ip": "2/min", "auth_email": "10000/hour"}
        with patch.object(SimpleRateThrottle, "THROTTLE_RATES", rates):
            for index in range(3):
                response = self.client.post(
                    "/api/auth/login/",
                    {"email": f"unknown{index}@example.com", "password": "wrong"},
                    format="json",
                    REMOTE_ADDR="192.0.2.10",
                    HTTP_X_FORWARDED_FOR=f"198.51.100.{index + 1}",
                )
                self.assertEqual(response.status_code, 401 if index < 2 else 429, response.content)
        self.assertEqual(response.json()["error"], "throttled")
        self.assertGreater(int(response["Retry-After"]), 0)

    def test_malformed_json_and_non_object_payloads_return_validation_errors(self):
        for body in ('{"email":', "[]", "null", '"a string"'):
            with self.subTest(body=body):
                response = self.client.post(
                    "/api/auth/register/", body, content_type="application/json"
                )
                self.assertEqual(response.status_code, 400, response.content)
                self.assertIn("error", response.json())
                self.assertNotIn("Traceback", response.content.decode())
        self.assertFalse(User.objects.exists())
        self.assertFalse(EmailChallenge.objects.exists())
