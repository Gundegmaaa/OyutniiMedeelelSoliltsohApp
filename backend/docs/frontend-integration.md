# Frontend холбох гэрээ

Local API base: `http://localhost:8000`. Бүх endpoint төгсгөлдөө `/`-тэй. JSON хүсэлт илгээнэ. Нэвтрэлт болон бүртгэлийн баталгаажуулах төлөв Django session cookie ашиглана; бүртгэлээс эхлэн browser хүсэлт бүрд `credentials: "include"` хэрэгтэй.

## Бэлэн Flutter холболт

`frontend` доторх Flutter апп энэ auth API-тай холбогдсон. `AuthScreen` нь нэвтрэх, бүртгүүлэх, 6 оронтой код баталгаажуулах, код дахин авах form-уудтай. API клиент `frontend/lib/auth/auth_api.dart` дотор байна. Flutter web-ийн `BrowserClient.withCredentials = true` нь cookie илгээж, клиент нь POST-ийн өмнө CSRF token авч header-д нэмнэ. Login хариуны шинэ token-ыг хадгална; зөвхөн `csrf_failed` алдаанд token-оо сэргээж нэг удаа дахин оролдоно.

Бүртгүүлэх form нь оюутны код, нэр, овог, курс, мэйл, нууц үг, давтсан нууц үг авна. Баталгаажуулах дэлгэцийн мэйл зөвхөн унших боломжтой; бүртгэсэн эсвэл зөв нууц үгээр нэвтэрч эхлүүлсэн хаяг руу л код дахин авна. Шууд дурын мэйлээр баталгаажуулах тусдаа холбоос байхгүй. Өөр мэйл хэрэглэх бол бүртгүүлэх хэсгээс шинэ урсгал эхлүүлнэ.

Апп нээгдэх/refresh хийхэд `me`-ээр session сэргээнэ. Профайл нь backend-ийн бодит овог нэр, мэйл, эрх, оюутны код, курсийг харуулж, гарах үйлдэл API-аар одоогийн session-ийг дуусгана. “Төхөөрөмж дээр сануулах” нь browser дээр 30 хоногийн session ашиглана. Мэдээ, Community, quiz, бодлого, XP/rank өгөгдөл одоогоор demo хэвээр.

Frontend-ийг эхлүүлэх PowerShell команд, төслийн үндсэн хавтсаас:

```powershell
Set-Location .\frontend
flutter pub get
flutter run -d chrome --web-port 5173
```

Terminal аль хэдийн `frontend` дотор байвал `Set-Location` мөрийг алгасана. Browser-оор `http://localhost:5173` нээж `http://localhost:8000` backend ашиглана. API base-ийг өөрчлөх бол `flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://api.example.mn` гэж ажиллуулна; base утгад `/api/v1/auth/` нэмэхгүй.

Одоогийн local орчинд эзэмшигч Gmail SMTP тохируулсан. Шинэ орчинд [gmail-setup.md](gmail-setup.md) зааврын дагуу `backend/scripts/configure_gmail.py`-г өөрийн terminal дээр ажиллуулна. Скрипт Google App Password-ыг далд оролтоор авдаг. Console email тохиргоотой үед баталгаажуулах код Django terminal дээр гарна.

## Дараалал

1. `GET /api/v1/auth/csrf/` дуудаж `csrf_token` авна.
2. Бүх `POST` хүсэлтэд `X-CSRFToken` header нэмнэ. Бүртгэл болон нэвтрэх хүсэлтэд ч шаардлагатай.
3. Бүртгүүлэх → хариуны `email`-ийг баталгаажуулах хаяг болгон тогтоох → мэйлээс 6 оронтой код авах → ижил session-д `{email, code, password}` илгээж баталгаажуулах. Нууц үгээ баталгаажуулах хүртэл зөвхөн form-ийн санах ойд хадгална.
4. Мэйл + нууц үгээр нэвтрэх. Login хариуны шинэ `csrf_token`-оор өмнөх token-оо солино.
5. Хуудас шинэчлэхэд `me`-ээр session шалгана. Өөрчлөх хүсэлт илгээхийн өмнө CSRF token-оо дахин авна.
6. Logout амжилттай бол хэрэглэгчийн UI төлөвөө цэвэрлэнэ.

`sessionid` cookie нь `HttpOnly`: JavaScript уншихгүй, browser өөрөө илгээнэ. CSRF token-ыг тухайн хуудасны санах ойд хадгалж болно. Баталгаажуулалт нь автоматаар нэвтрүүлэхгүй; баталгаажуулсны дараа login дуудна.

