# 🌐 VADER Web Application

The customer website for the VADER E-Commerce & Inventory Platform.

## 🛠 Tech Stack

- **Framework:** Next.js 16
- **UI:** React 19
- **Language:** TypeScript
- **Backend:** Django REST Framework
- **Authentication:** JWT with HttpOnly cookies
- **Styles:** Bootstrap and custom CSS

## ✅ Requirements

- Node.js 20.9 or newer
- npm
- Django backend running on `http://127.0.0.1:8000`

## 🚀 First-Time Setup

### Windows (PowerShell)

Run these commands from the main project directory:

```powershell
# 1. Open the web directory
cd web

# 2. Install packages
npm install

# 3. Create the local environment file
Copy-Item .env.example .env.local

# 4. Return to the main project directory
cd ..
```

The environment file contains:

```env
API_BASE_URL=http://127.0.0.1:8000/api/v1
```

## ▶️ Start the Web Application

The easiest method is to run this from the main project directory:

```powershell
.\startweb.bat
```

This starts PostgreSQL, Django API, and Next.js.

Open this address:

```text
http://localhost:3000/
```

### Start Only Next.js

Make sure PostgreSQL and Django are already running. Then run:

```powershell
cd web
npm run dev
```

## ⏹ Stop the Project

Run this from the main project directory:

```powershell
.\stop.bat
```

## 📁 Main Files

```text
src/app/                  Pages, layouts, and server actions
src/components/           Navbar and reusable UI components
src/lib/                  Authentication and API helpers
public/                   Logo, images, and static files
src/app/globals.css       Main CSS file
src/app/layout.tsx        Main layout, like Django base.html
```

Each URL has a `page.tsx` file:

```text
src/app/(store)/page.tsx              /
src/app/(auth)/signin/page.tsx        /signin
src/app/(auth)/signup/page.tsx        /signup
src/app/(store)/products/page.tsx     /products
src/app/(store)/categories/page.tsx   /categories
src/app/(store)/cart/page.tsx         /cart
src/app/(store)/profile/page.tsx      /profile
src/app/(store)/myorders/page.tsx     /myorders
```

Folders inside parentheses do not appear in the URL.

## 🔐 Authentication

The web application uses the Django API for:

- Account registration
- Sign in
- Current user information
- Token refresh
- Sign out

Users without an active session are redirected to `/signin`.

## 🧪 Useful Commands

```powershell
# Start development mode
npm run dev

# Check code
npm run lint

# Create a production build
npm run build

# Start the production build
npm run start
```

Run `npm install` again after changing `package.json`.
