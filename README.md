# Ripple — Liquid Glass Aquatic AI Chat

A next-generation messaging application built with Flutter, featuring liquid glass aesthetics, on-device ML, spatial workspaces, and sensory typing physics.

**222 Dart files** | 16 feature modules | Firebase + Supabase + OneSignal + Daily.co

---

## Features

### Core Messaging
| Feature | Status |
|---------|--------|
| 1-on-1 chat with text, images, video, voice, GIFs, stickers, polls, files | ✅ |
| Group chat with member management, invite codes | ✅ |
| Voice messages with Sonic Whisper (ambient-aware auto transcript) | ✅ |
| Message reactions (emojis + custom) | ✅ |
| Message scheduling & Chronos time capsules | ✅ |
| Saved / archived messages | ✅ |
| Cloud drive (file storage & preview) | ✅ |
| Document viewer (PDF via InAppWebView, Office docs) | ✅ |
| Global search across chats, users, messages | ✅ |

### Security & Privacy
| Feature | Status |
|---------|--------|
| Ripple Telepathy — ML Kit gaze tracking blurs messages on look-away | ✅ |
| Anti-shoulder surfing — instant blur if second face detected | ✅ |
| Biometric / PIN chat lock (`local_auth`) | ✅ |
| App lock gate on resume | ✅ |
| Decoy passcode (fake account screen) | ✅ |
| Screenshot blocking via `FLAG_SECURE` | ✅ |
| AES-256 GCM encryption with PBKDF2 key derivation | ✅ |
| Vanish Mode (self-destructing messages) | ✅ |
| Chat lock with lock timer | ✅ |

### Group Chats
| Feature | Status |
|---------|--------|
| Standard linear group chat | ✅ |
| Spatial Canvas — 2D infinite canvas with drag-and-drop bubbles | ✅ |
| Semantic Currents — contextual topic threads within groups | ✅ |
| Polls inside groups | ✅ |
| Join via invite code | ✅ |

### Voice & Video Calls
| Feature | Status |
|---------|--------|
| Daily.co WebRTC 1-on-1 audio/video calls | ✅ |
| Group calls | ✅ |
| Incoming call screen with notification | ✅ |
| Missed call notifications | ✅ |
| PiP overlay during calls | ✅ |

### AI
| Feature | Status |
|---------|--------|
| Ripple Bot (AI chatbot) | ✅ |
| AI settings & model picker | ✅ |

### Social
| Feature | Status |
|--------|--------|
| Friend requests & management | ✅ |
| User discovery & suggestions | ✅ |
| Status / stories (like Instagram) with mood aura rings | ✅ |
| Status reactions | ✅ |
| Activity feed | ✅ |
| Achievements & badges | ✅ |
| Leaderboard | ✅ |
| Profile visitors | ✅ |
| Weekly challenges with rewards | ✅ |

### Gifts & Premium
| Feature | Status |
|---------|--------|
| Gift card system (send/receive) | ✅ |
| Premium subscription plans | ✅ |
| Premium sticker categories (Love, Gaming) | ✅ |

### Personalization
| Feature | Status |
|---------|--------|
| 5+ theme presets (Aqua Ocean, Bioluminescent, etc.) | ✅ |
| Light/dark mode per theme | ✅ |
| Custom wallpaper colors per chat | ✅ |
| App icon switching (Default, Abyss, Gold, Glitch) | ✅ |
| Custom notification tones support | ✅ |
| Language selection (l10n) | ✅ |
| Accessibility (text scaling, bold, reduced motion, color blind mode) | ✅ |

### Notification System
| Feature | Status |
|---------|--------|
| OneSignal push notifications | ✅ |
| Per-chat mute (8h, 1w, always) | ✅ |
| Global notification toggles (messages, groups, calls, friend requests) | ✅ Enforced |
| In-app sound / vibration control | ✅ Wired |
| 4 Android notification channels (messages, calls, groups, social) | ✅ |
| Custom notification icon | ✅ |
| Foreground mute suppression (async) | ✅ |
| Notification tap -> deep navigation | ✅ |
| Unread badge counts on navbar tabs | ✅ |

