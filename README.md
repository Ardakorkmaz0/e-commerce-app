# E-Commerce & Inventory Platform

A small-scale e-commerce and inventory platform with a Django REST backend, Next.js web application, Flutter Android application, and PostgreSQL database.

![Python](https://img.shields.io/badge/Python-3.14-3776AB?logo=python&logoColor=white)
![Django](https://img.shields.io/badge/Django-5.2.17-0C4B33?logo=django&logoColor=white)
![Next.js](https://img.shields.io/badge/Next.js-16-black?logo=next.js)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.44.9-02569B?logo=flutter&logoColor=white)

## Current Stack

- **Backend:** Django REST Framework
- **Web:** Next.js, React, and TypeScript
- **Mobile:** Flutter for Android
- **Database:** PostgreSQL with Docker Compose
- **Admin:** Django Admin

## First-Time Setup

### Windows (PowerShell)

```powershell
# 1. Clone the repository
git clone https://github.com/Ardakorkmaz0/e-commerce-app.git
cd e-commerce-app

# 2. Create and activate the Python environment
python -m venv venv
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
.\venv\Scripts\Activate.ps1

# 3. Install backend dependencies
python -m pip install -r requirements.txt

# 4. Create the local environment file
notepad .env
```

Add these values to `.env`:

```env
POSTGRES_DB=ecommerce
POSTGRES_USER=ecommerce_user
POSTGRES_PASSWORD=replace_with_a_strong_password
DB_HOST=127.0.0.1
DB_PORT=5433
```

Continue in PowerShell:

```powershell
# 5. Start PostgreSQL and apply migrations
docker desktop start
docker compose up -d --wait db
python manage.py migrate
python manage.py createsuperuser

# 6. Install web dependencies
cd web
npm install
cd ..

# 7. Install mobile dependencies
cd mobile
flutter pub get
flutter doctor -v
cd ..
```

## Start the Project

Run one of these files from the project root:

```powershell
# PostgreSQL + Django API + Next.js
.\startweb.bat

# PostgreSQL + Django API + Android emulator + Flutter
.\startmobile.bat

# PostgreSQL + Django API + Next.js + Android emulator + Flutter
.\startwebamobile.bat
```

The scripts start Docker Desktop automatically when necessary. `startmobile.bat` and `startwebamobile.bat` use the `Pixel_8` emulator when no Android device is already connected.

## Stop the Project

The same stop file works for every start mode:

```powershell
.\stop.bat
```

It stops Django, Next.js, Flutter, the emulator started by the project, and Docker Compose services. The PostgreSQL volume and database data are preserved.

## Local Addresses

| Service | Address |
| --- | --- |
| Next.js web application | `http://localhost:3000/` |
| Django REST API | `http://127.0.0.1:8000/api/v1/` |
| Django Admin | `http://127.0.0.1:8000/admin/` |
| PostgreSQL from Windows | `127.0.0.1:5433` |
| Django API from Android through the start scripts | `http://127.0.0.1:8000/api/v1/` |

Django on port `8000` is backend-only. The customer-facing web interface runs on port `3000`.
The mobile start scripts configure ADB port forwarding automatically.

## Checks and Tests

```powershell
# Backend
.\venv\Scripts\python.exe manage.py check
.\venv\Scripts\python.exe manage.py test

# Web
cd web
npm run lint
npm run build

# Mobile
cd ..\mobile
flutter analyze
flutter test
```

## Useful Notes

- Run `python manage.py makemigrations` only after changing Django models.
- Run `flutter pub get` after cloning or changing `pubspec.yaml`.
- Run `npm install` after cloning or changing `web/package.json`.
- Redis is not configured yet.
- Web authentication uses Django JWT endpoints through HttpOnly Next.js cookies.
- Never commit `.env` or real database passwords.

## Author

**Arda Korkmaz**

- GitHub: [@Ardakorkmaz0](https://github.com/Ardakorkmaz0)
