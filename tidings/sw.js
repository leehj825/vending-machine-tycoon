// Service worker: keeps the game's files so it opens offline once it has been loaded over the web (http or https).
// Files are served from the cache straight away and refreshed in the background, so an update shows on the next open.
// (It does nothing when the game is opened by double-clicking index.html: browsers do not allow it there.)
const CACHE = 'tidings-v3';
const FILES = ['./', './index.html', './game.js', './characters.js', './models.js', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/icon.svg', './icons/apple-touch-icon.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => Promise.all(FILES.map((f) => c.add(f).catch(() => {})))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;
  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(req, { ignoreSearch: true });
      const fresh = fetch(req)
        .then((res) => {
          if (res.ok) cache.put(req, res.clone());
          return res;
        })
        .catch(() => cached);
      return cached || fresh;
    }),
  );
});

// Tapping a notification brings the game back.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => (list.length ? list[0].focus() : self.clients.openWindow('./index.html'))),
  );
});
