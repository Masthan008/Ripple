# 🛡️ Ripple Security & Privacy Guide

Welcome to the consolidated **Security & Privacy Guide** for Ripple Chat. This document aggregates all of Ripple's advanced security models, cryptographic protocols, on-device AI guardians, and privacy configurations in one place.

---

## 🧭 Directory of Settings & Controls

| Feature | Key Technology | Code Reference | Description |
| :--- | :--- | :--- | :--- |
| **End-to-End Encryption (E2EE)** | Curve25519 (X3DH) & AES-256-GCM | [secret_chat_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/secret_chat_service.dart) | Automatically negotiates cryptographic keys and encrypts chats on-device. |
| **Steganography (Acoustic Stealth)** | Least Significant Bit (LSB) Audio Coding | [steganography_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/steganography_service.dart) | Embeds and recovers E2EE encrypted payloads within rainfall white noise WAVs. |
| **Ripple Telepathy™ (Gaze Lock)** | On-Device ML Kit Face Detection | [gaze_privacy_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/gaze_privacy_service.dart) | Blurs chat message bubbles unless the user is looking directly at them. |
| **Anti-Shoulder Surfing** | Front Camera Face Stream Analysis | [gaze_privacy_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/gaze_privacy_service.dart) | Instantly blurs the screen and fires haptics if a second face enters the frame. |
| **Sentient Decoy Matrix** | Hashed SHA-256 Passcodes | [privacy_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/privacy_service.dart) | Opens a fake, sandboxed chat feed when entered during app login. |
| **Biometric Chat Lock** | Android/iOS Local Auth | [chat_lock_settings_screen.dart](file:///c:/valli/RIPPLE/ripple/lib/features/privacy/screens/chat_lock_settings_screen.dart) | Hides and locks individual/group chats behind biometric authentication. |
| **Stealth Mode** | Firestore Presence Rules | [privacy_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/privacy_service.dart) | Makes user appear permanently offline (globally or to specific contacts). |
| **Vanish Mode (Self-Destruct)** | Firestore TTL & Scheduled Deletion | [privacy_service.dart](file:///c:/valli/RIPPLE/ripple/lib/core/services/privacy_service.dart) | Deletes messages on both devices after a specified countdown once read. |
| **Native Screen Protection** | OS window layout flags | [privacy_settings_screen.dart](file:///c:/valli/RIPPLE/ripple/lib/features/privacy/screens/privacy_settings_screen.dart) | Prevents screenshots, video recordings, and blurs previews in recent apps. |
| **Sonic Whispers™** | Micro-decibel Monitoring | [privacy_settings_screen.dart](file:///c:/valli/RIPPLE/ripple/lib/features/privacy/screens/privacy_settings_screen.dart) | Dynamically blocks or allows auto-transcription depending on ambient noise. |

---

## 🔒 1. End-to-End Encryption (E2EE)
Ripple implements E2EE using an automated **Curve25519 X3DH (Extended Triple Diffie-Hellman)** key agreement handshake, combined with **AES-256-GCM** authenticated symmetric encryption.

* **Key Generation & Storage**: 
  When a user logs in, Ripple automatically generates an Identity Key (IK), a Signed Prekey (SPK), and five One-Time Prekeys (OPKs). The public keys are uploaded to Firestore (`/users/{uid}/prekeys/bundle`). The private keys are kept exclusively on-device in secure storage via the `flutter_secure_storage` package (using native Android `EncryptedSharedPreferences` and iOS Keychain).
* **Handshake Agreement**: 
  When initiating a chat, Alice retrieves Bob's prekey bundle, generates an Ephemeral Key (EK), computes four DH operations (DH1, DH2, DH3, DH4), and derives a master 256-bit AES session key using SHA-256. Alice publishes the handshake metadata under `secretChats/{chatId}/handshake/init` for Bob to complete the handshake.
* **Message Cryptography**: 
  Messages are encrypted using AES-256-GCM with a secure 96-bit (12-byte) initialization vector (IV) generated from a secure random source. The payload stores the encrypted ciphertext and IV in base64 format, preventing interceptors or servers from reading the communication.

---

## 🌊 2. Steganography (Acoustic Stealth)
Steganography hides E2EE-encrypted data inside standard media files, adding a second layer of plausible deniability.

* **LSB WAV Encoding**: 
  Ripple converts payloads (with an End of Message marker `##RIPPLE_STEG_EOM##`) into a raw bitstream. It then replaces the Least Significant Bit (LSB) of each 16-bit PCM sample in a WAV audio file.
* **Cover Generation**: 
  Ripple automatically generates cover audio WAV files representing calming rainfall white noise by randomizing PCM samples with a low amplitude threshold.
* **Performance Isolation**: 
  Because bitwise modification of raw audio arrays requires heavy processing, Ripple offloads both encoding and decoding to background Dart Isolates via the `compute` helper, keeping the app UI running at a smooth 60fps.

---

## 👁️ 3. Ripple Telepathy™ (Gaze & Proximity Privacy)
Ripple Telepathy™ utilizes the device's front-facing camera and Google ML Kit on-device face detection to secure screens from physical snooping.

* **Gaze Lock**: 
  Locks/frosts the chat bubble UI elements unless the user is looking directly at the device screen. Euler Y-rotation metrics are analyzed to determine if the user's focus is on the device.
* **Anti-Shoulder Surfing**: 
  Constantly monitors the camera stream. If a second face is detected within the frame, the entire screen immediately applies an intense blur overlay, haptic vibrations fire, and an alert sounds.
* **100% Local Processing**: 
  For strict privacy, no images or face biometric metrics are stored or transmitted. All calculations are executed locally within memory buffers.

---

## 🎭 4. Sentient Decoy Matrix (Decoy Passcodes)
The Decoy Matrix provides physical-duress security.

* **Simulated Sandbox**: 
  If forced to open Ripple, the user can enter a custom, predefined decoy passcode. Entering this code signs in a simulated account showing a realistic but completely simulated sandbox environment with fake chats and automated responses.
* **Cryptographic Salting**: 
  Decoy passcodes are hashed locally using SHA-256 with a unique salt key (`ripple_`) and checked against the stored preference hash, preventing reverse engineering of passcodes from memory dumps.

---

## 🔐 5. Biometric Chat Lock
Allows securing sensitive individual chats directly from the chat feed.

* **Biometric Auth**: 
  Users can lock a chat room by long-pressing it. Opening a locked chat invokes local system-level authentication (Fingerprint, Face ID, or system PIN) using the `local_auth` package.
* **Locked registry**: 
  The list of locked chat IDs is stored locally inside secure shared preferences.

---

## ✈️ 6. Stealth Mode & Visibility Controls
Stealth Mode controls network presence.

* **Stealth Switch**: 
  Forces the Firestore profile key `isOnline` to `false` and locks the `lastSeen` indicator to the time Stealth Mode was activated. It also suppresses outgoing read receipts and typing status indicators.
* **Targeted Stealth**: 
  Users can configure specific contacts to block presence data from using the `stealthContacts` array in Firestore, allowing granular control over who sees them online.

---

## ⏳ 7. Vanish Mode (Self-Destructing Messages)
* **Message TTL**: 
  Users can configure individual messages to automatically disappear after a specified timeout (e.g., 5 seconds, 30 seconds) once they have been viewed by the recipient. 
* **Firestore Scheduling**: 
  Vanish mode sets a `deleteAt` timestamp in Firestore. The app monitors messages and automatically triggers deletion operations on both client devices once the timestamp is reached.

---

## 🚫 8. Native Screen Protection
* **Screenshot & Recents Blocking**: 
  Uses the native Android window manager flag `FLAG_SECURE` (via the `flutter_windowmanager_plus` package) to prevent taking screenshots or recording the screen. This flag also automatically obscures the application layout window preview inside the OS recent tasks switcher.

---

## 🚫 9. Sonic Whispers™ Ambient Transcription
* **Smart Transcriptions**: 
  Monitors ambient decibel levels through the microphone. If the surrounding room noise is too high (above a user-configured threshold, e.g., 60dB), Ripple disables auto-transcription or locks specific voice playback modes to prevent audio leakage.
