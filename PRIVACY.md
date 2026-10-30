# Privacy Policy for Ripple

**Last Updated: October 30, 2026**

At **Ripple**, we believe privacy is not an optional feature—it is a fundamental human right. Ripple was built from the ground up as a **Zero-Trace, Sovereign Encrypted Communication Platform**.

---

## 1. Zero Metadata Retention Principle
- **No Message Storage on Servers**: All direct and group messages are end-to-end encrypted on sender devices using the **Signal Double Ratchet Protocol** and **AES-256-GCM**.
- **No IP or Location Logging**: Ripple does not maintain access logs, connection IP histories, or geo-telemetry.
- **Ephemeral Session Routing**: Push notifications routed through Zoho Catalyst and Google FCM convey encrypted envelopes only, with zero plain text exposure.

---

## 2. End-to-End Encryption (E2EE)
- Cryptographic private keys never leave your physical device hardware.
- Local chat archives, stealth vaults, and backup exports are secured via hardware-backed AES keys managed by Android Keystore / iOS Secure Enclave (`flutter_secure_storage`).

---

## 3. Account Data & Information We Collect
- **Profile Info**: Your chosen display name, optional `@username`, and avatar image (if uploaded).
- **Authentication**: Email address or phone token required solely to verify identity and enable cloud account restoration.
- **Device Identifiers**: Push notification tokens (FCM) used strictly to wake up the app for incoming calls and encrypted messages.

---

## 4. Stealth Vault Isolation
Chats designated for the **Stealth Vault** are entirely invisible to search, notification badges, and the main chat stream. Vault contents remain encrypted in hardware storage and unlock exclusively via your biometric signature or custom secret dial code.

---

## 5. Instant Account Deletion
You maintain complete sovereignty over your data. Tapping **"Delete Account Permanently"** instantly executes an irreversible cascade across Firebase Auth, Firestore, and Zoho Catalyst Datastores, erasing all records permanently.

---

## 6. Contact & Auditing
For security inquiries, audit verifications, or vulnerability reports:
- **Repository**: [github.com/Masthan008/Ripple](https://github.com/Masthan008/Ripple)
- **Security Team**: `security@ripple.io`
