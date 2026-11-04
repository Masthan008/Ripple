// Firebase Cloud Messaging Background Service Worker for Ripple Web
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyA-ZlO7BMYxRy6hFdj0opbZIq1BtCoqN0o",
  authDomain: "ripple-cd77c.firebaseapp.com",
  projectId: "ripple-cd77c",
  storageBucket: "ripple-cd77c.firebasestorage.app",
  messagingSenderId: "965795380677",
  appId: "1:965795380677:web:ripple"
});

const messaging = firebase.messaging();

// Handle background notification delivery when Ripple Web tab is closed or in background
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background push: ', payload);

  const title = (payload.notification && payload.notification.title) || 
                (payload.data && payload.data.title) || 
                (payload.data && payload.data.senderName) || 
                'Ripple';

  const body = (payload.notification && payload.notification.body) || 
               (payload.data && payload.data.body) || 
               'New encrypted message';

  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
    actions: [
      { action: 'open', title: 'Open Ripple' }
    ]
  };

  return self.registration.showNotification(title, notificationOptions);
});

// Focus active tab or navigate when user clicks web notification
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  let targetUrl = '/';
  if (data.chatId) {
    targetUrl = `/#/chat/${data.chatId}`;
  } else if (data.groupId) {
    targetUrl = `/#/group/${data.groupId}`;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let client of windowClients) {
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          if ('navigate' in client && targetUrl !== '/') {
            client.navigate(targetUrl);
          }
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
