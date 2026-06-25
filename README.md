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

- **Firestore Rules**: Securing user documents, messages, prekeys, and secret chat handshakes. Rules are declared in [firestore.rules](file:///c:/valli/RIPPLE/ripple/firestore.rules).
- **Database Indexes**: Optimized query mappings are defined in [firestore.indexes.json](file:///c:/valli/RIPPLE/ripple/firestore.indexes.json).
- **Release Guidelines**: When prepping the app for production deployment, make sure to configure ProGuard rules and release signing. Follow the checklist in the [Indus App Store Release Guide](file:///c:/valli/RIPPLE/ripple/RELEASE.md).

---

## 🛡️ E2E Encryption & Advanced Privacy System

Ripple integrates state-of-the-art E2EE and sensory-security features to guarantee communication privacy:

### 1. Automated E2EE Protocol (Curve25519 X3DH + Double Ratchet)
- **Handshake**: Extended Triple Diffie-Hellman (X3DH) automatically establishes shared master keys on Firestore upon chat entry. It publishes prekey bundles under `users/{uid}/prekeys/bundle` and exchanges metadata under `secretChats/{chatId}/handshake/init`.
- **Encryption**: Messages are encrypted via **AES-256-GCM** with dynamic key rotations on every message bubble for Forward Secrecy and Post-Compromise Security.
- **Key Storage**: Identity and session keys are kept exclusively on-device inside Android's EncryptedSharedPreferences and iOS's Keychain via `flutter_secure_storage`.

### 2. Steganography (Acoustic Stealth)
- **Cover Audio**: High-fidelity rain/ocean noise WAV file generator.
- **LSB Encoding**: Compresses and encrypts audio message payloads, hiding binary bits within the least significant bits of the wav file's sample arrays.
- **Isolate Processing**: Runs bitwise encoding/decoding off the UI thread via Dart isolate workers (`compute`) to prevent screen frame drops.
- **On-the-fly Recovery**: Automatically detects cover WAV files on play, extracts LSB payloads, and decrypts the audio stream for seamless reproduction.

### 3. Liquid Wave Polarized Key Verification
- **Aesthetic Representation**: Draws dynamic public keys as dynamic vector canvas ripples with frequency, phase-offset, and HSL color cycles using custom `LiquidWavePainter`.
- **Temporal QR-Alternative**: Prevents static photo/screenshot spoofing since key verification is verified through animation movement cycles.

### 4. Sentient Decoy Matrix
- **Stealth Pin Access**: Logins using the decoy passcode redirect users to a clean, fully simulated chat sandbox.
- **Dialogue Engine**: Local generator populates mock threads with dynamic conversations, blurry media placeholders, and auto-replies to deflect physical inspection.

---

## 🎨 Premium Visuals, Diagnostics, & Storage Systems

Ripple now includes enhanced visuals, diagnostic metrics, and granular local resource tools:

### 1. Dynamic Splash Screen
- **Concurrent Checks**: Parallelizes user auth checks and Firestore profile fetches during the entrance animations, accelerating launch times.
- **Morphing Liquid Blobs**: Draws organic drifting liquid blobs using a custom `_LiquidOrbsPainter` alongside expanding ripple waves.

### 2. Live Storage Scanner & Category Clearing
- **Recursive Directory Scan**: Computes actual cache sizes across local directories and partitions usage into Images, Videos, and Documents.
- **Selective Purge**: Allows users to clear files category-by-category.
- **Storage Ring representation**: Visualizes resource usage through a custom circular storage distribution ring widget.

### 3. Persistent Data Tracker
- **Traffic Tracking**: Displays cellular and Wi-Fi data statistics (sent and received) tracked persistently using local configurations.
- **Reset Option**: Offers a simple reset option to clear statistics to zero.

### 4. Diagnostics & Support Center
- **FAQ search**: Adds real-time query searching and category filter chips to Help/FAQ.
- **Direct Ticket Creation**: Features a glassmorphic Contact Support form that submits ticket details directly to the Firestore `/support_tickets` collection.
- **Live Latency Ping**: Dynamically measures connection latency and gRPC/Firestore network operational health.

### 5. Premium Stickers & Emojis-to-Icons Overhaul
- **Sticker Achievement Lock**: Locks Premium Sticker categories (Love, Gaming) behind customizable achievement tiers streamed from Firestore.
- **Chronos Messages Icon Update**: Replaces all text emojis in the Chronos Messages UI with modern Material Design icons.

