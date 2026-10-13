# Backend ажиллуулах

Python 3.10–3.14 хэрэгтэй. Python 3.14, Django 5.2.18 дээр шалгасан.
Dependency хувилбарууд, database migration-ууд Git-д хадгалагдана.
Анхдагч тохиргоо SQLite ашигладаг тул тусдаа database сервер шаардлагагүй.

## Багийн гишүүн анх татахдаа

Repository-ийн үндсэн хавтсаас Windows PowerShell дээр:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver
```

Өмнө нь `.env` үүсгэсэн бол `Copy-Item` алхмыг алгасана.
Одоо байгаа `venv` нь өөр dependency хувилбартай байж болох тул дээрх `.venv`-ийг хэрэглэнэ.
PowerShell-ийн activation permission өөрчлөх шаардлагагүй.

macOS / Linux:

```bash
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
cp .env.example .env
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver
```

Дараагийн удаа кодоо шинэчлэхдээ `git pull`, dependency суулгах, `manage.py migrate` ажиллуулна.
`.env`, `.venv`, `venv`, SQLite database, cache нь Git-д орохгүй.
Багийн гишүүн бүр өөр `.env` болон өөрийн local database-тай байна.
Нэг database ашиглах шаардлагатай бол багийн shared MySQL серверийг тусад нь тохируулна.

## Мэйл баталгаажуулалт

Хөгжүүлэлтийн анхдагч горимд баталгаажуулах мэйлийн агуулга, 6 оронтой код backend-ийн terminal-д харагдана.
Энэ горимд бодит мэйл илгээхгүй. API response-д код буцаахгүй.

Бодит мэйл илгээхийн тулд `.env`-д:

```dotenv
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_USE_SSL=False
EMAIL_HOST_USER=your-address@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=Student Hub <your-address@gmail.com>
```

Эдгээр нь жишээ утга. Өөр SMTP үйлчилгээ ашиглавал тухайн үйлчилгээний host, port, credentials-ийг хэрэглэнэ.
Gmail ашиглахдаа 2-Step Verification идэвхжүүлээд App Password үүсгэнэ.
Өөрийн Gmail-ийн үндсэн нууц үгийг энд ашиглахгүй.
[Google-ийн App Password заавар](https://support.google.com/accounts/answer/185833).
Мэйл тохиргоогоо өөрчилсний дараа backend-ээ дахин асаана.
SMTP холболт/илгээлт бүтэлгүйтвэл API `503 email_unavailable` буцааж, ажиллахгүй шинэ код хадгалахгүй.
Өмнөх ажиллаж байсан кодыг resend-ийн бүтэлгүй илгээлт хүчингүй болгохгүй.

Код 10 минут хүчинтэй; нэг хүсэлт дээр нийт 5 удаа шалгаж болно.
Дахин код авахад 60 секунд хүлээнэ; нэг хүсэлт дээр анхны илгээлттэй нийлээд 5 удаа илгээж болно.
Resend шинэ код үүсгэж өмнөх кодыг хүчингүй болгоно. Буруу оролдлогын тоо reset болохгүй.
Бүртгэл/нэвтрэлт дахин эхлүүлэхэд мөн тухайн мэйл, үйлдэл дээр 60 секундийн хүлээлт үйлчилнэ.
Код, password, token нь database-д ил хэлбэрээр хадгалагдахгүй.

## API

Base URL: `http://127.0.0.1:8000`. Бүх POST request-д `Content-Type: application/json` хэрэглэнэ.
URL-ийн төгсгөлийн `/`-ийг оруулна.

| Method | URL | Үйлдэл |
| --- | --- | --- |
| GET | `/api/health/` | Сервер ажиллаж байгаа эсэх |
| POST | `/api/auth/register/` | Бүртгүүлэх код илгээх |
| POST | `/api/auth/register/verify/` | Бүртгэлээ кодоор батлах |
| POST | `/api/auth/login/` | Нууц үг шалгах, шинэ төхөөрөмжид код илгээх |
| POST | `/api/auth/login/verify/` | Нэвтрэх код батлах |
| POST | `/api/auth/resend-code/` | Код дахин авах |
| GET | `/api/auth/me/` | Нэвтэрсэн хэрэглэгч |
| POST | `/api/auth/logout/` | Одоогийн session-ээс гарах |
| GET | `/api/auth/devices/` | Санасан төхөөрөмжүүд |
| DELETE | `/api/auth/devices/<device_id>/` | Төхөөрөмжийн эрхийг хүчингүй болгох |

