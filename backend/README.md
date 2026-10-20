# Оюутны мэдээ, мэдээллийн систем — backend

Python 3.12+ · Django 5.2 LTS · Django REST Framework.

Эхний ээлжийн бүртгэл, мэйл баталгаажуулалт, нэвтрэх API. Flutter frontend auth API-тай холбогдсон. Бүртгүүлэхдээ мэйлээ нэг удаа баталгаажуулаад, цааш мэйл + нууц үгээр нэвтэрнэ.

## Ажиллуулах — Windows / PowerShell

Төслийн үндсэн хавтсаас:

```powershell
cd backend
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver
```

`py -3 --version` нь Python 3.12 буюу түүнээс шинэ хувилбар байх хэрэгтэй. Виртуал орчны Python-ыг шууд ашигладаг тул PowerShell-ийн activation script тохируулах шаардлагагүй. `.env` өмнө нь байгаа бол хуулж дарж бичихгүй, одоогийн тохиргоогоо хадгална.

Backend: `http://localhost:8000`. Health: `GET /health/` → `{"status":"ok"}`.
Үндсэн `/` хуудас backend/API хаягуудын жагсаалт болон health, admin холбоосуудыг харуулна.

`.env.example`-ийн анхны тохиргоогоор SQLite болон console email ашиглана: кодтой мэйл `runserver` terminal дээр гарна. Одоогийн local орчинд эзэмшигч Gmail SMTP тохируулсан; шинэ орчинд доорх SMTP зааврыг ашиглана.

Өмнөх хувилбараас шинэчилж байгаа бол `manage.py migrate` ажиллуулахад `0002_user_course_user_student_code_and_more` migration шинэ талбаруудыг нэмээд өмнөх хэрэглэгч, өгөгдлийг хадгална. Өмнө бүртгүүлсэн хэрэглэгчийн `student_code`, `course` нь `null` байж болох бөгөөд мэйл + нууц үгээрээ хэвийн нэвтэрнэ.

## Бэлэн боломжууд

- Оюутны код, нэр, овог, курс, мэйл, нууц үг болон давтсан нууц үгээр бүртгүүлэх; шинээр бүртгүүлсэн хэрэглэгч `student` эрхтэй.
- Мэйлээр ирэх 6 оронтой код болон хэрэглэгчийн сонгосон нууц үгээр баталгаажуулах. Зөв код хүлээн авахтай хамт нууц үгийг тогтооно. Код 10 минут хүчинтэй, 5 удаагийн буруу оролдлогын дараа хүчингүй болно.
- 60 секундын дараа код дахин авах. Шинэ код гармагц өмнөх код хүчингүй болно.
- Мэйл + нууц үгээр нэвтрэх. Баталгаажаагүй мэйлтэй хэрэглэгч нэвтрэхгүй.
- “Төхөөрөмж дээр сануулах”: сонговол 30 хоног; сонгоогүй бол browser session, серверийн дээд хугацаа 8 цаг.
- Өөрийн мэдээлэл авах, одоогийн session-оос гарах.
- Django admin-аар хэрэглэгч удирдах.

Бүртгэлийн `student_code` нь 32 хүртэлх тэмдэгттэй, үсэг/тоогоор эхэлж, Unicode үсэг, тоо, `_`, `-` агуулна; зайг цэвэрлэж том үсэгт шилжүүлнэ. Нэр, овог тус бүр 150 хүртэлх тэмдэгттэй, `course` нь 1–6 бүхэл тоо байна. `display_name`-ийг сервер `овог нэр` хэлбэрээр үүсгэнэ; бүртгэлийн хүсэлтэд илгээхгүй. Оюутны код давхардахгүй.

Нууц үг 10-аас доошгүй тэмдэгттэй, түгээмэл эсвэл дан тоон нууц үг биш байх ёстой. Django хэрэглэгчийн нэр/мэйлтэй хэт төстэй нууц үгийг мөн шалгана. Бүртгүүлэх хүсэлтээр `role`, `is_staff`, `is_superuser` зэрэг нэмэлт талбар илгээвэл 400 буцаана. Ижил мэйлээр дахин бүртгүүлэхэд одоогийн нууц үг өөрчлөгдөхгүй.

Баталгаажуулалт нь бүртгэл үүсгэсэн browser session-ийн тухайн мэйлд холбогдоно. Бүртгүүлэх эсвэл баталгаажаагүй хэрэглэгч зөв мэйл/нууц үгээр нэвтрэхэд 30 минутын баталгаажуулах төлөв үүснэ; нууц үгийг энэ төлөвт хадгалахгүй. Код баталгаажуулах/дахин авахдаа ижил cookie, ижил мэйл ашиглана. Баталгаажуулах дэлгэцэд мэйл солихгүй; өөр хаяг хэрэглэх бол бүртгэлээс шинэ урсгал эхлүүлнэ. Төлөв дууссан бол бүртгүүлэх эсвэл зөв мэйл/нууц үгээр нэвтрэхээс дахин эхэлнэ.

Нэвтрэлт нь серверт хадгалдаг Django session болон `HttpOnly` cookie ашиглана. `POST` хүсэлт бүр CSRF хамгаалалттай. Frontend холбох код, хүсэлт/хариуны гэрээ: [frontend-integration.md](docs/frontend-integration.md).

