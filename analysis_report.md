# Call Routing Issues Analysis Report

## Issue 1: Audio Calls Starting as Video Calls in Chats
**Problem:** When a user taps the "Audio Call" button in a 1-on-1 chat or group chat, the call still opens with the video enabled.
**Root Cause:**
In `lib/features/calls/screens/daily_call_screen.dart`, the app uses `DailyService.createRoom()` and loads the Daily.co room URL in an `InAppWebView`. However, the `_buildDailyUrl()` method does not pass any flags to disable the camera when `isVideo` is `false`. By default, Daily.co always requests camera access and turns on video unless explicitly told not to.
**Proposed Solution:**
Modify `_buildDailyUrl()` in `DailyCallScreen` to append a `cameraOff=true` (or `v=0` / JS injection depending on Daily.co configuration) parameter if `widget.isVideo == false`. This will ensure the camera is disabled upon joining an audio-only call.

## Issue 2: Group Calls Not Connecting / "Not Getting"
**Problem:** When a user starts a call in a group chat, the other group members do not receive any notification and cannot join the call.
**Root Cause:**
There are two reasons why group calls fail to reach other members:
1. **Push Notifications are Bypassed:** In `DailyCallScreen`, the `_sendCallNotification()` method explicitly skips sending push notifications if the call is a group call (`if (widget.isGroup) return;`).
2. **No In-Chat Notification:** When `_startGroupCall` is invoked in `GroupChatScreen`, it creates a call document in the `calls` collection and navigates the caller to the call screen, but it *never adds a message to the group chat's messages collection*. Since there is no system message in the chat saying "User started a call" with a Join button, and no push notifications are sent, the other members have absolutely no way to know a call is happening.

**Proposed Solution:**
1. **Broadcast Notifications:** Update `_sendCallNotification()` (or create a dedicated group notification method) to fetch the group members' `oneSignalPlayerId`s and send a push notification to all participants.
2. **System Chat Message (Optional but Recommended):** In `_startGroupCall()`, add a new message to the group chat (e.g., type: `call_invite`) so that users currently in the app can tap a "Join Call" button to enter the active Daily.co room.
