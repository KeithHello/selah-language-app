import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import { createHash, webcrypto } from 'node:crypto';

const source = await readFile(new URL('../web/selah_service_worker.js', import.meta.url), 'utf8');
const seedBytes = new Uint8Array([73, 68, 51, 1, 2, 3]);
const seedHash = createHash('sha256').update(seedBytes).digest('hex');
const seedVoices = [
  'gentle-natural',
  'clear-slow',
  'daily-bright',
  'elegant-british',
];
const activeSeedIds = ['001', '006', '027', '012', '016', '021', '004', '010', '030', '020'];
const seedAudio = Object.fromEntries(activeSeedIds.flatMap((number) => {
  const id = 'seed-' + number;
  return [
    ...seedVoices.map((voice) => [
      id + ':' + voice,
      { path: 'assets/audio/' + id + '-' + voice + '.mp3',
        sha256: seedHash, byteSize: seedBytes.length },
    ]),
    [
      id + ':source:zh-Hant',
      { path: 'assets/audio/' + id + '-source-zh-Hant.mp3',
        sha256: seedHash, byteSize: seedBytes.length },
    ],
    [
      id + ':source:ja',
      { path: 'assets/audio/' + id + '-source-ja.mp3',
        sha256: seedHash, byteSize: seedBytes.length },
    ],
  ];
}));
const posePaths = [];
for (let stage = 1; stage <= 5; stage += 1) {
  for (let action = 1; action <= 10; action += 1) {
    posePaths.push('assets/sprites/PlushV4S' + stage + 'A' + String(action).padStart(2, '0') + '.png');
  }
}

function worker({ manifests = true } = {}) {
  const base = 'https://app.example/';
  const handlers = {};
  const stores = new Map();
  const requests = [];
  const state = { offline: false, corruptSeed: false };
  const key = (request) => new URL(typeof request === 'string' ? request : request.url, base).href;
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map());
      const store = stores.get(name);
      return {
        match: async (request) => store.get(key(request)),
        put: async (request, response) => { store.set(key(request), response); },
        delete: async (request) => store.delete(key(request)),
      };
    },
    keys: async () => [...stores.keys()],
    delete: async (name) => stores.delete(name),
  };
  const fetch = async (request) => {
    const url = key(request);
    requests.push(url);
    if (state.offline) throw new Error('offline');
    const isManifest = /(?:AssetManifest|FontManifest|selah-precache).*json/.test(url);
    return {
      ok: !isManifest || manifests,
      type: 'basic',
      clone() { return this; },
      async arrayBuffer() {
        return (state.corruptSeed ? new Uint8Array([0, 0, 0]) : seedBytes).slice().buffer;
      },
      async json() {
        if (url.endsWith('/seed-audio.json')) return seedAudio;
        if (url.endsWith('/FontManifest.json')) return [{ fonts: [{ asset: 'assets/fonts/test.ttf' }] }];
        if (url.endsWith('/AssetManifest.json')) return Object.fromEntries(posePaths.map((p) => [p, [p]]));
        if (url.endsWith('/selah-precache.json')) return { assets: posePaths.map((p) => 'assets/' + p) };
        return {};
      },
    };
  };
  vm.runInNewContext(source, {
    URL, Request, Promise, console, caches, fetch, crypto: webcrypto,
    self: {
      location: new URL(base + 'selah_service_worker.js?v=poses-test'),
      addEventListener: (name, handler) => { handlers[name] = handler; },
      clients: {}, registration: {}, skipWaiting() {},
    },
  });
  return {
    requests, state, stores,
    async install() {
      let pending;
      handlers.install({ waitUntil(promise) { pending = promise; } });
      await pending;
    },
    async image(path) {
      let pending;
      handlers.fetch({
        request: { method: 'GET', url: base + path, mode: 'cors', destination: 'image' },
        respondWith(promise) { pending = promise; },
      });
      assert.ok(pending, 'image request is handled by the worker');
      return pending;
    },
  };
}

test('installation caches first-stage actions and each stage idle, without all future poses', async () => {
  const app = worker();
  await app.install();
  const poseRequests = app.requests.filter((url) => /PlushV4S/.test(url));
  const poses = new Set(poseRequests);
  assert.equal(poses.size, 14);
  assert.equal(poseRequests.length, 14, 'each initial pose is fetched only once');
  assert.ok([...poses].some((url) => url.endsWith('PlushV4S1A10.png')));
  assert.ok([...poses].some((url) => url.endsWith('PlushV4S5A01.png')));
  assert.ok(![...poses].some((url) => url.endsWith('PlushV4S5A09.png')));
  assert.ok(app.requests.some((url) => url.endsWith('/assets/assets/fonts/test.ttf')));
});

test('minimum offline pose set remains available when optional manifests are absent', async () => {
  const app = worker({ manifests: false });
  await app.install();
  const poses = new Set(app.requests.filter((url) => /PlushV4S/.test(url)));
  assert.equal(poses.size, 14);
});

test('installation keeps both supported CanvasKit variants without downloading inactive renderers', async () => {
  const app = worker();
  await app.install();
  const renderers = app.requests.filter((url) => url.includes('/canvaskit/'));
  assert.deepEqual(renderers.map((url) => new URL(url).pathname).sort(), [
    '/canvaskit/canvaskit.js',
    '/canvaskit/canvaskit.wasm',
    '/canvaskit/chromium/canvaskit.js',
    '/canvaskit/chromium/canvaskit.wasm',
  ]);
  app.state.offline = true;
  for (const url of renderers) {
    assert.equal((await app.image(new URL(url).pathname.slice(1))).ok, true);
  }
});

test('future-stage poses are cached when requested and remain readable offline', async () => {
  const app = worker();
  const path = 'assets/assets/sprites/PlushV4S5A09.png';
  const online = await app.image(path);
  assert.equal(online.ok, true);
  app.state.offline = true;
  const offline = await app.image(path);
  assert.equal(offline.ok, true);
  assert.equal(app.requests.filter((url) => url.endsWith('PlushV4S5A09.png')).length, 1);
});

test('all 60 active starter audios are installed and readable offline', async () => {
  const app = worker();
  await app.install();
  app.state.offline = true;
  for (const entry of Object.values(seedAudio)) {
    assert.equal((await app.image('assets/' + entry.path)).ok, true);
  }
  const audioRequests = app.requests.filter((url) => /seed-\d{3}-(?:gentle-natural|clear-slow|daily-bright|elegant-british|source-zh-Hant|source-ja)\.mp3$/.test(url));
  assert.equal(new Set(audioRequests).size, 60);
  assert.equal(audioRequests.length, 60, 'each file is fetched once during install');
});

test('corrupt seed response is excluded from cache and recovered on the next online request', async () => {
  const app = worker();
  app.state.corruptSeed = true;
  await app.install();
  const path = 'assets/assets/audio/seed-001-gentle-natural.mp3';
  assert.ok([...app.stores.values()].every((store) => !store.has('https://app.example/' + path)));
  app.state.corruptSeed = false;
  assert.equal((await app.image(path)).ok, true);
  app.state.offline = true;
  assert.equal((await app.image(path)).ok, true);
});
