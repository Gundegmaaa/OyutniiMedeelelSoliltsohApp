# Backend-ийг Postman-аар шалгах

Энэ хавтасны collection нь Postman v2.1 форматтай бөгөөд зөвхөн `base_url` дахь локал backend руу хүсэлт илгээнэ. Бүртгэл, мэйл код, төхөөрөмж сануулах, session болон logout-ийг 16 хүсэлтээр шалгана.

## Postman-д импортлох

1. Postman → **Import** → `StudentHub.postman_collection.json` болон `StudentHub.postman_environment.json` хоёр файлыг сонгоно.
2. Баруун дээд талын environment сонголтоос **Student Hub Local**-ийг сонгоно.
3. `base_url` нь `http://127.0.0.1:8000` байна. Backend ажиллаж байгаа эсэхийг `01 Health` → **Send**-ээр шалгана.

`01 Health` явуулах бүрд `postman-<timestamp>@example.com` гэсэн шинэ туршилтын мэйл үүсэж, өмнөх run-ийн код болон token утгууд цэвэрлэгдэнэ. Жишээ нууц үг `BlueMoon!River9847`, нэр `Postman Test` байна.

## Хүсэлтүүдийг дарааллаар явуулах

1. `01 Health`, дараа нь `02 Register` явуулна. Хүлээгдэх HTTP төлөв нь `200`, `202`.
2. Backend terminal дээр гарсан **бүртгэлийн зургаан оронтой кодыг** environment-ийн `registration_code` утгад оруулж хадгална. Кодын эхний `0`-ийг хэвээр оруулна.
3. Бүртгүүлснээс хойш **60 секундийн дотор** `03 Resend cooldown` явуулна. `429` нь зөв үр дүн: шууд дахин код илгээхийг хязгаарласныг шалгана.
4. `04 Wrong registration code` явуулна. Скрипт бодит кодоос өөр код сонгох бөгөөд `400` хүлээнэ. Дараа нь `05 Register verify` → `200`, `06 Duplicate register` → `409`.
5. `07 Login with remember device` явуулна. `202` хүлээн авсны дараа terminal дээр гарсан **нэвтрэх шинэ кодыг** environment-ийн `login_code` утгад оруулж хадгална.
6. `08 Login verify`-ээс `16 Logout registration session` хүртэл үлдсэн хүсэлтүүдийг дугаарын дарааллаар **Send** хийнэ.

Мэйл код 10 минут хүчинтэй. Хариу бүрийн **Test Results** ногоон болсон эсэхийг харна. Хүлээгдэж байгаа `400`, `401`, `409`, `429` хариунууд нь collection-ийн алдаатай оролдлогыг шалгах хэсэг.

Console email backend ашиглаж байгаа тул жишээ `example.com` хаягт бодит мэйл очихгүй. SMTP-ээр шалгах үед өөрийн бодит мэйл болон backend-ийн SMTP тохиргоог ашиглана; collection-ийн `01 Health` үүсгэсэн `email`-ийг `02 Register` явуулахаас өмнө өөрчилнө.

## Terminal-ийн оронд logfile-оос код авах

Backend арын процессоор ажиллаж байгаа бөгөөд logfile үүссэн бол `backend` хавтсаас PowerShell дээр:

```powershell
Get-Content .\.venv\postman-server.log -Tail 60 -Encoding UTF8
```

Хамгийн сүүлд гарсан `Таны бүртгэлээ баталгаажуулах код:` эсвэл `Таны нэвтрэх код:` мөрийг ашиглана. Нэг мөрийн мэйл хүлээн авагч нь environment-ийн `email` утгатай таарч байгаа эсэхийг шалгана.

## Хүлээгдэх үр дүн

| Хүсэлт | HTTP | Шалгах үйлдэл |
| --- | --- | --- |
| 01 Health | 200 | Backend ажиллаж байна |
| 02 Register | 202 | Бүртгэлийг мэйлээр батална |
| 03 Resend cooldown | 429 | 60 секундийн дахин илгээх хязгаар |
| 04 Wrong registration code | 400 | Буруу кодоор session авахгүй |
| 05 Register verify | 200 | Баталгаажсан хэрэглэгч, Bearer session |
| 06 Duplicate register | 409 | Давхардсан мэйлээр бүртгүүлэхгүй |
| 07 Login with remember device | 202 | Шинэ нэвтрэх мэйл код |
| 08 Login verify | 200 | Session болон төхөөрөмжийн token |
| 09 Me | 200 | Баталгаажсан хэрэглэгчийн мэдээлэл |
| 10 Devices | 200 | Сануулсан төхөөрөмжийн мэдээлэл, нууц token агуулахгүй |
| 11 Remembered login | 200 | Нууц үг + төхөөрөмжийн token-оор дахин OTP-гүй нэвтрэх |
| 12 Logout and forget device | 204 | Төхөөрөмж болон түүнтэй холбоотой session-үүдийг хаах |
| 13 Revoked second session | 401 | Тэр төхөөрөмжийн хоёр дахь session ажиллахгүй |
| 14 Unauthenticated me | 401 | Token-гүй хувийн мэдээлэл авахгүй |
| 15 Invalid password | 401 | Буруу нууц үгээр нэвтрэхгүй |
| 16 Logout registration session | 204 | Бүртгэлийн үед үүссэн session-ийг хаах |

Collection-ийн scripts нь challenge, user болон token утгуудыг environment-д автоматаар хадгална. `session_token` нь төхөөрөмж сануулсан эхний session, `second_session_token` нь `11 Remembered login`-ийн session, `register_session_token` нь бүртгэлийн үед үүссэн session. Экспортын файлуудад бодит код/token хадгалаагүй.

Дахин бүтэн шалгахдаа `01 Health`-ээс эхэлнэ. Олон run-ийг хурдан давтвал нэг IP-д минутанд 30 хүсэлтийн хязгаар үйлчилнэ; 60 секунд хүлээгээд шинэ run эхлүүлнэ. Бүртгүүлсэн туршилтын хэрэглэгч database-д үлдэнэ, харин сүүлийн logout хүсэлтүүд энэ run-ийн бүх session-ийг хаана.

Postman environment-ийн API: [Variables reference](https://learning.postman.com/docs/tests-and-scripts/write-scripts/postman-sandbox-reference/pm-variables/).
