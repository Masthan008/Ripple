const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ═══════════════════════════════════════════════════════
// 1. New message in 1-to-1 chat → push notification
// ═══════════════════════════════════════════════════════
exports.onNewMessage = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const message = snap.data();
        const chatId = context.params.chatId;
        const senderId = message.senderId;

        // Get chat doc to find recipient
        const chatDoc = await admin.firestore()
            .collection('chats').doc(chatId).get();
        if (!chatDoc.exists) return null;

        const participants = chatDoc.data().participants;
        const recipientId = participants.find(id => id !== senderId);
        if (!recipientId) return null;

        // Get recipient's FCM token and notification settings
        const [recipientDoc, senderDoc] = await Promise.all([
            admin.firestore().collection('users').doc(recipientId).get(),
            admin.firestore().collection('users').doc(senderId).get(),
        ]);

        if (!recipientDoc.exists) return null;

        const recipientData = recipientDoc.data();
        const senderName = senderDoc.exists ? senderDoc.data().name : 'Someone';
        const fcmToken = recipientData.fcmToken;
        const notifSettings = recipientData.notificationSettings || {};

        if (!fcmToken) return null;
        if (notifSettings.messages === false) return null;

        // Build notification payload
        const messageText = message.type === 'text'
            ? message.text
            : message.type === 'image' ? '📷 Sent a photo'
                : message.type === 'video' ? '🎥 Sent a video'
                    : '📎 Sent a file';

        try {
            await admin.messaging().send({
                notification: {
                    title: senderName,
                    body: messageText,
                },
                data: {
                    type: 'chat',
                    chatId: chatId,
                    senderId: senderId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                token: fcmToken,
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'ripple_messages',
                        sound: 'default',
                        priority: 'high',
                    },
                },
                apns: {
                    payload: { aps: { sound: 'default', badge: 1 } },
                },
            });
        } catch (e) {
            console.error('FCM send error:', e);
        }
        return null;
    });

// ═══════════════════════════════════════════════════════
// 2. New group message → push to all members except sender
// ═══════════════════════════════════════════════════════
exports.onNewGroupMessage = functions.firestore
    .document('groups/{groupId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const message = snap.data();
        const groupId = context.params.groupId;
        const senderId = message.senderId;

        const [groupDoc, senderDoc] = await Promise.all([
            admin.firestore().collection('groups').doc(groupId).get(),
            admin.firestore().collection('users').doc(senderId).get(),
        ]);

        if (!groupDoc.exists) return null;

        const groupData = groupDoc.data();
        const memberIds = groupData.memberIds || groupData.members || [];
        const groupName = groupData.name;
        const senderName = senderDoc.exists ? senderDoc.data().name : 'Someone';

        const messageText = message.type === 'text'
            ? message.text : '📎 Attachment';

        // Send to all members except sender
        const recipients = memberIds.filter(id => id !== senderId);

        const userDocs = await Promise.all(
            recipients.map(uid =>
                admin.firestore().collection('users').doc(uid).get()
            )
        );

        const sendPromises = userDocs.map(doc => {
            if (!doc.exists) return null;
            const data = doc.data();
            if (!data.fcmToken) return null;
            const notifSettings = data.notificationSettings || {};
            if (notifSettings.groupMessages === false) return null;

            return admin.messaging().send({
                notification: {
                    title: groupName,
                    body: `${senderName}: ${messageText}`,
                },
                data: {
                    type: 'group',
                    groupId: groupId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                token: data.fcmToken,
                android: {
                    priority: 'high',
                    notification: {
                        channelId: 'ripple_messages',
                        sound: 'default',
                    },
                },
                apns: {
                    payload: { aps: { sound: 'default', badge: 1 } },
                },
            }).catch(e => console.error(`FCM error for ${doc.id}:`, e));
        });

        return Promise.all(sendPromises.filter(Boolean));
    });

