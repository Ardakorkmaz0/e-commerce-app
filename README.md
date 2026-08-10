# 🛒 E-Commerce & Inventory Platform

A small-scale e-commerce and inventory management project with a Django web application, PostgreSQL database, and Flutter Android application.

![Python](https://img.shields.io/badge/Python-3.14-3776AB?logo=python&logoColor=white)
![Django](https://img.shields.io/badge/Django-5.2.17-0C4B33?logo=django&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.44.9-02569B?logo=flutter&logoColor=white)

## Current Stack

- **Backend:** Django 5.2.17
- **Web UI:** Django templates and Bootstrap
- **Database:** PostgreSQL 18 with Docker Compose
- **Mobile:** Flutter for Android
- **API dependencies:** Django REST Framework and SimpleJWT
- **Planned:** REST API integration, Redis, and Next.js

## Prerequisites

Install the following tools before starting:

- Git
- Python 3.14
- Docker Desktop on Windows/macOS, or Docker Engine with Compose on Linux
- Flutter SDK
- Android Studio, Android SDK, and an Android emulator

Verify the main tools:

```powershell
python --version
docker --version
docker compose version
flutter --version
flutter doctor -v
```

## 🚀 First-Time Setup

### Windows (PowerShell)

```powershell
# 1. Clone the repository from GitHub
git clone https://github.com/Ardakorkmaz0/e-commerce-app.git

# 2. Navigate into the project directory
cd e-commerce-app

# 3. Create a virtual environment named venv
python -m venv venv

# 4. Allow activation for the current PowerShell session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# 5. Activate the virtual environment
.\venv\Scripts\Activate.ps1

# 6. Install all required Python packages
python -m pip install -r requirements.txt

# 7. Create the local environment file
notepad .env
```

Add the following values to `.env`, then save the file:

```env
POSTGRES_DB=ecommerce
POSTGRES_USER=ecommerce_user
POSTGRES_PASSWORD=replace_with_a_strong_password
DB_HOST=127.0.0.1
DB_PORT=5433
```

Continue in PowerShell:

```powershell
# 8. Start Docker Desktop
docker desktop start

# Wait until Docker Desktop is ready, then start PostgreSQL
docker compose up -d --wait db

# 9. Apply the existing Django migrations
python manage.py migrate

# 10. Create an administrative user
python manage.py createsuperuser

# 11. Install the Flutter dependencies
cd mobile
flutter pub get

# 12. Check the Android development environment
flutter doctor -v

# Return to the project root
cd ..
```

### macOS / Linux (Bash)

```bash
# 1. Clone the repository from GitHub
git clone https://github.com/Ardakorkmaz0/e-commerce-app.git

# 2. Navigate into the project directory
cd e-commerce-app

# 3. Create a virtual environment named venv
python3 -m venv venv

# 4. Activate the virtual environment
source venv/bin/activate

# 5. Install all required Python packages
python -m pip install -r requirements.txt

# 6. Create and edit the local environment file
nano .env
```

Add the following values to `.env`, then save the file:

```env
POSTGRES_DB=ecommerce
POSTGRES_USER=ecommerce_user
POSTGRES_PASSWORD=replace_with_a_strong_password
DB_HOST=127.0.0.1
DB_PORT=5433
```

Continue in the terminal:

```bash
# 7. Start PostgreSQL
docker compose up -d --wait db

# 8. Apply the existing Django migrations
python manage.py migrate

# 9. Create an administrative user
python manage.py createsuperuser

# 10. Install the Flutter dependencies
cd mobile
flutter pub get

# 11. Check the Android development environment
flutter doctor -v

# Return to the project root
cd ..
```

## ▶️ Daily Start

### Windows

Start Docker Desktop and wait until it is ready. From the project root, run:

```powershell
docker desktop start
.\start.bat
```

`start.bat` starts PostgreSQL and Django. It does not start the Android emulator or Flutter application.

Open a second PowerShell window for Flutter:

```powershell
cd C:\path\to\e-commerce-app\mobile

# List the available emulators
flutter emulators

# Launch the emulator if it is not already running
flutter emulators --launch Pixel_8

# Start the Flutter application on the available Android device
flutter run
```

The emulator and device identifiers can differ between computers. Use `flutter emulators` and `flutter devices` to find the correct identifiers.

### macOS / Linux

Open the first terminal for PostgreSQL and Django:

```bash
cd e-commerce-app
source venv/bin/activate
docker compose up -d --wait
python manage.py runserver 127.0.0.1:8000
```

Open a second terminal for Flutter:

```bash
cd e-commerce-app/mobile

# List and launch an available Android emulator
flutter emulators
flutter emulators --launch Pixel_8

# Start the Flutter application
flutter run
```

## ⏹️ Stop the Project

### Windows

Press `q` or `Ctrl+C` in the Flutter terminal. Then run this command from the project root:

```powershell
.\stop.bat
```

### macOS / Linux

Press `Ctrl+C` in the Django and Flutter terminals, then run:

```bash
docker compose stop
```

Stopping the project preserves the PostgreSQL data volume.

## Local Addresses

| Service | Address |
| --- | --- |
| Django web application | `http://127.0.0.1:8000/` |
| Sign in | `http://127.0.0.1:8000/signin/` |
| Django admin | `http://127.0.0.1:8000/admin/` |
| PostgreSQL from the host | `127.0.0.1:5433` |
| Django from the Android emulator | `http://10.0.2.2:8000/` |
| Planned API base URL | `http://10.0.2.2:8000/api/v1/` |

## Checks and Tests

Run the backend checks from the project root with the virtual environment active:

```powershell
python manage.py check
python manage.py test
```

Run the Flutter checks from the `mobile` directory:

```powershell
flutter analyze
flutter test
```

Check PostgreSQL when needed:

```powershell
docker compose ps
docker compose logs --tail=50 db
```

## Useful Notes

- `flutter pub get` is normally required only after cloning the project or changing `pubspec.yaml`.
- `flutter clean` is normally required only when troubleshooting a build or cache problem.
- `python manage.py makemigrations` is used after changing Django models, not during a normal installation.
- The Android emulator can remain on API 37 while the application compiles against SDK 36.
- `flutter_secure_storage` is pinned to `10.3.1` for Android SDK 36 compatibility.
- The current Compose configuration starts PostgreSQL only. Redis is not configured yet.
- The REST API and Next.js application are not implemented yet.
- The project currently uses development settings and is not ready for production deployment.
- Never commit `.env` or real database passwords.

## 👨‍💻 Author

**Arda Korkmaz**

- GitHub: [@Ardakorkmaz0](https://github.com/Ardakorkmaz0)
