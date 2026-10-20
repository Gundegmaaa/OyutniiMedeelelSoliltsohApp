# Gmail-аар баталгаажуулах код илгээх

Энэ тохиргоо backend-ээс бүртгэлийн кодтой мэйл илгээхэд зориулагдана. Оюутан өөрийн мэйл, нууц үгээр аппад нэвтэрдэг урсгал хэвээр байна.

1. Мэйл илгээх Google дансандаа [2-Step Verification идэвхжүүлнэ](https://support.google.com/accounts/answer/185839?hl=en).
2. [App Passwords](https://myaccount.google.com/apppasswords) нээгээд `Student News` нэртэй App Password үүсгэнэ. Google-ийн [App Password заавар](https://support.google.com/accounts/answer/185833?hl=en)-ын дагуу 2-Step Verification асаалттай байх шаардлагатай. Google дансны ердийн нууц үгийг ашиглахгүй.
3. Төслийн үндсэн `medeelel web` хавтаснаас PowerShell дээр ажиллуулна:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\scripts\configure_gmail.py
```

`backend` хавтас дотор байгаа бол:

```powershell
.\.venv\Scripts\python.exe .\scripts\configure_gmail.py
```

Скрипт Gmail хаяг болон App Password асууна. Нууц үг бичихэд дэлгэц дээр харагдахгүй; Google-ээс хуулсан дөрвөн хэсгийн хоорондох зайг автоматаар арилгана. App Password-аа чатад, frontend кодод эсвэл командын аргументад бичихгүй.

Скрипт `smtp.gmail.com:587` серверт STARTTLS ашиглан холбогдож нэвтрэх эрхийг шалгана. Энэ алхам мэйл илгээхгүй. Амжилттай болсны дараа л `backend/.env` дотор мэйлийн тохиргоог хадгална; бусад тохиргоо, тайлбарууд хадгалагдана. Мэйлээ хоосон орхих, `Ctrl+C` дарах, эсвэл холболт/нэвтрэлт амжилтгүй болбол `.env` өөрчлөгдөхгүй. Сервер болон портыг [Google-ийн SMTP заавраас](https://support.google.com/mail/answer/7104828?hl=en) шалгаж болно.

`backend/.env` байхгүй бол эхлээд `.env.example`-ийг хуулна. Өмнө нь байгаа `.env`-ийг хуулж дарж бичихгүй. Скрипт ажиллуулахад нэмэлт Python сан суулгах шаардлагагүй.

Тохируулсны дараа Django серверээ `Ctrl+C` дарж зогсоогоод дахин асаана:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\manage.py runserver
```

Хадгалсан тохиргоогоор дахин холбогдож шалгах команд:

```powershell
.\backend\.venv\Scripts\python.exe .\backend\scripts\configure_gmail.py --check
```

`--check` нь `.env`-ийг өөрчлөхгүй, мэйл илгээхгүй. Бодит хүргэлтийг frontend-ээс өөрийн мэйлээр шинээр бүртгүүлж шалгана. Inbox болон Spam хавтсаа шалгаад ирсэн 6 оронтой кодыг аппад оруулна.

Скриптийн хадгалах тохиргоо:

```dotenv
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=true
EMAIL_USE_SSL=false
EMAIL_HOST_USER=your-account@gmail.com
EMAIL_HOST_PASSWORD=your-16-character-app-password
DEFAULT_FROM_EMAIL='Student News <your-account@gmail.com>'
```

Дээрх нууц үг нь жишээ тул шууд хуулж ашиглахгүй. `.env` Git-д орохгүй байх ёстой. Backend ажиллуулж буй terminal-д `EMAIL_*` хувьсагч өмнө нь тохируулсан бол тэдгээр нь `.env`-ийн утгыг давж үйлчилж болзошгүй.

App Password сонголт харагдахгүй бол байгууллага/сургуулийн дансны бодлого, зөвхөн security key ашигладаг 2-Step Verification, эсвэл Advanced Protection нөлөөлж болно. Байгууллагын данс бол админтайгаа тохирно. Google дансны нууц үгийг сольсноор App Password хүчингүй болдог тул шинээр үүсгээд скриптээ дахин ажиллуулна. [Google-ийн тайлбар](https://support.google.com/accounts/answer/185833?hl=en).

Gmail тохируулах хүртэл анхны `console.EmailBackend` тохиргоотой үед код Django серверийн terminal дээр гарна.