Бүртгэл амжилттай эсвэл баталгаажаагүй хэрэглэгч зөв мэйл/нууц үгээр login хийхэд сервер 30 минутын `pending_verification` төлөвийг session-д хадгална: хэрэглэгчийн ID, мэйл, эхэлсэн хугацаа. Нууц үг энэ төлөвт хадгалагдахгүй. Кодын өөрийн хугацаа 10 минут байна. Verify/resend нь зөвхөн уг session болон түүнд холбосон мэйлд үйлчилнэ; амжилттай баталгаажуулахад төлөв цэвэрлэгдэнэ.

Нууц үгийг `localStorage`, `sessionStorage`, URL эсвэл log-д хадгалахгүй. Refresh хийж form-ийн мэдээллээ алдсан эсвэл серверийн төлөв дууссан бол мэйл + нууц үгээр нэвтрэхээс баталгаажуулалтыг үргэлжлүүлнэ. Амжилттай баталгаажуулсны дараа form утгаа цэвэрлэнэ. Curl/Postman ашиглахдаа бүртгэл, verify, resend-д ижил cookie jar хадгалж дамжуулна; curl-ийн `-c` болон `-b` нь нэг jar файл заах ёстой.

## Хүсэлт ба хариу

### CSRF

`GET /api/v1/auth/csrf/` → **200**

```json
{"csrf_token": "<token>"}
```

### Бүртгүүлэх

`POST /api/v1/auth/register/`

```json
{
  "email": "student@example.com",
  "student_code": "B24-001",
  "first_name": "Болд",
  "last_name": "Бат",
  "course": 2,
  "password": "Campus!River936",
  "password_confirm": "Campus!River936"
}
```

→ **202** `{"detail":"...","email":"student@example.com"}`. Хариуны `email` нь серверийн хэвийн болгосон хаяг; дараагийн verify/resend-д тогтмол хэрэглэнэ. Нууц үгийн шалгалт тэнцэхгүй эсвэл нэмэлт талбар байвал **400**. Бүртгэл бүр `student` эрхтэй; frontend `role`, `display_name` илгээхгүй.

Бүх талбар заавал байна. `student_code` нь 32 хүртэлх тэмдэгттэй: зайг цэвэрлэж том үсэгт шилжүүлнэ; үсэг/тоогоор эхэлж, Unicode үсэг, тоо, `_`, `-` агуулна. Код давхардахгүй. `first_name`, `last_name` тус бүр 150 хүртэлх тэмдэгттэй; `course` нь 1–6 бүхэл тоо байна. Сервер `display_name`-ийг `last_name + " " + first_name` хэлбэрээр үүсгэнэ, дээд урт 301 тэмдэгт.

Бүртгэлтэй мэйлд мөн ерөнхий **202** хариу өгнө. Дахин бүртгүүлэхэд өмнөх хувийн мэдээлэл, нууц үг солигдохгүй. Баталгаажаагүй бүртгэл байвал session-ийг түүнд холбоно; код дахин авахдаа тусдаа endpoint ашиглана. Аль хэдийн баталгаажсан мэйлд шинэ баталгаажуулах төлөв үүсэхгүй.

### Мэйл баталгаажуулах

`POST /api/v1/auth/verify-email/`

```json
{"email":"student@example.com","code":"012345","password":"Campus!River936"}
```

→ **200** `{"detail":"..."}`. Кодыг string илгээнэ: эхний `0` хадгалагдах ёстой. Код 10 минутын хугацаатай, нэг удаа ашиглана. Тав дахь буруу оролдлогын дараа эсвэл хугацаа дууссан бол шинэ код авна. Буруу, ашигласан, хугацаа дууссан код **400** буцаана.

Ижил бүртгэл/login урсгалын session cookie заавал байна. `email` нь session-д холбосон хаягтай таарна. Төлөв байхгүй/дууссан бол **400** `verification_required`; өөр мэйл илгээвэл **400** `verification_email_mismatch`. Амжилттай баталгаажуулсны дараа уг төлөв устна.

`password` заавал шаардлагатай бөгөөд бүртгэлийн нууц үгийн дүрмээр шалгана. Frontend нь бүртгүүлэхэд сонгосон нууц үгийг энэ хүсэлтээр дахин илгээнэ. Зөв кодоор мэйл баталгаажих болон нууц үг тогтоох үйлдэл нэг transaction-д хийгдэнэ. Ингэснээр хаягийг өмнө нь өөр хүн бүртгүүлсэн байсан ч мэйл эзэмшигч өөрийн сонгосон нууц үгээр бүртгэлээ баталгаажуулна. Аль хэдийн баталгаажсан хэрэглэгчийн нууц үгийг энэ endpoint солихгүй.

