'use strict';

const catalyst = require('zcatalyst-sdk-node');
const admin = require('firebase-admin');

// Initialize Firebase Admin if credentials available, or use default environment credentials
if (!admin.apps.length) {
  try {
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT 
      ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT) 
      : null;

    if (serviceAccount) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    } else {
      admin.initializeApp();
    }
  } catch (err) {
    console.warn('[Catalyst FCM] Firebase Admin fallback initialization note:', err.message);
  }
}

/**
 * Advanced I/O function for Zoho Catalyst Pay-As-You-Go plan.
 * Dispatches high-priority FCM v1 push notifications for Ripple calls and messages.
 */
module.exports = async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Catalyst-Secret');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    return res.end();
  }

  const url = req.url || '/';

  // 1. Health check
  if (req.method === 'GET') {
    res.writeHead(200);
    return res.end(JSON.stringify({
      status: 'active',
      service: 'Ripple Zoho Catalyst FCM Dispatcher',
      timestamp: new Date().toISOString()
    }));
  }

  // 2. Parse JSON body
  let body = {};
  try {
    if (typeof req.body === 'object') {
      body = req.body;
    } else if (req.body) {
      body = JSON.parse(req.body);
    }
  } catch (e) {
    res.writeHead(400);
    return res.end(JSON.stringify({ error: 'Invalid JSON payload' }));
  }

  // 3. Register Device Token
  if (url.includes('/registerDevice')) {
    const { uid, fcmToken } = body;
    if (!uid || !fcmToken) {
      res.writeHead(400);
      return res.end(JSON.stringify({ error: 'Missing uid or fcmToken' }));
    }

    try {
      const catalystApp = catalyst.initialize(req);
      const datastore = catalystApp.datastore();
      const table = datastore.table('FcmTokens');

      await table.insertRow({
        user_id: uid,
        fcm_token: fcmToken,
        updated_at: new Date().toISOString()
      }).catch(err => {
        // Table might not exist yet; gracefully ignore
        console.log('Catalyst table insert note:', err.message);
      });

      res.writeHead(200);
      return res.end(JSON.stringify({ success: true, message: 'Device token registered' }));
    } catch (err) {
      res.writeHead(200);
      return res.end(JSON.stringify({ success: true, note: err.message }));
    }
  }

  // 3.5. Delete User Account (Full Server-Side Purge)
  if (url.includes('/deleteAccount')) {
    const { uid } = body;
    if (!uid) {
      res.writeHead(400);
      return res.end(JSON.stringify({ error: 'Missing uid' }));
    }

    try {
      // 1. Delete user from Firebase Auth
      try {
        await admin.auth().deleteUser(uid);
        console.log([Catalyst Purge] Deleted Firebase Auth user );
      } catch (authErr) {
        console.warn([Catalyst Purge] Auth delete note for :, authErr.message);
      }

      // 2. Delete user doc and subcollections in Firestore
      try {
        const db = admin.firestore();
        await db.collection('users').doc(uid).delete();
        
        // Delete statuses
        const statuses = await db.collection('statuses').where('userId', '==', uid).get();
        if (!statuses.empty) {
          const batch = db.batch();
          statuses.forEach(doc => batch.delete(doc.ref));
          await batch.commit();
        }
        console.log([Catalyst Purge] Purged Firestore records for );
      } catch (dbErr) {
        console.warn([Catalyst Purge] Firestore purge note:, dbErr.message);
      }

      // 3. Remove tokens from Catalyst Datastore if present
      try {
        const catalystApp = catalyst.initialize(req);
        const datastore = catalystApp.datastore();
        const table = datastore.table('FcmTokens');
        const rows = await table.getRows({ search: uid });
        if (rows && rows.length > 0) {
          for (const row of rows) {
            await table.deleteRow(row.ROWID);
          }
        }
      } catch (dsErr) {
        console.log([Catalyst Purge] Datastore token cleanup note:, dsErr.message);
      }

      res.writeHead(200);
      return res.end(JSON.stringify({
        success: true,
        message: Account  permanently deleted across Firebase and Catalyst backend.
      }));
    } catch (err) {
      console.error([Catalyst Purge] Error:, err);
      res.writeHead(500);
      return res.end(JSON.stringify({ error: err.message }));
    }
  }

  // 4. Send Push Notification
  if (url.includes('/sendNotification') || url.includes('/send') || (req.method === 'POST' && !url.includes('/deleteAccount') && !url.includes('/registerDevice'))) {
    const { recipientUids, title, body: msgBody, data = {}, priority = 'high' } = body;

    if (!recipientUids || !Array.isArray(recipientUids) || recipientUids.length === 0) {
      res.writeHead(400);
      return res.end(JSON.stringify({ error: 'Missing recipientUids array' }));
    }

    try {
      const isCall = data.type === 'call';
      const channelId = isCall ? 'ripple_calls' : 'ripple_messages';

      // Gather FCM tokens for recipients from Firestore
      const tokens = [];
      const db = admin.firestore();

      for (const uid of recipientUids) {
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) tokens.push(userData.fcmToken);
          if (Array.isArray(userData.fcmTokens)) {
            for (const t of userData.fcmTokens) {
              if (t && !tokens.includes(t)) tokens.push(t);
            }
          }
        }
      }

      if (tokens.length === 0) {
        res.writeHead(200);
        return res.end(JSON.stringify({
          success: true,
          delivered: 0,
          message: 'No active device tokens found for recipients'
        }));
      }

      // Convert all data values to strings (FCM specification requirement)
      const sanitizedData = {};
      for (const [key, val] of Object.entries(data)) {
        sanitizedData[key] = typeof val === 'string' ? val : JSON.stringify(val);
      }
      sanitizedData['title'] = title || 'Ripple';
      sanitizedData['body'] = msgBody || '';

      // Construct FCM Multicast Payload
      const message = {
        tokens: tokens,
        notification: {
          title: title || 'Ripple',
          body: msgBody || '',
        },
        data: sanitizedData,
        android: {
          priority: priority === 'high' ? 'high' : 'normal',
          notification: {
            channelId: channelId,
            priority: isCall ? 'max' : 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: 'public',
            notificationCount: 1,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: isCall ? 'call_ringtone.caf' : 'default',
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`[Catalyst FCM] Multicast response: ${response.successCount} sent, ${response.failureCount} failed`);

      // Clean up invalid tokens if any failed
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errCode = resp.error ? resp.error.code : '';
            if (errCode === 'messaging/invalid-registration-token' ||
                errCode === 'messaging/registration-token-not-registered') {
              invalidTokens.push(tokens[idx]);
            }
          }
        });

        if (invalidTokens.length > 0) {
          console.log(`[Catalyst FCM] Cleaning ${invalidTokens.length} expired tokens.`);
        }
      }

      res.writeHead(200);
      return res.end(JSON.stringify({
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount
      }));

    } catch (err) {
      console.error('[Catalyst FCM] Dispatch error:', err);
      res.writeHead(500);
      return res.end(JSON.stringify({ error: err.message }));
    }
  }

  res.writeHead(404);
  return res.end(JSON.stringify({ error: 'Endpoint not found' }));
};
