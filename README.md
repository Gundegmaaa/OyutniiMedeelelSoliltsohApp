# Оюутны мэдээлэл солилцох апп

- `backend/`: Django REST API — мэйлээр баталгаажуулдаг бүртгэл, нэвтрэлт, төхөөрөмж санах.
- `frontend/`: Flutter төсөл.

Backend-ийг GitHub-ээс татаж ажиллуулах, мэйл илгээх, Flutter-тэй холбох заавар болон API жишээг [backend/README.md](backend/README.md)-ээс үзнэ үү.

```powershell
git clone https://github.com/Gundegmaaa/OyutniiMedeelelSoliltsohApp.git
cd OyutniiMedeelelSoliltsohApp/backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.\.venv\Scripts\python.exe manage.py migrate
.\.venv\Scripts\python.exe manage.py runserver
```

`http://127.0.0.1:8000/api/health/` → `{"status":"ok"}`.
