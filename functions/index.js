const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Helper to collect all unique FCM tokens for a user document.
 */
function extractTokens(userData) {
    if (!userData) return [];
    const tokens = new Set();
    if (typeof userData.fcmToken === 'string' && userData.fcmToken.trim().length > 0) {
        tokens.add(userData.fcmToken.trim());
    }
    if (Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach(t => {
            if (typeof t === 'string' && t.trim().length > 0) {
                tokens.add(t.trim());
            }
        });
    }
    return Array.from(tokens);
}

/**
 * Helper to clean up expired or unregistered FCM tokens from Firestore.
 */
async function pruneInvalidTokens(userId, invalidTokens) {
    if (!userId || !invalidTokens || invalidTokens.length === 0) return;
    try {
        const userRef = admin.firestore().collection('users').doc(userId);
        await userRef.update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
        const userSnap = await userRef.get();
        if (userSnap.exists) {
            const currentPrimary = userSnap.data().fcmToken;
            if (invalidTokens.includes(currentPrimary)) {
                await userRef.update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                });
            }
        }
        console.log(`[FCM] Pruned ${invalidTokens.length} dead token(s) for user: ${userId}`);
    } catch (err) {
        console.warn(`[FCM] Failed to prune dead tokens for user ${userId}:`, err);
    }
}

// ═══════════════════════════════════════════════════════
// 1. New 1-to-1 Chat Message → FCM Multicast Push (v2)
// ═══════════════════════════════════════════════════════
exports.onNewMessage = onDocumentCreated({
    document: 'chats/{chatId}/messages/{messageId}',
    region: 'us-central1',
}, async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const message = snap.data();
    if (!message) return null;

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = message.senderId;
    if (!senderId) return null;

    // Resolve recipient ID
    let recipientId = message.receiverId || message.recipientId;
    if (!recipientId) {
        const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
        if (chatDoc.exists) {
            const participants = chatDoc.data().participants || [];
            recipientId = participants.find(id => id !== senderId);
        }
    }
    if (!recipientId && chatId.includes('_')) {
        const parts = chatId.split('_');
        recipientId = parts[0] === senderId ? parts[1] : parts[0];
    }

    if (!recipientId || recipientId === senderId) return null;

    // Fetch recipient and sender profiles
    const [recipientDoc, senderDoc] = await Promise.all([
        admin.firestore().collection('users').doc(recipientId).get(),
        admin.firestore().collection('users').doc(senderId).get(),
    ]);

    if (!recipientDoc.exists) return null;

    const recipientData = recipientDoc.data();
    const senderData = senderDoc.exists ? senderDoc.data() : {};
    const senderName = senderData.name || 'Someone';

    // Check recipient notification preferences
    const notifSettings = recipientData.notificationSettings || {};
    if (notifSettings.messages === false) {
        console.log(`[FCM] Notifications disabled by recipient: ${recipientId}`);
        return null;
    }

    // Check muted chats
    const mutedChats = recipientData.mutedChats || {};
    if (mutedChats[chatId]) {
        const expiry = mutedChats[chatId];
        if (expiry === 'always') return null;
        if (typeof expiry === 'string' && new Date(expiry) > new Date()) return null;
    }

    // Collect all tokens (mobile + web)
    const targetTokens = extractTokens(recipientData);
    if (targetTokens.length === 0) {
        console.log(`[FCM] No tokens registered for recipient: ${recipientId}`);
        return null;
    }

    // Build notification text
    const type = message.type || 'text';
    let messageText = 'Sent you a message';
    if (type === 'text') {
        messageText = message.text || 'New message';
    } else if (type === 'image') {
        messageText = '📷 Sent a photo';
    } else if (type === 'video') {
        messageText = '🎥 Sent a video';
    } else if (type === 'voice') {
        messageText = '🎙️ Sent a voice message';
    } else if (type === 'gif') {
        messageText = '👾 Sent a GIF';
    } else if (type === 'sticker') {
        messageText = '🎨 Sent a sticker';
    } else if (type === 'poll') {
        messageText = '📊 Created a poll';
    } else if (type === 'file') {
        messageText = '📎 Sent a file';
    }

    const unreadCount = ((recipientData.unreadCount && recipientData.unreadCount[chatId]) || 0) + 1;

    const multicastPayload = {
        tokens: targetTokens,
        notification: {
            title: senderName,
            body: messageText,
        },
        data: {
            type: 'chat',
            chatId: String(chatId),
            senderId: String(senderId),
            senderName: String(senderName),
            messageId: String(messageId),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
            priority: 'high',
            notification: {
                channelId: 'ripple_messages',
                sound: 'default',
                priority: 'high',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default',
                    badge: unreadCount,
                },
            },
        },
        webpush: {
            notification: {
                title: senderName,
                body: messageText,
                icon: '/icons/Icon-192.png',
                badge: '/icons/Icon-192.png',
            },
            fcmOptions: {
                link: `/#/chat/${chatId}`,
            },
        },
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(multicastPayload);
        console.log(`[FCM] Sent message to ${recipientId}: ${response.successCount} success, ${response.failureCount} failed.`);

        if (response.failureCount > 0) {
            const deadTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success && resp.error) {
                    const code = resp.error.code;
                    if (code === 'messaging/registration-token-not-registered' ||
                        code === 'messaging/invalid-registration-token') {
                        deadTokens.push(targetTokens[idx]);
                    }
                }
            });
            if (deadTokens.length > 0) {
                await pruneInvalidTokens(recipientId, deadTokens);
            }
        }
    } catch (error) {
        console.error('[FCM] Error dispatching multicast notification:', error);
    }

    return null;
});

