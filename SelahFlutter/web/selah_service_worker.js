/* Selah's small, dependency-free service worker. */
// Bump the build id when publishing a new Web bundle.  The registration also
// passes this value as a query string, so a new worker gets a new cache name
// while the old worker can finish any active recording before replacement.
const BUILD_ID = new URL(self.location.href).searchParams.get('v') || '2026-09-15-fixed-pose-gifs-v1';
const SHELL_CACHE = `selah-shell-${BUILD_ID}`;
const STATIC_CACHE = `selah-static-${BUILD_ID}`;
const INITIAL_POSES = [
  ...Array.from({ length: 10 }, (_, index) =>
    `./assets/assets/sprites/PlushV4S1A${String(index + 1).padStart(2, '0')}.png`),
  ...[2, 3, 4, 5].map((stage) => `./assets/assets/sprites/PlushV4S${stage}A01.png`),
];
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './selah_bridge.js',
  './selah_service_worker.js',
  './flutter.js',
  './flutter_bootstrap.js',
  './main.dart.js',
  './assets/AssetManifest.bin',
  './assets/AssetManifest.bin.json',
  './selah-precache.json',
  './assets/AssetManifest.json',
  './assets/FontManifest.json',
  './assets/NOTICES',
  './assets/assets/content/seed-sentences.json',
  './assets/assets/content/seed-audio.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './assets/assets/sprites/SeedBodyNeutral.png',
  './assets/assets/sprites/SeedBodyFloat.png',
  './assets/assets/sprites/SeedBodyListenComplete.png',
  './assets/assets/sprites/SeedBodyListenEnter.png',
  './assets/assets/sprites/SeedBodyListenPlaying.png',
  './assets/assets/sprites/SeedBodyQuizFail.png',
  './assets/assets/sprites/SeedBodyQuizGood.png',
  './assets/assets/sprites/SeedBodyRecDone.png',
  './assets/assets/sprites/SeedBodyRecRecording.png',
  './assets/assets/sprites/SeedEyesClosed.png',
  './assets/assets/sprites/SeedEyesSoft.png',
  // The release bootstrap uses dart2js + CanvasKit. Keep its default and
  // Chromium variants offline; revisit this list if the build enables Wasm
  // or experimental WebParagraph rendering.
  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
  './canvaskit/chromium/canvaskit.js',
  './canvaskit/chromium/canvaskit.wasm',
  './assets/shaders/ink_sparkle.frag',
  './assets/shaders/stretch_effect.frag',
  './version.json',
  ...INITIAL_POSES,
];

let seedAudioEntries;
async function loadSeedAudioEntries() {
  if (seedAudioEntries) return seedAudioEntries;
  const path = './assets/assets/content/seed-audio.json';
  const cache = await caches.open(SHELL_CACHE);
  const response = (await cache.match(path)) || await fetch(path, { cache: 'no-cache' });
  if (!response || !response.ok) throw new Error('Seed audio manifest unavailable');
  const manifest = await response.clone().json();
  const entries = new Map();
  for (const entry of Object.values(manifest)) {
    if (!entry || !/^assets\/audio\/seed-\d{3}-[a-z-]+\.mp3$/.test(entry.path) ||
        !/^[a-f0-9]{64}$/.test(entry.sha256) || !Number.isInteger(entry.byteSize) || entry.byteSize <= 0) continue;
    entries.set(new URL('./assets/' + entry.path, self.location.href).href, entry);
  }
  await cache.put(path, response);
  seedAudioEntries = entries;
  return entries;
}

async function validSeedAudio(request, response) {
  const url = new URL(typeof request === 'string' ? request : request.url, self.location.href);
  if (!/\/assets\/assets\/audio\/seed-[^/]+\.mp3$/.test(url.pathname)) return true;
  try {
    const entry = (await loadSeedAudioEntries()).get(url.href);
    if (!entry) return false;
    const bytes = await response.clone().arrayBuffer();
    if (bytes.byteLength !== entry.byteSize) return false;
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const hex = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
    return hex === entry.sha256;
  } catch (_) { return false; }
}

