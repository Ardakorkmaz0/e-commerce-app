# 📱 VADER Mobile Application

The Flutter Android application for the VADER E-Commerce & Inventory Platform.

The mobile and web applications use the same Django REST API and PostgreSQL database.

## 🛠 Tech Stack

- **Framework:** Flutter 3.44.9
- **Language:** Dart 3.12
- **API Client:** Dio
- **Routing:** GoRouter
- **State Management:** Riverpod
- **Token Storage:** Flutter Secure Storage

## ✅ Requirements

- Flutter
- Android Studio
- Android SDK
- Android emulator or physical Android device
- Docker Desktop
- Django backend packages installed in the main project

## 🚀 First-Time Setup

### Windows (PowerShell)

Run these commands from the main project directory:

```powershell
# 1. Check Flutter and Android
flutter doctor -v
flutter devices

# 2. Open the mobile directory
cd mobile

# 3. Install Flutter packages
flutter pub get

# 4. Check the project
flutter analyze
flutter test

# 5. Return to the main project directory
cd ..
```

If `flutter` is not found:

```powershell
$env:Path = "$env:USERPROFILE\develop\flutter\bin;$env:Path"
```

## ▶️ Start the Mobile Application

Run this from the main project directory:

```powershell
.\startmobile.bat
```

This command:

1. Starts PostgreSQL.
2. Starts the Django API.
3. Uses a connected Android device or starts the `Pixel_8` emulator.
4. Connects the emulator to the local API.
5. Starts the Flutter application.

## ▶️ Start Web and Mobile Together

```powershell
.\startwebamobile.bat
```

## ⏹ Stop the Project

```powershell
.\stop.bat
```

PostgreSQL data is not deleted.

## 🔌 Backend Connection

The start script automatically uses:

```text
http://127.0.0.1:8000/api/v1/
```

When Flutter is started manually on the Android emulator, the default address is:

```text
http://10.0.2.2:8000/api/v1/
```

PostgreSQL and Django must be running before the mobile application can load API data.

## 📁 Main Files

```text
lib/main.dart                         Application entry point
lib/app/                              Application and router
lib/core/config/                      API configuration
lib/core/network/                     Dio API client
lib/core/storage/                     Secure token storage
lib/features/auth/                    Authentication screens and code
lib/features/products/                Product screens and code
android/                              Android project settings
pubspec.yaml                          Flutter packages and app version
```

## 🚧 Current Status

- Sign-in screen created
- Product screen created
- API client created
- Secure token storage created
- Django sign-in connection is not completed yet
- Product API connection is not completed yet

## 🧪 Useful Commands

```powershell
# List devices
flutter devices

# List emulators
flutter emulators

# Start the Pixel 8 emulator
flutter emulators --launch Pixel_8

# Start the application manually
flutter run

# Check code
flutter analyze

# Run tests
flutter test
```

Run `flutter pub get` again after changing `pubspec.yaml`.