## API

| Method | URL | Зориулалт |
| --- | --- | --- |
| GET | `/` | Backend/API хаягуудын мэдээлэл |
| GET | `/health/` | Серверийн төлөв |
| GET | `/api/v1/auth/csrf/` | CSRF cookie болон token авах |
| POST | `/api/v1/auth/register/` | Бүртгүүлэх, баталгаажуулах код илгээх |
| POST | `/api/v1/auth/verify-email/` | Мэйл баталгаажуулах |
| POST | `/api/v1/auth/resend-verification/` | Код дахин авах |
| POST | `/api/v1/auth/login/` | Нэвтрэх |
| GET | `/api/v1/auth/me/` | Нэвтэрсэн хэрэглэгчийн мэдээлэл |
| POST | `/api/v1/auth/logout/` | Одоогийн session-оос гарах |

## Админ

```powershell
.\.venv\Scripts\python.exe manage.py createsuperuser
```

`http://localhost:8000/admin/` хаягаар нэвтэрнэ. Мэйл болон харагдах нэрийг команд асууна. Нийтийн бүртгэлээс багш/админ эрх авах боломжгүй. Багшийн `role=teacher`-ийг итгэмжлэгдсэн админ тохируулна. Django admin-д нэвтрэх эрх нь `is_staff`/`is_superuser` тохиргоогоор тусдаа хянагдана.

## Бодит мэйл ба PostgreSQL

`.env.example` дотор SMTP болон PostgreSQL-ийн жишээ байна. Мэйл үйлчилгээний `EMAIL_HOST`, `EMAIL_PORT`, хэрэглэгч, нууц үг, илгээгчийн хаягийг өөрийн үйлчилгээний утгаар солино. TLS ба SSL-ийг зэрэг идэвхжүүлэхгүй. Одоогийн local Gmail SMTP тохиргоо `.env`-д байгаа; энэ файл болон нууц мэдээлэл repository-д орохгүй.

Gmail ашиглах бол [Gmail тохируулах заавар](docs/gmail-setup.md)-ын дагуу Google дансандаа 2-Step Verification асааж App Password үүсгээд `backend` хавтас дотроос `.\.venv\Scripts\python.exe .\scripts\configure_gmail.py` ажиллуулна. Скрипт нууц үгийг дэлгэц дээр харуулахгүй, SMTP нэвтрэлт амжилттай болсон үед `.env`-ийн мэйл тохиргоог хадгална. Дараа нь Django серверээ дахин асаана.

PostgreSQL хэрэглэх бол database, user-ээ үүсгээд `DB_ENGINE=postgresql`, `POSTGRES_*` утгуудыг тохируулж `manage.py migrate` ажиллуулна. SQLite-ийн өгөгдөл PostgreSQL руу автоматаар хуулахгүй.

Production-д `DJANGO_DEBUG=false`, санамсаргүй үүсгэсэн дор хаяж 50 тэмдэгттэй `DJANGO_SECRET_KEY`, PostgreSQL, бодит SMTP, зөв domain/origin, HTTPS болон `COOKIE_SECURE=true` шаардлагатай. Secret болон SMTP нууц үгээ repository-д оруулахгүй. `runserver` нь хөгжүүлэлтийн сервер; deployment хийхдээ WSGI/ASGI сервер, HTTPS прокси, static файл, нөөцлөлтөө тусад нь тохируулна. Нэг domain-ийн дэд domain-уудаар frontend/API-г байрлуулах нь session cookie холбоход тохиромжтой.

Одоогийн auth throttle нь process тус бүрийн санах ойн cache ашиглана. Олон worker-тэй production-д нийт worker-уудын shared cache болон/эсвэл API gateway-ийн rate limiting тохируулах шаардлагатай; эдгээрийг одоогоор тохируулаагүй. `NUM_PROXIES`-ийг өөрчлөхөөс өмнө итгэмжлэгдсэн proxy-уудаар клиент IP хэрхэн дамжихыг тохируулж шалгана.

Хугацаа дууссан session мөрүүдийг үе үе цэвэрлэхээр scheduler тохируулна:

```powershell
.\.venv\Scripts\python.exe manage.py clearsessions
```

## Шалгах

```powershell
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\.venv\Scripts\python.exe manage.py test
```

Бүртгэл → мэйлээс код авах (console backend бол terminal-аас) → ижил browser session-д баталгаажуулах → нэвтрэх → `me` → гарах дарааллаар frontend-ээс туршина. CSRF шаардлага, буруу код, хугацаа дуусалт, session-ийн хугацаа, баталгаажуулах мэйл/session-ийн хязгаарлалтыг автомат тестүүдээр шалгана.

Мэдээ, ангилал, бодлого, quiz, rank-ийн дараагийн ажлууд: [roadmap.md](docs/roadmap.md).

Session-ийн тайлбар: [Django sessions](https://docs.djangoproject.com/en/5.2/topics/http/sessions/). Cookie ашиглах API-ийн CSRF/CORS тайлбар: [Django REST Framework](https://www.django-rest-framework.org/topics/ajax-csrf-cors/).
