# 🚀 RIPPLE — Indus App Store Release Guide

> **App**: Ripple Chat — Liquid Glass Aquatic AI  
> **Package**: `com.valli.ripple`  
> **Version**: `1.0.0+1`  
> **Date**: March 18, 2026  
> **Platform**: Android (Flutter)

---

## 📊 Release Readiness Audit

### ✅ What's Already Good

| Requirement | Status | Details |
|---|---|---|
| Unique Package ID | ✅ Pass | `com.valli.ripple` |
| AndroidX Support | ✅ Pass | `android.useAndroidX=true` |
| Multi-Dex Enabled | ✅ Pass | `multiDexEnabled = true` |
| App Launcher Icons | ✅ Pass | All densities (mdpi → xxxhdpi) + adaptive icon |
| Adaptive Icon | ✅ Pass | `ic_launcher.xml` with foreground + background `#060D1A` |
| Hardware Features Optional | ✅ Pass | Camera, microphone marked `required="false"` |
| Internet Permission | ✅ Pass | Declared in manifest |
| Java 17 Compatibility | ✅ Pass | Source & target set to Java 17 |
| Core Library Desugaring | ✅ Pass | Enabled with `desugar_jdk_libs:2.1.4` |
| Flutter Embedding v2 | ✅ Pass | Declared in manifest |
| Portrait Lock | ✅ Pass | Set in `main.dart` |
| Error Handling | ✅ Pass | Graceful fallback UI on init failure |

### ❌ Critical Blockers (Must Fix Before Release)

| # | Issue | Severity | Details |
|---|---|---|---|
| 1 | **Debug Signing on Release Build** | 🔴 Critical | `signingConfig = signingConfigs.getByName("debug")` — Indus will reject this |
| 2 | **No Privacy Policy URL** | 🔴 Critical | Required by Indus for all apps |
| 3 | **No ProGuard / R8 Rules** | 🟡 High | Release build should enable code shrinking & obfuscation |
| 4 | **`.env` Bundled as Asset** | 🟡 High | Contains API keys — exposed in APK |
| 5 | **`APP_ENV=development`** | 🟡 High | Must be `production` for release |
| 6 | **App Label is Lowercase** | 🟠 Medium | `android:label="ripple"` → should be `"Ripple"` |
| 7 | **OneSignal Verbose Logging** | 🟠 Medium | `OSLogLevel.verbose` should be removed in production |
| 8 | **No `minSdk` Override** | 🟠 Medium | Uses Flutter default — verify it meets Indus ≥ API 21 |
| 9 | **`targetSdk` Verification** | 🟠 Medium | Indus requires ≥ API 30, verify Flutter default |

---

## 🔧 Step-by-Step Fix Guide

### Fix 1 — Generate a Release Signing Keystore

```powershell
# Run from project root (one-time setup)
keytool -genkey -v -keystore ripple-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ripple
```

Create `android/key.properties`:

```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=ripple
storeFile=../../ripple-release-key.jks
```

> [!CAUTION]
> **Never commit `key.properties` or `.jks` files to Git!** Add both to `.gitignore`.

### Fix 2 — Update `android/app/build.gradle.kts` for Release Signing

Replace the current `buildTypes` block:

```kotlin
// Load signing config
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Fix 3 — Create ProGuard Rules

Create `android/app/proguard-rules.pro`:

```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Supabase / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
```

### Fix 4 — Fix App Label

In `android/app/src/main/AndroidManifest.xml`, change:

```diff
- android:label="ripple"
+ android:label="Ripple"
```

### Fix 5 — Set Production Environment

In your `.env` file for the release build:

```properties
APP_ENV=production
```

### Fix 6 — Remove Verbose Logging in Production

In `lib/main.dart`, wrap the verbose logging:

```dart
// Only enable verbose logging in debug mode
assert(() {
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  return true;
}());
```

### Fix 7 — Set Explicit minSdk and targetSdk

In `android/app/build.gradle.kts`, update `defaultConfig`:

```kotlin
defaultConfig {
    applicationId = "com.valli.ripple"
    minSdk = 24          // Required for all plugins used
    targetSdk = 34       // Meets Indus requirement (≥ 30)
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    multiDexEnabled = true
}
```

### Fix 8 — Create a Privacy Policy

You need a hosted privacy policy URL. It must cover:
- What data the app collects (messages, contacts, media, biometrics)
- How Firebase, Supabase, OneSignal, Cloudinary/ImageKit are used
- Data retention and deletion policies
- User rights under Indian data protection laws

> [!IMPORTANT]
> Indus App Store **requires** a privacy policy URL during app submission. Host it on your website or use a free service like Notion, GitHub Pages, or Google Sites.

---

## 📦 Build Commands

### Generate Release APK

```powershell
cd c:\valli\RIPPLE\ripple
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Generate Release AAB (Recommended)

```powershell
cd c:\valli\RIPPLE\ripple
flutter build appbundle --release
```

The AAB will be at: `build/app/outputs/bundle/release/app-release.aab`