function shouldPrecacheAsset(asset) {
  const path = new URL(asset, self.location.href).pathname;
  const pose = /\/PlushV4S([1-5])A(0[1-9]|10)\.(png|gif)$/i.exec(path);
  return !pose || pose[1] === '1' || pose[2] === '01';
}

function isApiRequest(url) {
  const path = url.pathname.toLowerCase();
  const hasCredentialQuery = ['apikey', 'api_key', 'access_token', 'token', 'authorization', 'signature', 'expires']
    .some((name) => url.searchParams.has(name));
  return hasCredentialQuery ||
    path.startsWith('/auth/') || path.includes('/auth/v1/') ||
    path.startsWith('/rest/') || path.includes('/rest/v1/') ||
    path.startsWith('/functions/') || path.includes('/functions/v1/') ||
    path.startsWith('/storage/') || path.includes('/storage/v1/') ||
    path.startsWith('/realtime/') || path.includes('/realtime/v1/') ||
    path.includes('/graphql') ||
    path.startsWith('/api/') ||
    url.hostname.includes('supabase.co') ||
    url.hostname.includes('openai.com');
}

function isSameOriginStatic(request, url) {
  if (url.origin !== self.location.origin || request.method !== 'GET' || isApiRequest(url)) return false;
  if (url.pathname.startsWith('/__selah_audio/')) return false;
  const destination = request.destination || '';
  const path = url.pathname.toLowerCase();
  return destination === 'script' ||
    destination === 'style' ||
    destination === 'font' ||
    destination === 'image' ||
    destination === 'audio' ||
    destination === 'manifest' ||
    /\.(?:js|mjs|css|wasm|json|bin|frag|png|jpg|jpeg|gif|svg|webp|woff2?|ttf|otf|ico|mp3|m4a|ogg|wav)$/.test(path);
}

async function cacheNetworkResponse(cacheName, request) {
  const response = await fetch(request);
  if (response && response.ok && response.type !== 'opaque') {
    if (!await validSeedAudio(request, response)) throw new Error('Seed audio integrity mismatch');
    const cache = await caches.open(cacheName);
    await cache.put(request, response.clone());
  }
  return response;
}

async function precache(cache, asset) {
  try {
    const cached = await cache.match(asset);
    if (cached && await validSeedAudio(asset, cached)) return cached;
    if (cached) await cache.delete(asset);
    const response = await fetch(asset, { cache: 'no-cache' });
    if (response && response.ok && response.type !== 'opaque' && await validSeedAudio(asset, response)) {
      await cache.put(asset, response);
    }
    return response;
  } catch (_) {
    return null;
  }
}

async function precacheManifestAssets(cache, manifestUrl, extract) {
  try {
    const response = await fetch(manifestUrl, { cache: 'no-cache' });
    if (!response || !response.ok) return;
    const manifest = await response.json();
    // Later-stage actions enter the static cache when their stage is used.
    // Installing the app need not download all fifty full-resolution poses.
    const assets = extract(manifest).filter(shouldPrecacheAsset);
    await Promise.all(assets.map((asset) => precache(cache, asset)));
  } catch (_) {
    // The fixed shell list still provides a usable offline app when a build
    // omits an optional manifest.
  }
}

async function currentCacheMatch(request) {
  const [shell, staticCache] = await Promise.all([
    caches.open(SHELL_CACHE),
    caches.open(STATIC_CACHE),
  ]);
  const cacheRequest = typeof request === 'string'
    ? new Request(new URL(request, self.location.origin).href, { cache: 'no-store' }) : request;
  for (const cache of [shell, staticCache]) {
    const response = await cache.match(cacheRequest);
    if (!response) continue;
    if (await validSeedAudio(request, response)) return response;
    await cache.delete(cacheRequest);
  }
  return undefined;
}