### 1. Бүртгүүлэх

`POST /api/auth/register/`

```json
{"email":"student@example.com","password":"StudyHub!2026Secure","full_name":"Оюутан"}
```

Мэйл хаягийг жижиг үсгээр нэг хэлбэрт оруулна. `full_name` заавал биш.
Нууц үг дор хаяж 8 тэмдэгт, нийтлэг нууц үг биш, дан тоо биш байх ёстой.
Код батлагдахаас өмнө хэрэглэгч үүсэхгүй.

Хариу `202`:

```json
{
  "verification_required": true,
  "challenge_id": "00000000-0000-0000-0000-000000000000",
  "purpose": "register",
  "expires_in": 600,
  "resend_after": 60,
  "message": "Баталгаажуулах код мэйл хаяг руу илгээгдлээ."
}
```

`challenge_id`-г бодит response-оос авч, мэйлээс авсан кодоор `POST /api/auth/register/verify/` дуудна:

```json
{"challenge_id":"response-оос-авсан-uuid","code":"123456"}
```

`code` нь string; эхний `0`-ийг хадгална. Жишээ кодыг өөрийн ирсэн кодоор солино.
Амжилттай батлахад хэрэглэгч үүсэж, автоматаар нэвтэрнэ. Хариу `200`:

```json
{
  "token": "opaque-session-token",
  "token_type": "Bearer",
  "expires_in": 7200,
  "user": {"id":1,"email":"student@example.com","full_name":"Оюутан","email_verified":true}
}
```

### 2. Нэвтрэх, төхөөрөмж санах

`POST /api/auth/login/`

```json
{
  "email":"student@example.com",
  "password":"StudyHub!2026Secure",
  "remember_device":true,
  "device_name":"Миний утас"
}
```

Шинэ төхөөрөмжид `202` ба `purpose: "login"` гэсэн кодын хүсэлт ирнэ.
`POST /api/auth/login/verify/` рүү `challenge_id`, `code`-оо өгнө.
Код батлагдах хүртэл session token олгохгүй.
`remember_device` анхдагчаар `false`; `device_name` заавал биш.

`remember_device: true` байсан бол нэвтрэлтийн амжилттай хариунд нэмэлтээр:

```json
{"device_token":"opaque-device-token","device_id":"device-uuid","device_expires_in":2592000}
```

Энэ `device_token`-ийг тухайн төхөөрөмж дээр хадгална. Дараагийн нэвтрэлтдээ:

```json
{"email":"student@example.com","password":"StudyHub!2026Secure","device_token":"өмнө-хадгалсан-device-token"}
```

30 хоногийн дотор хүчинтэй төхөөрөмжийн token + зөв нууц үг байвал шууд `200` session token авна.
Энэ тохиолдолд шинэ `device_token` буцаахгүй; хадгалсан token-оо үргэлжлүүлэн хэрэглэнэ.
Санасан төхөөрөмж нь нууц үг шалгахыг алгасахгүй.
Хүчингүй, хугацаа дууссан, өөр хэрэглэгчийн device token байвал дахин мэйл код шаардана.
Хугацаа автоматаар сунгагдахгүй.

### 3. Бусад дуудлага

Код дахин авах — `POST /api/auth/resend-code/`:

```json
{"challenge_id":"response-оос-авсан-uuid"}
```

`me`, `logout`, `devices` дуудлагуудын header:

```http
Authorization: Bearer opaque-session-token
```

Session 2 цаг хүчинтэй. Хугацаа дуусвал нэвтрэх урсгалаа дахин ажиллуулна.
Мобайл аппд session/device token-уудыг төхөөрөмжийн secure storage-д хадгална.

Гарах — `POST /api/auth/logout/`, body `{}`. `204` буцааж session хүчингүй болно.
Санасан төхөөрөмжийн эрхийг хамт цуцлах бол `{"forget_device":true}` өгнө.
Тэр төхөөрөмжөөр үүссэн бүх session хүчингүй болно; client талд token-уудаа устгана.