> [!NOTE]
> Indus App Store accepts **APK**, **AAB**, and **APKS** formats. AAB is recommended for smaller download sizes.

---

## 📋 Indus Developer Console — Submission Checklist

### Account Setup
- [ ] Create developer account at [Indus Appstore Developer Console](https://developer.indusappstore.com)
- [ ] Complete KYC verification (ID proof, address, PAN/GST if organization)
- [ ] Set up payment details for earnings

### App Listing Details
- [ ] **App Name**: `Ripple` (or `Ripple Chat`)
- [ ] **App Icon**: Square format, max 2 MB — use `assets/images/ripple_logo.png`
- [ ] **Category**: `Communication` → `Messaging`
- [ ] **Target Age Group**: Select appropriate age rating
- [ ] **Short Description** (80 chars): `Ripple — AI-powered private chat with liquid glass design`
- [ ] **Full Description** (4000 chars): See [suggested description below](#-suggested-store-description)
- [ ] **Screenshots**: Upload at least 4 screenshots (1080×1920 or 1920×1080)
- [ ] **Promotional Video** (optional): 1920×1080, max 30 seconds
- [ ] **Privacy Policy URL**: Your hosted privacy policy link

### App File Upload
- [ ] Upload signed release APK or AAB
- [ ] Verify the APK/AAB is **unencrypted**
- [ ] Ensure both **32-bit and 64-bit** architectures are included (Flutter does this by default)

### Technical Verification
- [ ] Target SDK ≥ API 30 ✅
- [ ] App is functional, stable, and bug-free
- [ ] App functionality matches the store description
- [ ] No demo/beta/test build — must be the full release version
- [ ] `.env` file has `APP_ENV=production`
- [ ] Verbose logging is disabled

### Data Security Declaration
- [ ] Declare data collection practices (camera, microphone, contacts, storage)
- [ ] Declare third-party SDKs (Firebase, Supabase, OneSignal, Cloudinary)
- [ ] Confirm encryption for data in transit (HTTPS/TLS)

### Content Compliance
- [ ] App designed for Indian audience compatibility
- [ ] No misleading metadata
- [ ] Content rating matches app content
- [ ] Proof of content ownership (if applicable)

---

## 📝 Suggested Store Description

**Short Description:**
> Ripple — AI-powered private chat with liquid glass design

**Full Description:**
> Ripple is a next-generation messaging app featuring a stunning liquid glass aquatic design and AI-powered features. Built for privacy-conscious users, Ripple combines beautiful animations with powerful communication tools.
>
> **🌊 Key Features:**
> • Liquid glass design with mesmerizing aquatic animations
> • End-to-end private chats and group conversations  
> • Voice messages, media sharing (photos, videos, documents)
> • Video and audio calls powered by Daily.co
> • AI assistant powered by Groq for smart replies
> • Chat lock with biometric authentication (fingerprint/face)
> • Fake passcode for decoy screen protection
> • Screenshot blocking for sensitive conversations
> • Emoji picker and link previews
> • Saved messages and archived chats
> • Social features: achievements, leaderboard, activity feed
> • Friend suggestions and profile visitors
> • Global search across all conversations
> • QR code sharing for easy contact exchange
> • Push notifications via OneSignal
> • Dark ocean theme with premium aesthetics
>
> **🔒 Privacy First:**
> • Chat lock with fingerprint/face unlock
> • Fake passcode for decoy mode
> • Screenshot blocking per conversation
> • No ads, no tracking
>
> **🤖 AI Powered:**
> • Smart reply suggestions
> • AI chat assistant for quick answers
> • Customizable AI settings
>
> Built with Flutter for smooth 60fps performance across all Android devices.

---

## 🔐 Files to Add to `.gitignore`

```gitignore
# Release signing
*.jks
*.keystore
key.properties

# Environment secrets (already should be ignored)
.env
```

---

## 📐 Version Numbering for Future Updates

| Field | Format | Example |
|---|---|---|
| `version` in `pubspec.yaml` | `major.minor.patch+buildNumber` | `1.0.0+1` |
| First release | `1.0.0+1` | Current ✅ |
| Bug fix update | `1.0.1+2` | Next patch |
| Feature update | `1.1.0+3` | Next minor |

> [!WARNING]
> For Indus updates, the new version's **signature key must match** the original release signing key. **Never lose your keystore file!** Back it up securely.

---

## ⚡ Quick Release Checklist (TL;DR)

```
1. ✅ Generate keystore           → keytool -genkey ...
2. ✅ Create key.properties       → android/key.properties
3. ✅ Update build.gradle.kts     → release signing + ProGuard
4. ✅ Create proguard-rules.pro   → android/app/proguard-rules.pro
5. ✅ Fix app label               → "Ripple" (capital R)
6. ✅ Set APP_ENV=production      → .env
7. ✅ Remove verbose logging      → main.dart
8. ✅ Set minSdk=24, targetSdk=34 → build.gradle.kts
9. ✅ Create & host privacy policy
10. ✅ Build: flutter build apk --release
11. ✅ Test the release APK on real device
12. ✅ Submit to Indus Developer Console
```