// ═══════════════════════════════════════════════════════
// 2. New Group Message → Push to all members except sender (v2)
// ═══════════════════════════════════════════════════════
exports.onNewGroupMessage = onDocumentCreated({
    document: 'groups/{groupId}/messages/{messageId}',
    region: 'us-central1',
}, async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const message = snap.data();
    if (!message) return null;

    const groupId = event.params.groupId;
    const senderId = message.senderId;
    if (!senderId) return null;

    const [groupDoc, senderDoc] = await Promise.all([
        admin.firestore().collection('groups').doc(groupId).get(),
        admin.firestore().collection('users').doc(senderId).get(),
    ]);

    if (!groupDoc.exists) return null;

    const groupData = groupDoc.data();
    const memberIds = groupData.memberIds || groupData.members || [];
    const groupName = groupData.name || 'Group Chat';
    const senderName = senderDoc.exists ? senderDoc.data().name : 'Someone';

    const messageText = message.type === 'text'
        ? message.text
        : '📎 Attachment';

    const recipientIds = memberIds.filter(id => id !== senderId);
    if (recipientIds.length === 0) return null;

    const recipientDocs = await Promise.all(
        recipientIds.map(uid => admin.firestore().collection('users').doc(uid).get())
    );

    const allTokens = [];

    recipientDocs.forEach(doc => {
        if (!doc.exists) return;
        const data = doc.data();
        const notifSettings = data.notificationSettings || {};
        if (notifSettings.groupMessages === false) return;

        const tokens = extractTokens(data);
        tokens.forEach(t => allTokens.push(t));
    });

    if (allTokens.length === 0) return null;

    const payload = {
        tokens: allTokens,
        notification: {
            title: groupName,
            body: `${senderName}: ${messageText}`,
        },
        data: {
            type: 'group',
            groupId: String(groupId),
            senderId: String(senderId),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
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
        webpush: {
            notification: {
                title: groupName,
                body: `${senderName}: ${messageText}`,
                icon: '/icons/Icon-192.png',
                badge: '/icons/Icon-192.png',
            },
            fcmOptions: {
                link: `/#/group/${groupId}`,
            },
        },
    };

    try {
        const res = await admin.messaging().sendEachForMulticast(payload);
        console.log(`[FCM] Group message sent to ${groupId}: ${res.successCount} ok, ${res.failureCount} failed.`);
    } catch (e) {
        console.error('[FCM] Group multicast error:', e);
    }

    return null;
});

