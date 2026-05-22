# 🌊 Ripple Client Application

This directory contains the cross-platform [Flutter](https://flutter.dev/) client application for **Ripple Chat — Liquid Glass Aquatic AI**.

For a full breakdown of Ripple's unique features, core differentiators (such as **Ripple Telepathy™** and **Spatial Threads™**), and architectural design, please refer to the [Root README.md](file:///c:/valli/RIPPLE/README.md).

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK**: Ensure you have Flutter SDK installed (recommend version matching `pubspec.yaml`).
- **Dart SDK**: Automatically bundled with Flutter.
- **Java 17**: Required for building the Android application.

### 2. Environment Configuration
Ripple relies on several secure service endpoints. Before running the app, copy the configuration template:
```bash
cp .env.example .env
```
Open the newly created `.env` file and populate it with your credentials. For step-by-step instructions on setting up Firebase, Supabase, Cloudinary, and ZegoCloud, refer to the [Environment Setup Guide](file:///c:/valli/RIPPLE/ripple/ENV_SETUP_GUIDE.md).

### 3. Fetch Dependencies
Install the required Dart packages (including Firestore plugins, encryption libraries, and notification services):
```bash
flutter pub get
```

### 4. Run the Application
Start the application in debug mode on your connected simulator or physical device:
```bash
flutter run
```

---

## 📂 Project Architecture

The source code is organized within the `lib/` directory under a modular feature-based structure:

- **`lib/core/`**: Shared components, services, database models, state managers, and cross-cutting concerns (e.g., encryption utilities).
- **`lib/features/`**: Feature-specific UI screens, controllers, and domain models.
  - **`calls/`**: Audio & Video calling screens using the Daily.co WebRTC integrations.
  - **`chat/`**: Standard message composers, voice player controllers, and smart decibel-based ambient listeners (**Sonic Whispers™**).
  - **`groups/`**: Non-linear, physics-based canvas interface (**Spatial Threads™**).
  - **`settings/`**: Security configuration panel and custom UI adjustments.

---

## 🔒 Security & Deployment

- **Firestore Rules**: Securing user documents and message sub-collections. Rules are declared in [firestore.rules](file:///c:/valli/RIPPLE/ripple/firestore.rules).
- **Database Indexes**: Optimized query mappings are defined in [firestore.indexes.json](file:///c:/valli/RIPPLE/ripple/firestore.indexes.json).
- **Release Guidelines**: When prepping the app for production deployment, make sure to configure ProGuard rules and release signing. Follow the checklist in the [Indus App Store Release Guide](file:///c:/valli/RIPPLE/ripple/RELEASE.md).