---

## Architecture

```
lib/
  main.dart                          # Entry point — splash-first init
  app.dart                           # GoRouter + MaterialApp.router (42 routes)
  core/
    constants/          (3 files)    # Colors, strings, text styles
    services/           (20 files)   # Firebase, OneSignal, encryption, AI, calls, media
    theme/              (6 files)    # RippleTheme, dynamic switching, glass theme
    utils/              (10 files)   # Helpers, env, haptics, animations, l10n
  features/
    ai/                 (5 files)    # Ripple Bot chatbot
    auth/               (5 files)    # Firebase Auth (Google + Email), 2-phase registration
    calls/              (5 files)    # Daily.co WebRTC calls
    challenges/         (4 files)    # Weekly challenges & badges
    chat/               (52 files)   # Core messaging (largest module)
    friends/            (3 files)    # Friend requests & user discovery
    gifts/              (4 files)    # Gift cards
    groups/             (12 files)   # Group chat + Spatial Canvas + Semantic Currents
    premium/            (3 files)    # Subscriptions
    privacy/            (10 files)   # Gaze lock, decoy, vanish mode, app lock
    profile/            (23 files)   # 18 settings screens
    search/             (1 file)     # Global search
    social/             (8 files)    # Activity feed, achievements, leaderboard
    status/             (7 files)    # Stories with mood aura
    stickers/           (3 files)    # Premium sticker picker
  shared/
    widgets/            (35 files)   # Liquid glass UI components
```

### State Management: Riverpod
- `StreamProvider` for Firebase auth state & Firestore docs
- `StateNotifierProvider` for theme, accessibility settings
- `Provider` for services, API clients

### Routing: GoRouter (42 routes)
- Auth-aware redirect (splash -> login -> register -> home)
- Custom page transitions per route
- `_GoRouterRefreshStream` tracks auth changes

### Services
- **Firebase** — Auth, Firestore, Realtime Database, Crashlytics, Performance
- **Supabase** — File storage
- **Cloudinary** — Media CDN
- **Daily.co** — WebRTC calls via InAppWebView
- **OneSignal** — Push notifications
- **flutter_secure_storage** — Encryption keys
- **ML Kit** — Face detection (gaze tracking)

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.x + Dart 3.7 |
| Auth | Firebase Auth (Google, Email/Password) |
| Database | Firebase Firestore (real-time) |
| Storage | Supabase + Cloudinary |
| Calls | Daily.co WebRTC |
| Push | OneSignal (FCM wrapper) |
| AI | On-device ML Kit |
| Encryption | AES-256 GCM, PBKDF2 |
| State | Riverpod |
| Routing | GoRouter |

---

## Setup

```bash
# Clone & enter
cd RIPPLE/ripple

# Environment
cp .env.example .env
# Fill in Firebase, OneSignal, Daily.co, Supabase, Cloudinary keys
# See ENV_SETUP_GUIDE.md for details

# Dependencies
flutter pub get

# Run
flutter run

# Build APK
flutter build apk --release
```

---

## Build Notes

### Shader Warnings
The `liquid_glass_renderer` package emits SkSL compatibility warnings during build. These are non-fatal — shaders fall back gracefully on devices without SkSL support.

### Known Build Issues
- `flutter_app_badger` is discontinued & incompatible with current AGP — OS-level badge count is deferred.
- Gradle may fail with file-lock errors on Windows — run `taskkill /f /im java.exe` and `flutter clean` before retrying.

### Code Quality
- `flutter analyze` passes with 0 errors
- Pre-existing warnings (deprecated `withOpacity`, unused imports) are pre-codebase

---

## Document References

| File | Purpose |
|------|---------|
| `NOTIFICATION_ANALYSIS.md` | Deep-dive notification system analysis & fix status |
| `FEATURE_COMPARISON.md` | 153-feature pin-to-pin vs WhatsApp, Telegram, Signal, Discord |
| `ripple/ENV_SETUP_GUIDE.md` | API key configuration guide |

---

## License

Proprietary — All rights reserved.
