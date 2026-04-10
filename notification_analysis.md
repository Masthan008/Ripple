# Notification Issues Analysis Report

## Issue 1: Bell Icon Showing Instead of App Logo
**Problem:** When a push notification arrives, the status bar shows a default bell icon, though pulling down the shade reveals the full app icon.
**Root Cause:**
On modern Android versions, the tiny status bar icon must be a monochromatic (white with transparent background) silhouette icon. Since the app does not provide a specifically named icon for OneSignal, it falls back to a generic default bell icon.
**Proposed Solution:**
1. Generate an alpha-only (white and transparent) version of the Ripple app logo.
2. Place this icon in the `android/app/src/main/res/drawable-*dpi` directories, naming it exactly `ic_stat_onesignal_default.png`.
3. (Optional) Add a meta-data tag in `AndroidManifest.xml` to define the default notification accent color so the icon takes on the app's theme color:
   ```xml
   <meta-data android:name="com.onesignal.NotificationAccentColor.DEFAULT" android:value="FF0EA5E9" />
   ```

## Issue 2: Notifications Appearing While Actively Chatting
**Problem:** User A and User B are already inside the 1-on-1 chat or group chat screen, but when User B sends a new message, User A still receives an intrusive push notification drop-down.
**Root Cause:**
Push notifications are triggered server-side (or via REST API from the sender) and delivered to the OneSignal native SDK. By default, OneSignal displays foreground notifications for all arriving pushes because it cannot automatically detect which Flutter UI screen is currently active.
**Proposed Solution:**
To suppress the notification selectively:
1. **State Tracking:** Introduce static variables in `NotificationService` (e.g., `static String? activeChatId;` and `static String? activeGroupId;`).
2. **Lifecycle Updates:** In the `initState()` of `ChatScreen` and `GroupChatScreen`, set these variables to the opened chat's ID. In `dispose()`, set them back to `null`.
3. **Intercept Display:** Add a foreground listener in `main.dart` or `NotificationService.initialize()` using:
   ```dart
   OneSignal.Notifications.addForegroundWillDisplayListener((event) {
     final data = event.notification.additionalData;
     if (data != null) {
       // Suppress if user is currently looking at this specific 1-on-1 chat
       if (data['type'] == 'chat' && data['chatId'] == NotificationService.activeChatId) {
         event.preventDefault();
       }
       // Suppress if user is currently looking at this specific group chat
       if (data['type'] == 'group' && data['groupId'] == NotificationService.activeGroupId) {
         event.preventDefault();
       }
     }
   });
   ```
This interception completely stops the repetitive top-of-screen popups when users are actively communicating in that specific thread.
