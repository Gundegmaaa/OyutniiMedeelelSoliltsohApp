# МТС — Оюутны мэдээллийн систем

Мандах Их Сургуулийн Мэдээлэл, технологийн сургуулийн оюутнуудад зориулсан Flutter апп. Нэвтрэх, бүртгүүлэх, мэйл баталгаажуулах хэсэг Django backend-тэй холбогдсон. Мэдээ, Community, quiz, бодлого, XP/rank хэсэг demo өгөгдөлтэй хэвээр байна.

## Хуудас, үйлдлүүд

- **Нэвтрэлт:** мэйл + нууц үгээр нэвтрэх; оюутны код, нэр, овог, курс, мэйл, нууц үг, давтсан нууц үгээр бүртгүүлэх; мэйлийн 6 оронтой код баталгаажуулах; код дахин авах. Алдааг form дээр харуулна.
- **Баталгаажуулах хаяг:** бүртгэл эсвэл баталгаажаагүй хэрэглэгчийн зөв нууц үгтэй login-оос эхэлнэ. Баталгаажуулах дэлгэцийн мэйл өөрчлөгдөхгүй; код дахин авахад тэр хаягийг ашиглана. Дурын мэйлээр баталгаажуулах тусдаа холбоос байхгүй.
- **Session:** апп нээгдэхэд `/api/v1/auth/me/`-ээр нэвтрэлтийг сэргээнэ. “Төхөөрөмж дээр сануулах” сонголт browser дээр 30 хоногийн session үүсгэнэ; сонгоогүй үед browser session, серверийн дээд хугацаа 8 цаг.
- **Нүүр:** шинэ зарлалын дэлгэрэнгүй, өнөөдрийн хичээл, гараг сонгох долоо хоногийн хуваарь.
- **Community:** Бүгд / Зар / Асуулт / Багш шүүлтүүр; зар, асуулт нийтлэх; үнэ оруулах; like хийх; сэтгэгдэл бичих. Багш, сургалтын албаны зарлал demo өгөгдөлтэй.
- **Сургалт:** Software Engineering / Information System хөтөлбөр сонгох; хөтөлбөр бүрийн 3 асуулттай quiz; хялбар / дунд / хүнд богино бодлого; зөв хариултын тайлбар; XP, жишээ rank.
- Доод цэсний **Профайл** товч backend-ээс ирсэн бодит нэр, мэйл, эрхийг bottom sheet-ээр харуулна. **Системээс гарах** товч серверийн одоогийн session-ийг дуусгаж нэвтрэх дэлгэц рүү буцаана.
- Баруун дээд товчоор гэгээтэй / харанхуй горим солино. Хуудас бүр гүйлгэгддэг; өргөн дэлгэц дээр агуулгын өргөн хязгаарлагдана.

## Ажиллуулах

Flutter stable SDK (Dart 3.8+) ба Chrome шаардлагатай. Windows дээр Flutter SDK-ийн `bin` хавтсыг PATH-д нэмсэн байна. Үндсэн хөгжүүлэлт, шалгалт Flutter web-д чиглэсэн.

Эхлээд [backend-ийн заавраар](../backend/README.md) Python орчин, `.env`, database-аа бэлтгэнэ. Төслийн үндсэн `medeelel web` хавтас дахь эхний PowerShell terminal-аас backend-ээ ажиллуулна:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\manage.py runserver
```

Хоёр дахь PowerShell terminal-ыг төслийн үндсэн хавтсанд нээгээд:

```powershell
Set-Location .\frontend
flutter pub get
flutter run -d chrome --web-port 5173
```

Terminal аль хэдийн `frontend` хавтас дотор байвал `Set-Location .\frontend` мөрийг алгасана; `frontend\frontend` хавтас руу орохгүй.

Chrome-ийн debug холболт тогтохгүй бол `frontend` хавтас дотроос дараах командаар ажиллуулаад браузертаа `http://localhost:5173` нээнэ:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 5173
```

Frontend: `http://localhost:5173`; backend: `http://localhost:8000`. Хоёуланд нь `localhost` хэрэглэнэ, `127.0.0.1`-тэй хольж ашиглахгүй. Backend-ийн `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` тохиргоонд `http://localhost:5173` орсон байх хэрэгтэй.

Өөр API сервер ашиглах бол `frontend` хавтсаас:

```powershell
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://api.example.mn
```

`API_BASE_URL` нь API-ийн үндсэн origin байна; `/api/v1/auth/` замыг нэмэхгүй. Энэ нь build/run үеийн тохиргоо тул өөрчилбөл дахин ажиллуулна. HTTPS API дээр cookie, CORS, CSRF origin-ыг deployment-ийн domain-ууддаа тааруулна. Нарийвчилсан гэрээ: [frontend-integration.md](../backend/docs/frontend-integration.md).

## Gmail ба бүртгэлийн урсгал