// ═══════════════════════════════════════════════════════
// 3. New Call Notification (v2)
// ═══════════════════════════════════════════════════════
exports.onNewCall = onDocumentCreated({
    document: 'calls/{callId}',
    region: 'us-central1',
}, async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const call = snap.data();
    if (!call) return null;

    const callId = event.params.callId;
    const callerDoc = await admin.firestore().collection('users').doc(call.callerId).get();
    const callerName = callerDoc.exists ? callerDoc.data().name : 'Someone';

    const notifTitle = call.type === 'video'
        ? '📹 Incoming Video Call'
        : '📞 Incoming Voice Call';

    if (call.isGroup) {
        const memberIds = call.memberIds || [];
        const recipients = memberIds.filter(id => id !== call.callerId);
        const userDocs = await Promise.all(
            recipients.map(uid => admin.firestore().collection('users').doc(uid).get())
        );

        const allTokens = [];
        userDocs.forEach(d => {
            if (d.exists) {
                allTokens.push(...extractTokens(d.data()));
            }
        });

        if (allTokens.length === 0) return null;

        await admin.messaging().sendEachForMulticast({
            tokens: allTokens,
            notification: {
                title: notifTitle,
                body: `${callerName} is calling the group`,
            },
            data: {
                type: 'call',
                callId: String(callId),
                channelName: String(call.channelName || callId),
                callType: String(call.type || 'audio'),
                callerName: String(callerName),
                callerUserId: String(call.callerId),
                isGroup: 'true',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'ripple_calls',
                    sound: 'default',
                    priority: 'max',
                },
            },
        }).catch(e => console.error('[FCM] Group call error:', e));
    } else {
        if (!call.calleeId) return null;
        const calleeDoc = await admin.firestore().collection('users').doc(call.calleeId).get();
        if (!calleeDoc.exists) return null;

        const tokens = extractTokens(calleeDoc.data());
        if (tokens.length === 0) return null;

        await admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: {
                title: notifTitle,
                body: `${callerName} is calling you`,
            },
            data: {
                type: 'call',
                callId: String(callId),
                channelName: String(call.channelName || callId),
                callType: String(call.type || 'audio'),
                callerName: String(callerName),
                callerUserId: String(call.callerId),
                isGroup: 'false',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'ripple_calls',
                    sound: 'default',
                    priority: 'max',
                },
            },
        }).catch(e => console.error('[FCM] Single call error:', e));
    }
    return null;
});

// ═══════════════════════════════════════════════════════
// 4. Friend Request Received (v2)
// ═══════════════════════════════════════════════════════
exports.onFriendRequest = onDocumentUpdated({
    document: 'users/{userId}',
    region: 'us-central1',
}, async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};

    const beforeReceived = (before.friendRequests && before.friendRequests.received) || [];
    const afterReceived = (after.friendRequests && after.friendRequests.received) || [];

    if (afterReceived.length <= beforeReceived.length) return null;

    const newRequesterId = afterReceived.find(id => !beforeReceived.includes(id));
    if (!newRequesterId) return null;

    const notifSettings = after.notificationSettings || {};
    if (notifSettings.friendRequests === false) return null;

    const targetTokens = extractTokens(after);
    if (targetTokens.length === 0) return null;

    const requesterDoc = await admin.firestore().collection('users').doc(newRequesterId).get();
    const requesterName = requesterDoc.exists ? requesterDoc.data().name : 'Someone';

    try {
        await admin.messaging().sendEachForMulticast({
            tokens: targetTokens,
            notification: {
                title: 'New Friend Request 👋',
                body: `${requesterName} wants to connect with you`,
            },
            data: {
                type: 'friend_request',
                fromUid: String(newRequesterId),
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: { channelId: 'ripple_messages' },
            },
            webpush: {
                notification: {
                    title: 'New Friend Request 👋',
                    body: `${requesterName} wants to connect with you`,
                    icon: '/icons/Icon-192.png',
                },
            },
        });
    } catch (e) {
        console.error('[FCM] Friend request notification error:', e);
    }
    return null;
});

// ═══════════════════════════════════════════════════════
// 5. Delete group Cloud Function (v2 callable)
// ═══════════════════════════════════════════════════════
exports.deleteGroup = onCall({
    region: 'us-central1',
}, async (request) => {
    if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be logged in');
    }
    const groupId = request.data.groupId;
    if (!groupId) {
        throw new HttpsError('invalid-argument', 'groupId is required');
    }

    const groupRef = admin.firestore().collection('groups').doc(groupId);
    const messages = await groupRef.collection('messages').get();
    const batch = admin.firestore().batch();
    messages.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    await groupRef.delete();
    return { success: true };
});