self.addEventListener('install', (event) => {
  // Do not call skipWaiting here.  Applying an update is an explicit action
  // from the app so an in-progress recording or edit is never interrupted.
  event.waitUntil(
    caches.open(SHELL_CACHE).then(async (cache) => {
      for (const asset of SHELL) {
        await precache(cache, asset);
      }
      try {
        const audioEntries = await loadSeedAudioEntries();
        await Promise.all([...audioEntries.keys()].map((url) => precache(cache, url)));
      } catch (_) { /* An incomplete install can recover seed audio when online. */ }
      // Flutter's generated manifests contain package fonts and any custom
      // renderers that are not knowable in this source tree.  Read them only
      // during installation and cache same-origin assets listed there.
      await precacheManifestAssets(cache, './assets/FontManifest.json', (manifest) => {
        const paths = [];
        for (const family of Array.isArray(manifest) ? manifest : []) {
          for (const font of (family.fonts || [])) if (font && typeof font.asset === 'string') paths.push('./assets/' + font.asset.replace(/^\.?\//, ''));
        }
        return paths;
      });
      await precacheManifestAssets(cache, './assets/AssetManifest.json', (manifest) => {
        if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) return [];
        return Object.keys(manifest).map((asset) => './assets/' + asset.replace(/^\.?\//, ''));
      });
      await precacheManifestAssets(cache, './selah-precache.json', (manifest) => {
        if (!manifest || !Array.isArray(manifest.assets)) return [];
        return manifest.assets
          .filter((asset) => typeof asset === 'string')
          .map((asset) => asset.replace(/^\.?\//, './'));
      });
    }),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) => Promise.all(names
      .filter((name) => (name.startsWith('selah-shell-') || name.startsWith('selah-static-')) && name !== SHELL_CACHE && name !== STATIC_CACHE)
      .map((name) => caches.delete(name))))
      .then(() => self.clients && self.clients.claim ? self.clients.claim() : undefined),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || isApiRequest(url)) return;

  if (request.mode === 'navigate' || request.destination === 'document') {
    event.respondWith(
      fetch(request).then((response) => {
        if (response && response.ok) {
          return caches.open(SHELL_CACHE).then((cache) => {
            cache.put(request, response.clone());
            return response;
          });
        }
        return response;
      }).catch(() => currentCacheMatch(request).then((cached) => cached || currentCacheMatch('./index.html'))),
    );
    return;
  }

  if (!isSameOriginStatic(request, url)) return;
  event.respondWith(
    currentCacheMatch(request).then((cached) => cached || cacheNetworkResponse(STATIC_CACHE, request)),
  );
});

self.addEventListener('message', (event) => {
  if (event.data && (event.data.type === 'APPLY_UPDATE' || event.data.type === 'SKIP_WAITING')) {
    // This branch only runs after the user explicitly chooses to apply an
    // update from Settings.
    self.skipWaiting();
  }
});

self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {
    try { data = event.data ? { body: event.data.text() } : {}; } catch (__) {}
  }
  const title = typeof data.title === 'string' && data.title ? data.title : 'Selah';
  const body = typeof data.body === 'string' ? data.body : '';
  const options = { body, icon: './icons/icon-192.png', badge: './icons/icon-192.png' };
  if (typeof data.url === 'string') {
    try {
      const target = new URL(data.url, self.location.origin);
      if (target.origin === self.location.origin) options.data = { url: target.pathname + target.search + target.hash };
    } catch (_) {}
  }
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const path = event.notification.data && typeof event.notification.data.url === 'string'
    ? event.notification.data.url : './';
  let target = './';
  try {
    const parsed = new URL(path, self.location.origin);
    if (parsed.origin === self.location.origin) target = parsed.href;
  } catch (_) {}
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
    const sameOrigin = windows.find((client) => client.url && new URL(client.url).origin === self.location.origin);
    if (sameOrigin && 'focus' in sameOrigin) return sameOrigin.focus().then(() => sameOrigin.navigate(target));
    if (clients.openWindow) return clients.openWindow(target);
    return undefined;
  }));
});