### Код дахин авах

`POST /api/v1/auth/resend-verification/`

```json
{"email":"student@example.com"}
```

→ **202** `{"detail":"..."}`. Ижил session-д холбосон `email`-ийг ашиглана. Илгээсний дараах 60 секундэд дахин авах хүсэлт **429** буцааж болно. Шинэ код өмнөх кодыг хүчингүй болгоно. Шууд дурын хаяг руу илгээхгүй: төлөв байхгүй/дууссан бол **400** `verification_required`; өөр мэйл бол **400** `verification_email_mismatch`.

### Нэвтрэх

`POST /api/v1/auth/login/`

```json
{"email":"student@example.com","password":"Campus!River936","remember_me":true}
```

→ **200**

```json
{
  "user": {
    "id": "<uuid>",
    "email": "student@example.com",
    "display_name": "Бат Болд",
    "first_name": "Болд",
    "last_name": "Бат",
    "student_code": "B24-001",
    "course": 2,
    "role": "student",
    "email_verified": true
  },
  "csrf_token": "<new-token>"
}
```

`remember_me` нь boolean, анхны утга `false`. `true` үед session 30 хоног; `false` үед browser хаах хүртэл, сервер дээр дээд тал нь 8 цаг. Энэ тохиргоо нууц үг хадгалахгүй. Login амжилттай болох бүрд CSRF token шинэчлэгдэнэ.

Буруу мэйл/нууц үг **401**, зөв нууц үгтэй боловч мэйл баталгаажаагүй бол **403** `email_not_verified`. Энэ **403** хариуны үед сервер session-д уг хэрэглэгчийн баталгаажуулах төлөвийг холбоно; cookie-г хадгалж, өөрчлөгдөхгүй мэйлтэй баталгаажуулах form руу шилжинэ. Нэвтрэх болгонд мэйл код шаардахгүй.

### Одоогийн хэрэглэгч

`GET /api/v1/auth/me/` → **200**

```json
{
  "user": {
    "id": "<uuid>",
    "email": "student@example.com",
    "display_name": "Бат Болд",
    "first_name": "Болд",
    "last_name": "Бат",
    "student_code": "B24-001",
    "course": 2,
    "role": "student",
    "email_verified": true
  }
}
```

Хүчинтэй нэвтрэлтгүй үед **401**. Боломжит role утгууд: `student`, `teacher`, `admin`. UI дээр role-оор харагдах үйлдлээ тохируулж болно; backend-ийн эрхийн шалгалтыг орлохгүй.

Өмнө үүсгэсэн хэрэглэгчийн `student_code`, `course` нь `null`, нэр/овог нь хоосон байж болно. Энэ нь нэвтрэлтийг хаахгүй; клиент эдгээр талбарт `null` хүлээн авна. Backend-ийн `0002_user_course_user_student_code_and_more` migration хуучин хэрэглэгч, өгөгдлийг хадгална.

### Гарах

`POST /api/v1/auth/logout/`, JSON body `{}` → **200** `{"detail":"..."}`. `X-CSRFToken` заавал илгээнэ. Одоогийн сервер session устаж, тухайн cookie-оор дахин нэвтрэх боломжгүй болно.

## Fetch жишээ

