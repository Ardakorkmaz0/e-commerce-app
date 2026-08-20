# 🛒 VADER - E-Commerce & Inventory Platform

A small e-commerce project with a Django REST backend, Next.js web application, Flutter mobile application, and PostgreSQL database.

![Python](https://img.shields.io/badge/Python-3.14-blue)
![Django](https://img.shields.io/badge/Django-5.2.17-green)
![Next.js](https://img.shields.io/badge/Next.js-16-black)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.44.9-lightblue)

## 📸 Screenshots

Drop the images in `docs/screenshots/` with these names.

| Web | Mobile |
| --- | --- |
| ![Catalog](docs/screenshots/web-catalog.png) | ![Catalog](docs/screenshots/mobile-catalog.png) |
| ![Product](docs/screenshots/web-product.png) | ![Product](docs/screenshots/mobile-product.png) |
| ![Checkout](docs/screenshots/web-checkout.png) | ![Orders](docs/screenshots/mobile-orders.png) |

## 🛠 Tech Stack

- **Backend:** Django REST Framework
- **Web:** Next.js, React, and TypeScript
- **Mobile:** Flutter for Android
- **Database:** PostgreSQL
- **Authentication:** JWT
- **Admin:** Django Admin
- **Tools:** Docker and Docker Compose

## 📁 Project Parts

- `accounts/` - User model and authentication API
- `ecommerce/` - Backend models for store features
- `config/` - Django settings and main URLs
- `web/` - Next.js web application
- `mobile/` - Flutter Android application
- `compose.yaml` - PostgreSQL Docker configuration

More information:

- [Web README](web/README.md)
- [Mobile README](mobile/README.md)

## ✅ Requirements

Install these programs first:

- Python 3.14
- Docker Desktop
- Node.js 20.9 or newer
- Flutter and Android Studio for the mobile application

## 🚀 Installation & Setup

### Windows (PowerShell)

```powershell
# 1. Clone the repository
git clone https://github.com/Ardakorkmaz0/e-commerce-app.git

# 2. Open the project directory
cd e-commerce-app

# 3. Create a Python virtual environment
python -m venv venv

# 4. Allow script execution for this terminal
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# 5. Activate the virtual environment
.\venv\Scripts\Activate.ps1

# 6. Install backend packages
python -m pip install -r requirements.txt

# 7. Create the environment file
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
# 8. Start Docker Desktop
docker desktop start

# 9. Start PostgreSQL
docker compose up -d --wait db

# 10. Create the database tables
python manage.py migrate

# 11. Create an admin user
python manage.py createsuperuser

# 12. Add the demo product catalog
python manage.py seed_catalog

# 13. Install web packages
cd web
npm install
Copy-Item .env.example .env.local
cd ..

# 14. Install mobile packages
cd mobile
flutter pub get
flutter doctor -v
cd ..
```

If `flutter` is not found:

```powershell
$env:Path = "$env:USERPROFILE\develop\flutter\bin;$env:Path"
```

## ▶️ Start the Project

Run one of these files from the main project directory.

### Start Web

```powershell
.\startweb.bat
```

Starts PostgreSQL, Django API, and Next.js.

### Start Mobile

```powershell
.\startmobile.bat
```

Starts PostgreSQL, Django API, Android emulator, and Flutter.

### Start Web and Mobile

```powershell
.\startwebamobile.bat
```

Starts the complete project.

## ⏹ Stop the Project

```powershell
.\stop.bat
```

This stops the project services. PostgreSQL data is not deleted.

## 🌐 Local Addresses

| Service | Address |
| --- | --- |
| Web application | `http://localhost:3000/` |
| Django REST API | `http://127.0.0.1:8000/api/v1/` |
| Django Admin | `http://127.0.0.1:8000/admin/` |
| PostgreSQL | `127.0.0.1:5433` |

The customer website runs on port `3000`. Port `8000` is used for the Django API and admin panel.

## 🧪 Checks

```powershell
# Backend checks
.\venv\Scripts\python.exe manage.py check
.\venv\Scripts\python.exe manage.py test

# Web checks
cd web
npm run lint
npm run build

# Mobile checks
cd ..\mobile
flutter analyze
flutter test
```

## 💳 Test Cards

Payments go through a stand-in provider, not a bank. It decides the result
from the last four digits of the card, so the same card behaves the same
way every time.

| Number | Result |
| --- | --- |
| `4242 4242 4242 4242` | Paid (Visa) |
| `5555 5555 5555 4444` | Paid (Mastercard) |
| `4000 0000 0000 0002` | Declined |
| `4000 0000 0000 9995` | Insufficient funds |

The full list, what the card form rejects and how to walk the failure path
are in [docs/test-cards.md](docs/test-cards.md).

**Never enter a real card number.** These are published test numbers that
belong to no account. No card number or security code is stored anywhere
in this project — only the brand, the last four digits and an expiry.

## 📝 Notes

- Run `python manage.py makemigrations` only after changing a Django model.
- Run `python manage.py migrate` after adding a new migration.
- Run `npm install` after changing `web/package.json`.
- Run `flutter pub get` after changing `mobile/pubspec.yaml`.
- Never upload `.env` or real passwords to GitHub.
- Redis is planned but is not configured yet.
- Payments are simulated; see [docs/test-cards.md](docs/test-cards.md).
- The app icon is generated from the site logo; see
  [docs/app-icon.md](docs/app-icon.md).

## 👨‍💻 Author

**Arda Korkmaz**

- GitHub: [@Ardakorkmaz0](https://github.com/Ardakorkmaz0)
