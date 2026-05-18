const CACHE = 'insulin-tracker-v5';
const CORE = [
  '/insulin-tracker/',
  '/insulin-tracker/index.html'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  if (e.request.url.includes('supabase.co')) {
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
    return;
  }
  if (e.request.destination === 'document') {
    e.respondWith(
      fetch(e.request).then(res => {
        const clone = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, clone));
        return res;
      }).catch(() => caches.match(e.request))
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});

// Notification action buttons: dismiss / snooze
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const action = e.action;                          // 'dismiss' | 'snooze' | ''
  const key    = e.notification.data && e.notification.data.key;

  // Relay action back to all open app windows
  if (action === 'dismiss' || action === 'snooze') {
    e.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
        list.forEach(c => c.postMessage({ type: 'notif-action', action, key }));
      })
    );
    return;
  }

  // Default: focus / open app
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) {
        if (c.url.includes('/insulin-tracker/') && 'focus' in c) return c.focus();
      }
      return clients.openWindow('/insulin-tracker/');
    })
  );
});