```javascript
const API = "http://localhost:8000";
let csrfToken;

async function bootstrapCsrf() {
  const response = await fetch(`${API}/api/v1/auth/csrf/`, {
    credentials: "include",
  });
  if (!response.ok) throw new Error("CSRF token авч чадсангүй");
  csrfToken = (await response.json()).csrf_token;
}

async function api(path, { method = "GET", body } = {}) {
  const unsafe = !["GET", "HEAD", "OPTIONS"].includes(method);
  if (unsafe && !csrfToken) await bootstrapCsrf();

  const headers = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (unsafe) headers["X-CSRFToken"] = csrfToken;

  const response = await fetch(`${API}${path}`, {
    method,
    headers,
    credentials: "include",
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const data = await response.json();
  if (!response.ok) {
    const error = new Error(data.error?.message ?? "Хүсэлт амжилтгүй");
    error.status = response.status;
    error.code = data.error?.code;
    error.details = data.error?.details;
    throw error;
  }
  if (data.csrf_token) csrfToken = data.csrf_token;
  return data;
}

// Бүртгэл, баталгаажуулалтын дэлгэцээс. Утгуудыг form-оос авна.
// pendingRegistration нь зөвхөн тухайн хуудасны санах ойд байна.
let pendingRegistration = {
  email: "student@example.com",
  student_code: "B24-001",
  first_name: "Болд",
  last_name: "Бат",
  course: 2,
  password: "Campus!River936",
};
const registration = await api("/api/v1/auth/register/", {
  method: "POST",
  body: {
    ...pendingRegistration,
    password_confirm: pendingRegistration.password,
  },
});
const verificationEmail = registration.email;
// Энэ хаягийг UI-д зөвхөн унших боломжтой харуулна, form-оос дахин авахгүй.
// Код ирээгүй бол 60 секундын дараа, баталгаажуулахаас өмнө:
// await api("/api/v1/auth/resend-verification/", {
//   method: "POST", body: { email: verificationEmail },
// });
// Дараа нь хэрэглэгчийн мэйлээс оруулсан кодыг ашиглана:
// await api("/api/v1/auth/verify-email/", {
//   method: "POST",
//   body: {
//     email: verificationEmail,
//     code,
//     password: pendingRegistration.password,
//   },
// });
// pendingRegistration = null; // Амжилттай баталгаажуулсны дараа.

// Login дэлгэцээс:
// const { user } = await api("/api/v1/auth/login/", {
//   method: "POST", body: { email, password, remember_me: true },
// });
// const { user: currentUser } = await api("/api/v1/auth/me/");
// await api("/api/v1/auth/logout/", { method: "POST", body: {} });
```

## Алдааны хэлбэр

```json
{
  "error": {
    "code": "validation_error",
    "message": "...",
    "details": {"email": ["..."]}
  }
}
```

`details` нь заавал байхгүй. `message`-ийн текстээр логик бичихгүй; HTTP status болон `error.code` ашиглана.

| Status | `error.code` | UI-ийн үйлдэл |
| --- | --- | --- |
| 400 | `validation_error` | `details`-аас талбарын алдаа харуулна |
| 400 | `invalid_code` | Кодыг шалгуулах эсвэл шинэ код авах боломж өгнө |
| 400 | `verification_required` | Бүртгэл эсвэл зөв мэйл/нууц үгийн login-оос баталгаажуулалтыг дахин эхлүүлнэ |
| 400 | `verification_email_mismatch` | Тогтсон мэйлээ шалгаж, зөв урсгалаас дахин эхлүүлнэ |
| 401 | `invalid_credentials`, `not_authenticated` | Нэвтрэх шаардлагатай эсвэл мэйл/нууц үг буруу |
| 403 | `email_not_verified` | Баталгаажуулах дэлгэц рүү шилжүүлнэ |
| 403 | `csrf_failed` | CSRF token/origin тохиргоог шалгана |
| 429 | `throttled` | Түр хүлээлгэнэ; `Retry-After` байгаа бол ашиглана |
| 503 | `email_delivery_failed` | Мэйл илгээж чадсангүй; дараа нь дахин оролдох боломж өгнө |

Auth endpoint-ууд IP болон мэйлээр хүсэлтийн давтамжийн хязгаартай. Товчийг дараалан олон дарахыг UI дээр хязгаарлана.

## Local origin тохиргоо

`.env`-ийн `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` хоёрт frontend-ийн яг origin-ыг оруулна. Жишээ нь `http://localhost:5173`. Origin нь protocol + hostname + port; зам болон төгсгөлийн `/` оруулахгүй. Flutter web өөр port ашиглавал хоёр жагсаалтад тэр port-оо нэмээд backend-ээ restart хийнэ.

Local үед frontend, API хоёул `localhost` хэрэглэнэ. Нэгийг нь `127.0.0.1` болгож холивол cookie/SameSite тохиргооноос шалтгаалж session ажиллахгүй байж болно. Production-д HTTPS болон `COOKIE_SECURE=true` хэрэгтэй. Хоорондоо өөр site дээр байрлуулах шаардлагатай бол `COOKIE_SAMESITE=None`, HTTPS болон browser-ийн third-party cookie бодлогыг хамтад нь шалгана.

Үндсэн хөгжүүлэлт, шалгалт Flutter web-д чиглэсэн. Native Flutter клиент нь session болон CSRF cookie-г санах ойн cookie jar-д хадгалж, POST-д CSRF header-аа илгээнэ. Native аппыг бүрэн хаагаад дахин нээхэд cookie үлдэхгүй тул `remember_me=true` байсан ч session-ийг сэргээхгүй; native-д тогтвортой хадгалалт хараахан хэрэгжээгүй.
