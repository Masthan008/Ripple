# 🔧 Ripple — Environment Variables Setup Guide

Complete step-by-step guide to obtain all API keys and credentials for the `.env` file.

---

## 📋 Quick Status: Which services need setup?

| Service | Required For | Priority |
|---------|-------------|----------|
| **Firebase** | Auth, Database, Notifications | 🔴 Required first |
| **ZegoCloud** | Video & Audio Calls | 🟡 Phase 8 |
| **Supabase** | File/Document Storage | 🟡 Phase 5 |
| **Cloudinary** | Image & Video Uploads | 🟡 Phase 5 |
| **ImageKit** | Alternative CDN (optional) | 🟢 Optional |

---

## 1. 🔥 Firebase Setup

Firebase powers auth, real-time database, and push notifications.

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add Project"**
3. Name it `ripple` (or any name)
4. Disable Google Analytics (optional) → Click **Create Project**

### Step 2: Add Android App
1. In your Firebase project → Click **Android icon** to add an app
2. **Package name**: `com.valli.ripple`
3. **App nickname**: Ripple
4. Click **Register App**
5. **Download `google-services.json`** → Place it in:
   ```
   ripple/android/app/google-services.json
   ```
6. Skip the remaining steps in the wizard

### Step 3: Add iOS App (if needed)
1. Click **iOS icon** → **Bundle ID**: `com.valli.ripple`
2. **Download `GoogleService-Info.plist`** → Place it in:
   ```
   ripple/ios/Runner/GoogleService-Info.plist
   ```

### Step 4: Enable Authentication
1. Go to **Build → Authentication → Sign-in method**
2. Enable **Email/Password**
3. Enable **Google** → Set support email → Save

### Step 5: Create Firestore Database
1. Go to **Build → Firestore Database**
2. Click **Create Database**
3. Choose **Start in test mode** (for development)
4. Select your preferred region → Click **Enable**

### Step 6: Get Your Firebase Keys
1. Go to **Project Settings** (gear icon) → **General** tab
2. Scroll to **Your apps** → Click on your Android/Web app
3. You'll find all the values in the Firebase config object:

```env
FIREBASE_API_KEY=AIzaSy...         # apiKey
FIREBASE_APP_ID=1:123456:android:abc123  # appId
FIREBASE_MESSAGING_SENDER_ID=123456789   # messagingSenderId
FIREBASE_PROJECT_ID=ripple-12345         # projectId
FIREBASE_AUTH_DOMAIN=ripple-12345.firebaseapp.com
FIREBASE_STORAGE_BUCKET=ripple-12345.appspot.com
FIREBASE_DATABASE_URL=https://ripple-12345.firebaseio.com
```

> **💡 Tip**: If you don't see a web app, click **Add App → Web** to get these values easily. The keys work across platforms.

### Step 7: Enable Cloud Messaging (FCM)
1. Go to **Project Settings → Cloud Messaging** tab
2. If prompted, enable Cloud Messaging API (V1)
3. No keys needed here — FCM uses the Firebase config above

---

## 2. 📞 ZegoCloud Setup (Video & Audio Calls)