// ═══════════════════════════════════════════════════════
// 3. Friend request received → push notification
// ═══════════════════════════════════════════════════════
exports.onFriendRequest = functions.firestore
    .document('users/{userId}')
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();

        const beforeReceived = (before.friendRequests && before.friendRequests.received) || [];
        const afterReceived = (after.friendRequests && after.friendRequests.received) || [];

        // A new request was added
        if (afterReceived.length <= beforeReceived.length) return null;

        const newRequesterId = afterReceived.find(
            id => !beforeReceived.includes(id)
        );
        if (!newRequesterId) return null;

        const fcmToken = after.fcmToken;
        const notifSettings = after.notificationSettings || {};
        if (!fcmToken) return null;
        if (notifSettings.friendRequests === false) return null;

        const requesterDoc = await admin.firestore()
            .collection('users').doc(newRequesterId).get();
        const requesterName = requesterDoc.exists
            ? requesterDoc.data().name : 'Someone';

        try {
            await admin.messaging().send({
                notification: {
                    title: 'New Friend Request 👋',
                    body: `${requesterName} wants to connect with you`,
                },
                data: {
                    type: 'friend_request',
                    fromUid: newRequesterId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
                token: fcmToken,
                android: { priority: 'high' },
            });
        } catch (e) {
            console.error('FCM friend request error:', e);
        }
        return null;
    });

// ═══════════════════════════════════════════════════════
// 4. Delete group Cloud Function (callable)
// ═══════════════════════════════════════════════════════
exports.deleteGroup = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated', 'Must be logged in'
        );
    }
    const groupId = data.groupId;
    if (!groupId) {
        throw new functions.https.HttpsError(
            'invalid-argument', 'groupId is required'
        );
    }

    const groupRef = admin.firestore().collection('groups').doc(groupId);

    // Delete all messages subcollection
    const messages = await groupRef.collection('messages').get();
    const batch = admin.firestore().batch();
    messages.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    // Delete group document
    await groupRef.delete();
    return { success: true };
});

// ═══════════════════════════════════════════════════════
// 5. New call → push notification to callee/group
// ═══════════════════════════════════════════════════════
exports.onNewCall = functions.firestore
    .document('calls/{callId}')
    .onCreate(async (snap, context) => {
        const call = snap.data();
        const callId = context.params.callId;

        const callerDoc = await admin.firestore()
            .collection('users').doc(call.callerId).get();
        const callerName = callerDoc.exists ? callerDoc.data().name : 'Someone';

        const notifTitle = call.type === 'video'
            ? '📹 Incoming Video Call'
            : '📞 Incoming Voice Call';

        if (call.isGroup) {
            // Notify all group members except caller
            const memberIds = call.memberIds || [];
            const recipients = memberIds.filter(id => id !== call.callerId);

            const userDocs = await Promise.all(
                recipients.map(uid =>
                    admin.firestore().collection('users').doc(uid).get()
                )
            );

            const sends = userDocs.map(doc => {
                if (!doc.exists) return null;
                const u = doc.data();
                if (!u.fcmToken) return null;

                return admin.messaging().send({
                    token: u.fcmToken,
                    notification: {
                        title: notifTitle,
                        body: `${callerName} is calling the group`,
                    },
                    data: {
                        type: 'call',
                        callId: callId,
                        callType: call.type,
                        isGroup: 'true',
                        click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                    android: {
                        priority: 'high',
                        notification: { channelId: 'ripple_calls' },
                    },
                }).catch(e => console.error(`FCM call error:`, e));
            });

            return Promise.all(sends.filter(Boolean));
        } else {
            // Notify single callee
            if (!call.calleeId) return null;
            const calleeDoc = await admin.firestore()
                .collection('users').doc(call.calleeId).get();
            if (!calleeDoc.exists) return null;

            const u = calleeDoc.data();
            if (!u.fcmToken) return null;

            try {
                await admin.messaging().send({
                    token: u.fcmToken,
                    notification: {
                        title: notifTitle,
                        body: `${callerName} is calling you`,
                    },
                    data: {
                        type: 'call',
                        callId: callId,
                        callType: call.type,
                        isGroup: 'false',
                        callerId: call.callerId,
                        click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                    android: {
                        priority: 'high',
                        notification: { channelId: 'ripple_calls' },
                    },
                });
            } catch (e) {
                console.error('FCM call error:', e);
            }
            return null;
        }
    });
