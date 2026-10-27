// Service worker: precaches every app file and the catalogue so the app works offline.
// All paths are relative so the app works under /Telestronomy/ (or any sub-path).
const CACHE = 'telestronomy-v1';
const PRECACHE = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './data/objects.json',
  './js/app.js',
  './js/astro.js',
  './js/catalogue.js',
  './js/location.js',
  './js/camera.js',
  './js/alignment.js',
  './js/starfinder.js',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
];
// Endpoints of the camera bridge (when the PWA is served by the bridge itself): never cached.
const BRIDGE_PATHS = ['/status', '/stream.mjpeg', '/capture', '/settings', '/solve'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  if (BRIDGE_PATHS.some((p) => url.pathname.endsWith(p))) return;
  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then((cached) => {
      const refresh = fetch(req).then((res) => {
        if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
        return res;
      });
      if (cached) { refresh.catch(() => {}); return cached; }
      return refresh.catch(() => (req.mode === 'navigate' ? caches.match('./index.html') : Response.error()));
    })
  );
});