### Step 1: Create Account
1. Go to [ZegoCloud Console](https://console.zegocloud.com/)
2. Sign up for a free account

### Step 2: Create a Project
1. Click **"Create Project"**
2. Select **"Voice & Video Call"** use case
3. Name it `Ripple`

### Step 3: Get Your Keys
1. Go to your project **Dashboard**
2. Find **AppID** and **AppSign**:

```env
ZEGO_APP_ID=123456789              # Numeric App ID
ZEGO_APP_SIGN=abc123def456...      # 64-character hex string
```

> **⚠️ Important**: ZegoCloud free tier includes 10,000 free minutes/month.

---

## 3. 💾 Supabase Setup (File/Document Storage)

### Step 1: Create Account & Project
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Sign up → Click **"New Project"**
3. **Name**: `ripple`
4. **Database Password**: Set a strong password (save it!)
5. **Region**: Choose closest to your users
6. Click **Create New Project** (takes ~2 minutes)

### Step 2: Create Storage Bucket
1. Go to **Storage** in the left sidebar
2. Click **"New Bucket"**
3. **Name**: `ripple-files`
4. Toggle **"Public bucket"** ON (so files can be accessed via URL)
5. Click **Create Bucket**

### Step 3: Set Bucket Policies (important!)
1. Click on `ripple-files` bucket → **Policies** tab
2. Click **"New Policy"** → **"For full customization"**
3. Create these policies:
   - **INSERT** (upload): Allow authenticated users
   - **SELECT** (download): Allow all (public)

### Step 4: Get Your Keys
1. Go to **Settings → API** in the left sidebar
2. Find your keys:

```env
SUPABASE_URL=https://abcdefgh.supabase.co    # Project URL
SUPABASE_ANON_KEY=eyJhbGci...                 # anon/public key
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...          # service_role key (keep secret!)
SUPABASE_BUCKET_NAME=ripple-files
```

> **⚠️ Never expose `SERVICE_ROLE_KEY` in client code** — it's only used server-side. The app primarily uses the `ANON_KEY`.

---

## 4. 🖼️ Cloudinary Setup (Image & Video Storage)

### Step 1: Create Account
1. Go to [Cloudinary Console](https://console.cloudinary.com/)
2. Sign up for a free account (25GB storage, 25GB bandwidth/month)

### Step 2: Get Your Cloud Name & Keys
1. After login, you land on the **Dashboard**
2. Your **Cloud Name**, **API Key**, and **API Secret** are shown right there:

```env
CLOUDINARY_CLOUD_NAME=dxxxxxx       # Your cloud name
CLOUDINARY_API_KEY=123456789012345  # API Key
CLOUDINARY_API_SECRET=abcDEF...     # API Secret (keep secret!)
CLOUDINARY_BASE_URL=https://res.cloudinary.com/dxxxxxx
```

### Step 3: Create Upload Preset
1. Go to **Settings → Upload** tab
2. Scroll to **Upload presets** → Click **"Add upload preset"**
3. Set:
   - **Preset name**: `ripple_upload` (or any name)
   - **Signing mode**: **Unsigned** (allows client-side upload)
   - **Folder**: `ripple` (optional, organizes uploads)
4. Click **Save**

```env
CLOUDINARY_UPLOAD_PRESET=ripple_upload
```

> **💡 Tip**: Unsigned presets allow direct upload from the app without exposing API secret.

---

## 5. 🌐 ImageKit Setup (Optional — Alternative CDN)

Only needed if you want an alternative/backup image CDN.

### Step 1: Create Account
1. Go to [ImageKit Dashboard](https://imagekit.io/dashboard)
2. Sign up for a free account (20GB bandwidth/month)

### Step 2: Get Your Keys
1. Go to **Dashboard → Developer options**
2. Find your keys:

```env
IMAGEKIT_PUBLIC_KEY=public_xxxxx
IMAGEKIT_PRIVATE_KEY=private_xxxxx        # Keep secret!
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/your_id
```

---

## ✅ Complete .env Checklist

After setting up all services, your `.env` should look like this (with real values):

```
✅ FIREBASE_API_KEY         → From Firebase Console > Project Settings
✅ FIREBASE_APP_ID          → From Firebase Console > Project Settings
✅ FIREBASE_MESSAGING_SENDER_ID → From Firebase Console > Project Settings
✅ FIREBASE_PROJECT_ID      → From Firebase Console > Project Settings
✅ FIREBASE_AUTH_DOMAIN      → {project-id}.firebaseapp.com
✅ FIREBASE_STORAGE_BUCKET   → {project-id}.appspot.com
✅ FIREBASE_DATABASE_URL     → https://{project-id}.firebaseio.com

✅ ZEGO_APP_ID              → From ZegoCloud Console > Project Dashboard
✅ ZEGO_APP_SIGN            → From ZegoCloud Console > Project Dashboard

✅ SUPABASE_URL             → From Supabase > Settings > API
✅ SUPABASE_ANON_KEY        → From Supabase > Settings > API
✅ SUPABASE_SERVICE_ROLE_KEY → From Supabase > Settings > API
✅ SUPABASE_BUCKET_NAME     → "ripple-files" (you created this)

✅ CLOUDINARY_CLOUD_NAME    → From Cloudinary Dashboard
✅ CLOUDINARY_UPLOAD_PRESET → From Cloudinary > Settings > Upload
✅ CLOUDINARY_API_KEY       → From Cloudinary Dashboard
✅ CLOUDINARY_API_SECRET    → From Cloudinary Dashboard
✅ CLOUDINARY_BASE_URL      → https://res.cloudinary.com/{cloud_name}

⬜ IMAGEKIT_PUBLIC_KEY      → Optional
⬜ IMAGEKIT_PRIVATE_KEY     → Optional
⬜ IMAGEKIT_URL_ENDPOINT    → Optional
```

---

## 🔒 Security Reminders

1. **Never commit `.env` to Git** — it's already in `.gitignore`
2. **Share `.env.example`** (with empty values) with teammates
3. **Rotate keys** if they're ever accidentally exposed
4. **Use test/development credentials** during development
5. **Service role keys** (Supabase) should only be used server-side
