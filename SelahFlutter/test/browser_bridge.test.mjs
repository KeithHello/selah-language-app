import test from 'node:test';
import assert from 'node:assert/strict';
import bridgeModule from '../web/selah_bridge.js';

const { createBridge, helpers } = bridgeModule;

test('bridge parses JSON payloads and returns JSON encoded results', async () => {
  const fakeRoot = {
    navigator: { onLine: true },
    addEventListener() {},
    removeEventListener() {},
    matchMedia: () => ({ matches: false }),
  };
  const bridge = createBridge({ root: fakeRoot });
  const result = await bridge('platformInfo', '{}');
  assert.deepEqual(JSON.parse(result), {
    online: true,
    visibilityState: 'visible',
    hidden: false,
    canRecord: false,
    canNotify: false,
    canPush: false,
    installed: false,
    canInstall: false,
    updateAvailable: false,
    storagePersisted: null,
    installKind: 'unsupported',
    buildId: 'dev',
  });
});

test('persistent storage returns existing permission without requesting again', async () => {
  let persistCalls = 0;
  const root = {
    navigator: {
      storage: {
        persisted: async () => true,
        persist: async () => { persistCalls += 1; return true; },
      },
    },
  };
  const bridge = createBridge({ root });
  assert.equal(JSON.parse(await bridge('platformInfo', '{}')).storagePersisted, true);
  assert.equal(await bridge('persistentStorage', '{}'), 'true');
  assert.equal(persistCalls, 0);
});

test('platform reports install state and build id from browser signals', async () => {
  const handlers = {};
  const root = {
    navigator: { userAgent: 'Mozilla/5.0 (X11; Linux x86_64)' },
    addEventListener: (name, handler) => { handlers[name] = handler; },
    matchMedia: () => ({ matches: false }),
    document: {
      querySelector: (selector) => selector === 'meta[name="selah-build-id"]'
        ? { content: 'build-42' } : null,
      visibilityState: 'visible',
    },
  };
  const bridge = createBridge({ root });
  handlers.beforeinstallprompt({ preventDefault() {}, prompt() {}, userChoice: Promise.resolve({ outcome: 'accepted' }) });
  const info = JSON.parse(await bridge('platformInfo', '{}'));
  assert.equal(info.installKind, 'prompt');
  assert.equal(info.canInstall, true);
  assert.equal(info.buildId, 'build-42');
});

test('platform distinguishes standalone and iOS manual installation', async () => {
  const standalone = createBridge({
    root: {
      navigator: { userAgent: 'desktop' },
      matchMedia: () => ({ matches: true }),
    },
  });
  const installed = JSON.parse(await standalone('platformInfo', '{}'));
  assert.equal(installed.installed, true);
  assert.equal(installed.installKind, 'installed');
  assert.equal(installed.canInstall, false);

  const ios = createBridge({
    root: {
      navigator: {
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)',
      },
      matchMedia: () => ({ matches: false }),
    },
  });
  const manual = JSON.parse(await ios('platformInfo', '{}'));
  assert.equal(manual.installKind, 'ios-manual');
  assert.equal(manual.canInstall, false);
});

test('checkUpdate reports unsupported, latest, and waiting states', async () => {
  const unsupported = createBridge({ root: { navigator: {} } });
  assert.equal(JSON.parse(await unsupported('checkUpdate', '{}')).status, 'unsupported');

  let updateCalls = 0;
  const registration = {
    waiting: null,
    update: async () => { updateCalls += 1; },
  };
  const latest = createBridge({
    root: { navigator: { serviceWorker: { getRegistration: async () => registration } } },
  });
  assert.equal(JSON.parse(await latest('checkUpdate', '{}')).status, 'latest');
  assert.equal(updateCalls, 1);
  const waiting = { postMessage() {} };
  registration.waiting = waiting;
  assert.equal(JSON.parse(await latest('checkUpdate', '{}')).status, 'available');
});

