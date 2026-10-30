# Ripple — Registry of Hidden & Suppressed Features

**Last Updated: October 30, 2026**  
**Document Purpose**: Tracks features that are temporarily hidden or disabled in the client UI so they can be reviewed and easily unhidden or re-activated in future development cycles.

---

## 1. 📞 1-to-1 Audio Calling (Voice Calls)
* **Current Status**: **Hidden from UI** (Underlying Daily.co WebRTC signaling & service remain fully intact).
* **Reason**: Temporarily hidden per user request to streamline communications, reduce clutter, and focus on E2EE messaging and video calling.
* **Affected Files & Code References**:
  1. [`lib/features/chat/screens/chat_screen.dart`](lib/features/chat/screens/chat_screen.dart):
     * *Location*: App bar action buttons (~line 1684).
     * *Commented Block*:
       ```dart
       // Audio call (Temporarily hidden per sovereign privacy guidelines; see HIDDEN_FEATURES.md)
       /*
       GestureDetector(
         onTap: () => _startCall(isVideo: false),
         child: Container(
           width: 32,
           height: 32,
           decoration: BoxDecoration(
             color: AppColors.glassPanel,
             shape: BoxShape.circle,
             border: Border.all(color: AppColors.glassBorder, width: 0.5),
           ),
           child: const Icon(Icons.call_rounded, color: AppColors.lightWave, size: 16),
         ),
       ),
       const SizedBox(width: 2),
       */
       ```
  2. [`lib/features/profile/screens/other_user_profile_screen.dart`](lib/features/profile/screens/other_user_profile_screen.dart):
     * *Location*: Quick action button row (~line 643).
     * *Commented Block*:
       ```dart
       // Voice call hidden per sovereign privacy guidelines (see HIDDEN_FEATURES.md)
       /*
       _buildActionButton(
         icon: Icons.call_rounded,
         label: 'Call',
         onTap: () {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Starting voice call...')),
           );
         },
       ),
       */
       ```
* **How to Re-Enable**:
  * Remove the block comments `/* ... */` in both files. Audio calls will immediately re-appear in chat headers and user profile cards.

---

## 2. 📡 Offline BitChat Mesh Networking
* **Current Status**: **Hidden in Chat Navigation** (Bluetooth LE & Wi-Fi Direct mesh codebase preserved in `lib/features/offline_mesh/`).
* **Reason**: Temporarily disabled from the chat stream to focus on internet-based Signal Double Ratchet E2EE protocol and Stealth Vault isolation.
* **Affected Files**:
  * `lib/features/chat/screens/chat_screen.dart`: Mesh fallback indicator toggles.
  * `lib/features/offline_mesh/screens/offline_radar_screen.dart`: Standalone radar view.
* **How to Re-Enable**:
  * Re-insert the radar action icon or drawer toggle to launch `OfflineRadarScreen` when offline conditions are detected.

---

## 3. 📅 Meeting Scheduling (Jitsi / Video Rooms)
* **Current Status**: **Permanently Removed**.
* **Reason**: Removed per user specification to keep Ripple focused strictly on 1-to-1 secure calls and direct group messaging.
* **Affected Files**:
  * `lib/features/calls/screens/meetings_screen.dart`: Permanently deleted.
  * `lib/app.dart`: `/meetings` route removed.
  * `lib/features/chat/screens/chat_list_screen.dart`: Meeting video call shortcut removed.

---

## 4. ☁️ Google Drive Cloud Sync
* **Current Status**: **Removed from Backup Engine**.
* **Reason**: Eliminated third-party cloud telemetry in favor of client sovereignty; replaced with AES-256 encrypted local `.rpbk` backup archives exported via the native OS share sheet.
* **Affected Files**:
  * `lib/features/profile/screens/chat_backup_screen.dart`: Drive authentication button removed; native file share & restore active.

---

## 5. 🤖 AI Chat Summarization & Spark Icons
* **Current Status**: **Removed from Chat App Bar**.
* **Reason**: Purged per user request to maintain an uncluttered, distraction-free conversation view.
* **Affected Files**:
  * `lib/features/chat/screens/chat_screen.dart`: AI spark action icon suppressed.

---

## 6. 🏆 Gamified Challenges & Weekly Achievements
* **Current Status**: **Removed from UI Navigation**.
* **Reason**: Purged per user direction to transition Ripple from a gamified app into a sovereign, high-performance encrypted communications workstation.
* **Affected Files**:
  * `lib/features/profile/screens/profile_screen.dart`: Achievements carousel removed.
  * `lib/features/challenges/`: Dormant background service.

---

## 💡 Summary Quick Reference

| Feature | Current State | Re-Enable Effort |
| :--- | :--- | :--- |
| **Audio Calling** | Commented in UI | 1 minute (uncomment 2 UI blocks) |
| **Offline Mesh** | Hidden in chat | 5 minutes (re-expose radar button) |
| **Meetings** | Fully Removed | Requires re-implementation if desired |
| **Google Drive** | Replaced with `.rpbk` | Not recommended (breaks zero-knowledge) |
| **AI Summarize** | Suppressed | 2 minutes (unhide app bar icon) |
| **Achievements** | Hidden from Profile | 5 minutes (restore profile section) |
