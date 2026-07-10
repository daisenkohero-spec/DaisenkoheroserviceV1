# Daisenko Hero Service — Server Setup

This guide covers local development and production deployment for the technician app and API.

## Architecture

| Component | Technology | Purpose |
|-----------|------------|---------|
| Mobile / Web app | Flutter | Technician UI |
| Real-time data | Firebase Firestore | Jobs, auth, notifications |
| REST API | Node.js + Express (`server/`) | Optional API layer for future migration |

Repository: [daisenkohero-spec/DaisenkoheroserviceV1](https://github.com/daisenkohero-spec/DaisenkoheroserviceV1)

---

## Prerequisites

Install these on your machine:

1. **Flutter** — [flutter.dev/docs/get-started](https://docs.flutter.dev/get-started/install)
2. **Node.js 20+** — [nodejs.org](https://nodejs.org/)
3. **Git**
4. **Windows Developer Mode** — required for Flutter plugin symlinks  
   Open: `start ms-settings:developers` and enable Developer Mode

Optional (for Android builds):

- Android Studio + Android SDK

---

## 1. Clone and install

```powershell
git clone https://github.com/daisenkohero-spec/DaisenkoheroserviceV1.git
cd DaisenkoheroserviceV1
flutter pub get
```

---

## 2. Firebase setup

The app uses Firebase project `air-cleaning-test`.

### Android (already configured)

- `android/app/google-services.json` is included
- `lib/firebase_options.dart` is generated from that file

### Web (one-time in Firebase Console)

1. Open [Firebase Console](https://console.firebase.google.com/) → project `air-cleaning-test`
2. Add a **Web app**
3. Copy the web `appId`
4. Update `lib/firebase_options.dart` → `web.appId` with the real value

### Firestore seed data

Create these collections in Firestore:

**`technicians`**

```json
{
  "name": "ช่างทดสอบ",
  "phone": "0812345678",
  "password": "1234"
}
```

**`jobs`** — assign `technicianId` to the technician document ID.

---

## 3. Run the REST API (local)

```powershell
.\scripts\start-api.ps1
```

API endpoints:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| POST | `/api/login` | Login with phone + password |
| GET | `/api/profile` | Current technician profile |
| GET | `/api/jobs` | Jobs for logged-in technician |
| GET | `/api/notifications` | Unread notifications |
| POST | `/api/checkin` | Check in to a job |
| POST | `/api/finish-job` | Complete a job |

**Test login**

```powershell
curl -X POST http://localhost:3000/api/login `
  -H "Content-Type: application/json" `
  -d '{"phone":"0812345678","password":"1234"}'
```

Default dev credentials: phone `0812345678`, password `1234`.

---

## 4. Run the web app (local)

In a second terminal:

```powershell
.\scripts\start-web.ps1
```

Open: [http://localhost:8080](http://localhost:8080)

### Other run targets

```powershell
# Chrome (interactive dev tools)
flutter run -d chrome

# Android emulator / device
flutter run -d android

# Windows desktop
flutter run -d windows
```

---

## 5. Production deployment options

### Option A — Flutter Web (static hosting)

```powershell
flutter build web --release
```

Deploy the `build/web/` folder to:

- **Firebase Hosting** (recommended — same project as Firestore)
- **Vercel / Netlify / Cloudflare Pages**

Firebase Hosting example:

```powershell
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy --only hosting
```

### Option B — API server (VPS / cloud)

Deploy the `server/` folder to any Node.js host (Railway, Render, DigitalOcean, AWS):

```bash
cd server
npm install --production
PORT=3000 node src/index.js
```

Set environment variables:

```env
PORT=3000
API_PREFIX=/api
CORS_ORIGIN=https://your-web-app-domain.com
```

### Option C — Android APK

```powershell
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Environment summary

| Service | Local URL | Production |
|---------|-----------|------------|
| Web app | http://localhost:8080 | Your hosting domain |
| API | http://localhost:3000 | Your API domain |
| Firebase | `air-cleaning-test` | Same project |

The Flutter app uses `http://localhost:3000/api` in debug mode and `https://api.daisenkohero.com/api` in release builds (`lib/core/api/api_client.dart`).

---

## Troubleshooting

**"Building with plugins requires symlink support"**  
→ Enable Windows Developer Mode.

**Firebase web init fails**  
→ Register a Web app in Firebase Console and update `firebase_options.dart`.

**API CORS errors**  
→ Set `CORS_ORIGIN` in `server/.env` to match your web app URL.

**Login fails in app**  
→ Confirm Firestore `technicians` collection has matching phone/password documents.