test('applyUpdate only posts to the waiting worker', async () => {
  let waitingMessages = 0;
  let activeMessages = 0;
  const registration = {
    waiting: { postMessage: () => { waitingMessages += 1; } },
    active: { postMessage: () => { activeMessages += 1; } },
  };
  const bridge = createBridge({
    root: { navigator: { serviceWorker: { getRegistration: async () => registration } } },
  });
  assert.equal(await bridge('applyUpdate', '{}'), 'true');
  assert.equal(waitingMessages, 1);
  assert.equal(activeMessages, 0);
});

test('bridge rejects malformed payloads and unknown actions with user safe errors', async () => {
  const bridge = createBridge({ root: { addEventListener() {}, navigator: {} } });
  await assert.rejects(() => bridge('platformInfo', '{'), /格式/);
  await assert.rejects(() => bridge('doesNotExist', '{}'), /不支持/);
});

test('recording mime selection prefers broadly supported webm, then mp4 and ogg', () => {
  const recorder = { isTypeSupported: (mime) => mime === 'audio/mp4' };
  assert.equal(helpers.chooseRecordingMime(recorder), 'audio/mp4');
  assert.equal(helpers.chooseRecordingMime({ isTypeSupported: () => false }), '');
});

test('audio cache keys include both account and content key', () => {
  const first = helpers.audioCacheKey('account-a', 'sentence-1');
  const second = helpers.audioCacheKey('account-b', 'sentence-1');
  const third = helpers.audioCacheKey('account-a', 'sentence-2');
  assert.notEqual(first, second);
  assert.notEqual(first, third);
  assert.equal(helpers.isSameOriginPath('https://example.com/app/'), false);
  assert.equal(helpers.isSameOriginPath('/app/main.dart.js'), true);
});

test('content hash gives audio a stable version without exposing the sentence', async () => {
  const { webcrypto } = await import('node:crypto');
  const bridge = createBridge({ root: { navigator: {}, crypto: webcrypto } });
  const hash = async (text) => JSON.parse(await bridge('contentHash', JSON.stringify({ text })));
  assert.equal(await hash('Hello.'), await hash('Hello.'));
  assert.notEqual(await hash('Hello.'), await hash('Hello!'));
  assert.match(await hash('你好。'), /^[0-9a-f]{64}$/);
});

test('platform reports waiting updates and notifications use the service worker', async () => {
  let notified = false;
  const registration = { waiting: { postMessage() {} }, showNotification: async () => { notified = true; } };
  const root = {
    navigator: { serviceWorker: { getRegistration: async () => registration } },
    Notification: Object.assign(function () { throw new Error('mobile constructor unsupported'); }, { permission: 'granted' }),
  };
  const bridge = createBridge({ root });
  const info = JSON.parse(await bridge('platformInfo', '{}'));
  assert.equal(info.updateAvailable, true);
  await bridge('notify', JSON.stringify({ title: 'Selah', body: '学习一句英文' }));
  assert.equal(notified, true);
});

test('save and load are JSON actions and preserve account isolation', async () => {
  const store = helpers.createMemorySnapshotStore();
  const bridge = createBridge({ root: { addEventListener() {}, navigator: {} }, snapshotStore: store });
  const snapshot = { format: 'selah-web', version: 1, sentences: [{ id: 's1' }] };
  assert.equal(await bridge('save', JSON.stringify({ accountId: 'a', snapshot })), 'null');
  assert.deepEqual(JSON.parse(await bridge('load', JSON.stringify({ accountId: 'a' }))), snapshot);
  assert.equal(JSON.parse(await bridge('load', JSON.stringify({ accountId: 'b' }))), null);
});

test('audio ensure caches bytes, verifies a supplied hash and reports cache size', async () => {
  const cache = helpers.createMemoryAudioCache();
  const bytes = new Uint8Array([1, 2, 3, 4]);
  const root = {
    addEventListener() {},
    navigator: {},
    fetch: async () => ({
      ok: true,
      headers: { get: () => 'audio/mpeg' },
      arrayBuffer: async () => bytes.buffer,
    }),
    crypto: { subtle: { digest: async () => new Uint8Array(32).buffer } },
  };
  const bridge = createBridge({ root, audioCache: cache });
  assert.deepEqual(JSON.parse(await bridge('audioEnsure', JSON.stringify({ accountId: 'a', key: 's1', url: 'https://cdn.example/s1.mp3' }))), { cached: true, bytes: 4 });
  assert.equal(JSON.parse(await bridge('audioCached', JSON.stringify({ accountId: 'a', key: 's1' }))), true);
  assert.deepEqual(JSON.parse(await bridge('audioCacheInfo', JSON.stringify({ accountId: 'a' }))), { count: 1, bytes: 4 });
});