`GET /api/auth/devices/` нь өөрийн хүчинтэй төхөөрөмжийн metadata-тай array буцаана.
`DELETE /api/auth/devices/<device_id>/` нь тухайн төхөөрөмж болон түүнтэй холбоотой session-уудыг цуцална (`204`).
Бусдын төхөөрөмжийг харах/устгах боломжгүй (`404`).

Алдааны хэлбэр:

```json
{"error":"invalid_code","message":"Баталгаажуулах код буруу байна."}
```

| Status | Тайлбар |
| --- | --- |
| 400 | Талбарын утга, код, хугацаа эсвэл хүсэлтийн төрөл буруу |
| 401 | Нэвтрэх мэдээлэл/session token буруу, хугацаа дууссан |
| 404 | Хүсэлт/өөрийн төхөөрөмж олдоогүй |
| 409 | Мэйл хаяг бүртгэлтэй |
| 429 | Оролдлого/илгээлтийн хязгаар эсвэл хүлээлтийн хугацаа |
| 503 | Мэйл илгээх боломжгүй |

Validation алдаа `fields`-тэй; хүлээлттэй алдаа `retry_after` ба `Retry-After` header-тай байна.

## Flutter холбох

Postman-аар API шалгах collection, environment болон алхмууд: [postman/README.md](postman/README.md).

Flutter-ийн login/register UI нь дээрх API-г дуудах хэрэгтэй.
Web хөгжүүлэлтэд тогтмол port ашиглана:

```bash
flutter run -d chrome --web-port=3000
```

`.env`-ийн `CORS_ALLOWED_ORIGINS` нь Flutter-ийн origin-той таарна.
Android emulator-ийн backend URL: `http://10.0.2.2:8000`.
Бодит утас: компьютерийн LAN IP-г ашиглаж, тэр IP-г `DJANGO_ALLOWED_HOSTS`-д нэмээд
`manage.py runserver 0.0.0.0:8000` ажиллуулна. Компьютер, утас нэг сүлжээнд байна.
Production token дамжуулахдаа HTTPS хэрэглэнэ.

## Шалгалт, арчилгаа

```powershell
.\.venv\Scripts\python.exe manage.py check
.\.venv\Scripts\python.exe manage.py makemigrations --check --dry-run
.\.venv\Scripts\python.exe manage.py test accounts
.\.venv\Scripts\python.exe manage.py cleanup_auth
```

`cleanup_auth` хугацаа дууссан session/device, хугацаа дууссанаас хойш 7 хоног болсон кодын хүсэлтийг устгана.
`--days`-аар хүсэлт хадгалах хоногийг өөрчилж болно. Сервер дээр энэ командыг хуваариар ажиллуулж болно.
Admin хэрэгтэй бол `manage.py createsuperuser` ажиллуулж `/admin/`-аар орно.

API-д IP-аар 30 request/minute, email-аар 10 request/hour throttle бий.
Энэ throttle хөгжүүлэлтийн local-memory cache ашигладаг; олон process серверт Redis/shared cache болон gateway rate limit тохируулна.
Кодын оролдлого, дахин илгээлтийн тоо database-д хадгалагддаг.

## MySQL сонголт

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-mysql.txt
```

MySQL дээр `utf8mb4` database үүсгээд `.env`-д `DB_ENGINE=mysql` болон `DB_NAME`, `DB_USER`,
`DB_PASSWORD`, `DB_HOST`, `DB_PORT`-оо өгч `manage.py migrate` ажиллуулна.
Windows-д `mysqlclient` wheel байхгүй тохиолдолд тухайн Python хувилбарын build dependency шаардлагатай байж болно.
`DB_*` утгууд дангаараа SQLite тохиргоог солихгүй.

## Серверт ажиллуулах

`.env`-д `DJANGO_DEBUG=False`, санамсаргүй урт `DJANGO_SECRET_KEY`, зөв `DJANGO_ALLOWED_HOSTS`, SMTP тохиргоог өгнө.
`DJANGO_SECURE_SSL_REDIRECT` анхдагчаар асаалттай; HTTPS/reverse proxy тохиргоогоо тааруулна.
Production-д Django-ийн development `runserver`-ийн оронд WSGI/ASGI сервер ашиглана.
Мэйл backend болон secret key байхгүй бол production тохиргоо startup дээр алдаа өгнө.

Django мэйл тохиргооны дэлгэрэнгүй: [албан ёсны баримт](https://docs.djangoproject.com/en/5.2/topics/email/).
