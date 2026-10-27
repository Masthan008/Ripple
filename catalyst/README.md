# Ripple × Zoho Catalyst FCM Push Notification Guide

This guide details how to configure and deploy the **Zoho Catalyst FCM Engine** for Ripple under your **Zoho Catalyst Pay-As-You-Go** plan.

---

## 1. Firebase Service Account Setup
1. Open the [Firebase Console](https://console.firebase.google.com/) for project `ripple-cd77c`.
2. Go to **Project Settings** (gear icon) > **Service Accounts**.
3. Click **Generate new private key** and download the JSON file.
4. Open the JSON file and copy its contents.

---

## 2. Zoho Catalyst Console Setup
1. Log in to [Zoho Catalyst Console](https://catalyst.zoho.com/).
2. Select or create your project for Ripple (e.g., `Ripple-Messenger`).
3. Under **Components** > **Push Notifications**:
   - Click **Add Application** > Select **Android**.
   - Package name: `com.valli.ripple`.
   - Upload the Firebase Service Account JSON downloaded in Step 1.
   - Note the **Catalyst Application ID**.
4. Under **Settings** > **Environment Variables** (or Function Config):
   - Add variable: `FIREBASE_SERVICE_ACCOUNT` with the contents of the service account JSON file.

---

## 3. Deploying the Catalyst Function

### Option A: Via Catalyst CLI (Recommended)
From your terminal:
```bash
cd catalyst
npm install -g zcatalyst-cli
catalyst login
catalyst deploy
```

### Option B: Via Catalyst Web Console
1. In the Catalyst Console, go to **Serverless** > **Functions**.
2. Click **Create Function**:
   - Function Name: `ripple_notify`
   - Type: **Advanced I/O**
   - Stack: **Node.js 18**
3. Paste the contents of `catalyst/functions/ripple_notify/index.js` and `package.json`.
4. Click **Deploy**.
5. Copy the function's Invoke URL (e.g., `https://ripple-xyz.catalystserverless.com/server/ripple_notify`).

---

## 4. Configuring Flutter Client (`.env`)
Add the following to your `ripple/.env` file:
```env
CATALYST_PROJECT_ID=your_catalyst_project_id
CATALYST_APP_ID=your_catalyst_app_id
CATALYST_FUNCTION_URL=https://your-catalyst-url.com/server/ripple_notify
CATALYST_CLIENT_SECRET=your_secret_optional
```

Once configured, all message and incoming call notifications are routed with sub-millisecond latency directly through Google's high-priority FCM v1 infrastructure via your Catalyst Pay-As-You-Go cloud.