test('audio play resolves after media starts and ended cleans the object URL', async () => {
  const cache = helpers.createMemoryAudioCache();
  let revoked = 0;
  let activeAudio;
  class FakeAudio {
    constructor() { this.listeners = {}; this.currentTime = 0; this.duration = 2; activeAudio = this; }
    addEventListener(name, handler) { (this.listeners[name] ??= []).push(handler); }
    removeEventListener(name, handler) { this.listeners[name] = (this.listeners[name] || []).filter((item) => item !== handler); }
    play() { (this.listeners.playing || []).forEach((handler) => handler()); return Promise.resolve(); }
    pause() {}
    load() {}
    removeAttribute() {}
    emit(name) { (this.listeners[name] || []).forEach((handler) => handler()); }
  }
  const bytes = new Uint8Array([9, 8]);
  const root = {
    location: { origin: 'https://app.example' },
    navigator: {},
    addEventListener() {},
    Audio: FakeAudio,
    Blob,
    Response,
    URL: { createObjectURL: () => 'blob:selah', revokeObjectURL: () => { revoked += 1; } },
    fetch: async () => ({ ok: true, headers: { get: () => 'audio/mpeg' }, arrayBuffer: async () => bytes.buffer }),
  };
  const bridge = createBridge({ root, audioCache: cache });
  await bridge('audioEnsure', JSON.stringify({ accountId: 'a', key: 'k', url: 'https://cdn.example/k.mp3' }));
  await bridge('audioPlay', JSON.stringify({ accountId: 'a', key: 'k', speed: 1 }));
  const status = JSON.parse(await bridge('audioStatus', '{}'));
  assert.equal(status.state, 'playing');
  activeAudio.currentTime = 2;
  activeAudio.emit('ended');
  const ended = JSON.parse(await bridge('audioStatus', '{}'));
  assert.equal(ended.state, 'ended');
  assert.equal(ended.durationMs, 2000);
  assert.equal(revoked, 1);
});

test('audio stop invalidates a pending play so it cannot resurrect the old account', async () => {
  const cache = helpers.createMemoryAudioCache();
  let resolveFetch;
  const root = {
    location: { origin: 'https://app.example' },
    navigator: {},
    addEventListener() {},
    fetch: () => new Promise((resolve) => { resolveFetch = resolve; }),
  };
  const bridge = createBridge({ root, audioCache: cache });
  const pending = bridge('audioPlay', JSON.stringify({ accountId: 'old', key: 'k', url: 'https://cdn.example/k.mp3' }));
  await new Promise((resolve) => setImmediate(resolve));
  await bridge('audioStop', '{}');
  resolveFetch({ ok: true, headers: { get: () => 'audio/mpeg' }, arrayBuffer: async () => new Uint8Array([1]).buffer });
  await assert.rejects(pending, /取消/);
  assert.equal(JSON.parse(await bridge('audioStatus', '{}')).state, 'idle');
});

test('recording stops tracks and returns a base64 blob', async () => {
  let stoppedTracks = 0;
  let activeRecorder;
  class FakeMediaRecorder {
    static isTypeSupported(mime) { return mime === 'audio/ogg'; }
    constructor(stream, options = {}) { this.stream = stream; this.mimeType = options.mimeType || 'audio/ogg'; activeRecorder = this; }
    start() { this.started = true; }
    stop() {
      this.ondataavailable({ data: new Blob(['abc'], { type: this.mimeType }) });
      this.onstop();
    }
  }
  const root = {
    addEventListener() {},
    navigator: {
      mediaDevices: { getUserMedia: async () => ({ getTracks: () => [{ stop: () => { stoppedTracks += 1; } }] }) },
    },
    MediaRecorder: FakeMediaRecorder,
    setTimeout: () => 1,
    clearTimeout: () => {},
  };
  const bridge = createBridge({ root });
  assert.deepEqual(JSON.parse(await bridge('recordStart', '{}')), { mimeType: 'audio/ogg' });
  assert.equal(JSON.parse(await bridge('recordingStatus', '{}')).recording, true);
  const result = JSON.parse(await bridge('recordStop', '{}'));
  assert.equal(result.base64, 'YWJj');
  assert.equal(result.mimeType, 'audio/ogg');
  assert.equal(stoppedTracks, 1);
  assert.equal(activeRecorder.started, true);
});