Gmail илгээгчийн хаяг, Google App Password-ыг эзэмшигч өөрийн terminal дээр оруулж тохируулна. Төслийн үндсэн хавтсаас:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\scripts\configure_gmail.py
```

Нууц үгийн оролт дэлгэц дээр харагдахгүй. Скрипт SMTP нэвтрэлтийг шалгаад амжилттай бол `backend/.env`-д хадгална; дараа нь backend-ээ restart хийнэ. Google App Password үүсгэх болон тохиргоог шалгах дэлгэрэнгүй заавар: [gmail-setup.md](../backend/docs/gmail-setup.md). Одоогийн local орчинд эзэмшигч Gmail SMTP тохируулсан; дээрх команд шинэ орчны тохиргоонд зориулагдсан. Анхны console email тохиргоотой үед код backend terminal дээр гарна.

1. Апп дээр **Бүртгүүлэх** сонгоод оюутны код, нэр, овог, курс (1–6), мэйл, нууц үг, давтсан нууц үгээ илгээнэ. Оюутны код 32 хүртэлх Unicode үсэг, тоо, `_`, `-` тэмдэгттэй, үсэг/тоогоор эхэлнэ; нэр, овог тус бүр 150 хүртэлх тэмдэгттэй.
2. Ижил browser session-д мэйлээс авсан 6 оронтой кодоо оруулна. Баталгаажуулах дэлгэцийн мэйл зөвхөн унших боломжтой; код дахин авах нь мөн уг хаягт илгээнэ. Кодтой хамт сонгосон нууц үгийг backend рүү илгээнэ; нууц үг зөвхөн form-ийн санах ойд хадгалагдана.
3. Баталгаажуулалт амжилттай болсны дараа мэйл + нууц үгээр нэвтэрнэ. Нэвтрэх болгонд код шаардахгүй.
4. Профайл дээр нэр, мэйл, эрхээ шалгаж, хуудас refresh хийхэд session сэргэж байгааг шалгана. Дараа нь **Системээс гарах** товчоор гарна.

Код 10 минут, серверийн баталгаажуулах төлөв 30 минут хүчинтэй. Form-ийн мэдээлэл алдагдсан эсвэл төлөв дууссан бол мэйл + нууц үгээр нэвтрэхээс үргэлжлүүлнэ; өөр хаяг хэрэглэх бол бүртгэлээс шинэ урсгал эхлүүлнэ. `verification_required` эсвэл `verification_email_mismatch` алдаанд апп нэвтрэх хэсэг рүү буцаана. Backend ижил session cookie болон түүнд холбосон мэйлийг заавал шалгана.

API нь бүртгэлд `display_name` авдаггүй; `овог нэр` хэлбэрээр үүсгэнэ. Хэрэглэгчийн хариунд нэр, овог, оюутны код, курс нэмэгдсэн. Өмнө бүртгүүлсэн хэрэглэгчийн код, курс `null` байж болох бөгөөд тэд өмнөх мэйл/нууц үгээрээ нэвтэрч болно; backend-ийн шинэ migration өгөгдлийг хадгална.

## Шалгах, build хийх

Доорх командуудыг `frontend` хавтас дотроос ажиллуулна:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

Өөр production API-тай build хийхдээ `flutter build web --dart-define=API_BASE_URL=https://api.example.mn` хэрэглэнэ.

Native Flutter клиент cookie-г одоогоор зөвхөн санах ойд хадгална. Аппыг бүрэн хаагаад дахин нээхэд “Төхөөрөмж дээр сануулах” сонголт session-ийг сэргээхгүй. Native төхөөрөмжөөс хөгжүүлэлтийн backend-д холбогдохдоо тухайн төхөөрөмжөөс хүрэх API хаяг, backend host/network тохиргоог тусад нь шийднэ. Android build-д Android SDK, JDK; iOS build-д macOS + Xcode шаардлагатай.

## Кодын бүтэц

```text
lib/
  main.dart                   # Session сэргээх, аппын төлөв, цэс, профайл
  auth/auth_api.dart          # Backend API, CSRF, алдааны боловсруулалт
  auth/auth_user.dart         # Backend хэрэглэгчийн мэдээлэл
  auth/http_client_web.dart   # BrowserClient.withCredentials
  auth/http_client_io.dart    # Native, санах ойн cookie jar
  theme.dart                  # Өнгө, light/dark theme
  models/post.dart            # Нийтлэл, demo өгөгдөл
  models/learning.dart        # Quiz, бодлого, XP
  screens/auth_screen.dart    # Нэвтрэх / бүртгүүлэх / мэйл баталгаажуулах
  screens/home_screen.dart
  screens/community_screen.dart
  screens/learning_screen.dart
  widgets/ui.dart             # Дахин ашиглах карт, товч, таб
test/auth_api_test.dart       # API хүсэлт, CSRF, session/error contract
test/auth_flow_test.dart      # Бүртгэл, баталгаажуулалт, нэвтрэх UI
test/app_test.dart            # Үндсэн үйлдлийн widget/unit шалгалт
```

## Прототипийн хязгаар

Нэвтрэлт, бүртгэл, мэйл баталгаажуулалт, хэрэглэгчийн мэдээлэл болон гарах үйлдэл бодит backend API ашиглана. Web дээр browser нь `HttpOnly` session cookie-г хадгалж, API клиент cookie болон CSRF token-ыг хүсэлтэд дамжуулна.

Мэдээ, Community, сургалтын demo өгөгдөл аппын санах ойд хадгалагдана: хуудас солиход үлдэнэ, аппыг дахин эхлүүлэхэд эсвэл гарахад reset хийнэ. Мэдээний API, бодит чат, багшийн мэдээ удирдах эрх, серверийн quiz/оноо/rank дараагийн шатанд холбогдоно. Сэтгэгдэл нь нийтлэл доторх харилцааны demo юм.

Quiz-ийн зөв хариулт бүр 20 XP; бодлого 20 / 40 / 60 XP өгнө. Үйл ажиллагаа тус бүрийн XP-г нэг удаа авна. Rank-ийн эхний гурван оюутан тогтмол жишээ өгөгдөл бөгөөд бусад оюутны бүтэн жагсаалт байхгүй тул тэднийг даваагүй үед өөрийн байр #12 хэвээр байна. Энэ нь бодит сургуулийн чансаа биш.