test('record cancel invalidates a pending microphone permission result', async () => {
  let resolveMedia;
  let stopped = 0;
  const root = {
    addEventListener() {},
    navigator: { mediaDevices: { getUserMedia: () => new Promise((resolve) => { resolveMedia = resolve; }) } },
    MediaRecorder: class {},
  };
  const bridge = createBridge({ root });
  const pending = bridge('recordStart', '{}');
  await new Promise((resolve) => setImmediate(resolve));
  await bridge('recordCancel', '{}');
  resolveMedia({ getTracks: () => [{ stop: () => { stopped += 1; } }] });
  await assert.rejects(pending, /取消/);
  assert.equal(stopped, 1);
  assert.deepEqual(JSON.parse(await bridge('recordingStatus', '{}')), { recording: false, durationMs: 0 });
});

test('service worker routes API requests out of the cache and includes offline assets', async () => {
  const source = await (await import('node:fs/promises')).readFile(new URL('../web/selah_service_worker.js', import.meta.url), 'utf8');
  assert.match(source, /function isApiRequest/);
  assert.match(source, /supabase\.co/);
  assert.match(source, /main\.dart\.js/);
  assert.match(source, /AssetManifest\.bin/);
  assert.match(source, /seed-audio\.json/);
  assert.match(source, /selah-precache\.json/);
  assert.match(source, /destination === 'audio'/);
  assert.match(source, /icons\/icon-192\.png/);
  assert.match(source, /self\.clients\.claim/);
  assert.match(source, /skipWaiting\(\)/);
  assert.match(source, /event\.data\.type === 'APPLY_UPDATE'/);
  assert.match(source, /async function currentCacheMatch/);
  assert.doesNotMatch(source, /caches\.match\(request\)/);

  const vm = await import('node:vm');
  const handlers = {};
  const staticCache = { match: async () => null, put: async () => {} };
  const sandbox = {
    URL,
    Promise,
    console,
    self: {
      location: new URL('https://app.example/'),
      addEventListener: (name, handler) => { handlers[name] = handler; },
      clients: {},
      registration: { showNotification: async () => {} },
      skipWaiting: () => {},
    },
    caches: {
      match: async () => null,
      open: async () => staticCache,
      keys: async () => [],
      delete: async () => true,
    },
    fetch: async () => ({ ok: true, type: 'basic', clone() { return this; } }),
  };
  vm.runInNewContext(source, sandbox);
  let apiResponded = false;
  handlers.fetch({
    request: { method: 'GET', url: 'https://project.supabase.co/rest/v1/sentences', mode: 'cors', destination: 'script' },
    respondWith: () => { apiResponded = true; },
  });
  assert.equal(apiResponded, false);
  let staticResponded = false;
  const staticEvent = {
    request: { method: 'GET', url: 'https://app.example/main.dart.js', mode: 'cors', destination: 'script' },
    respondWith: (promise) => { staticResponded = true; return promise; },
  };
  handlers.fetch(staticEvent);
  assert.equal(staticResponded, true);
  for (const path of ['assets/shaders/ink_sparkle.frag', 'assets/AssetManifest.bin']) {
    let cached = false;
    handlers.fetch({
      request: { method: 'GET', url: 'https://app.example/' + path, mode: 'cors', destination: '' },
      respondWith: (promise) => { cached = true; return promise; },
    });
    assert.equal(cached, true, 'offline Flutter resource: ' + path);
  }
});
