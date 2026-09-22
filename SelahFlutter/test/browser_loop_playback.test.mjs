import test from 'node:test';
import assert from 'node:assert/strict';
import bridgeModule from '../web/selah_bridge.js';

const { createBridge, helpers } = bridgeModule;

function createAudioClass(timers, { blocked = false } = {}) {
  class FakeAudio {
    static lastInstance;
    static instances = [];
    static playSources = [];
    constructor() {
      this.listeners = {};
      this.playbackRate = 1;
      this.src = '';
      FakeAudio.lastInstance = this;
      FakeAudio.instances.push(this);
    }
    addEventListener(name, handler) {
      (this.listeners[name] ||= []).push(handler);
    }
    removeEventListener(name, handler) {
      this.listeners[name] = (this.listeners[name] || []).filter((item) => item !== handler);
    }
    emit(name) {
      for (const handler of this.listeners[name] || []) handler({ type: name, target: this });
    }
    emitAsync(name) {
      this.emit(name);
    }
    async play() {
      FakeAudio.playSources.push(this.src);
      if (blocked) {
        const error = new Error('autoplay is not allowed');
        error.name = 'NotAllowedError';
        throw error;
      }
      timers.microtasks.push(() => this.emit('playing'));
    }
    pause() {
      timers.microtasks.push(() => this.emit('pause'));
    }
    removeAttribute() {}
    load() {}
  };
  return FakeAudio;
}

function makeEnvironment({ blocked = false } = {}) {
  const cache = helpers.createMemoryAudioCache();
  const timers = { timeouts: [], now: 100000, microtasks: [] };
  let activeTimerId = 0;
  const root = {
    Audio: createAudioClass(timers, { blocked }),
    navigator: {},
    URL: {
      createObjectURL: (() => {
        let id = 0;
        return () => `blob:audio-${++id}`;
      })(),
      revokeObjectURL() {},
    },
    fetch: async () => ({
      ok: true,
      headers: { get: () => 'audio/mpeg' },
      arrayBuffer: async () => new Uint8Array([1, 2, 3, 4]).buffer,
    }),
    setTimeout: (handler, delay) => {
      const id = ++activeTimerId;
      timers.timeouts.push({ id, handler, delay, fired: false });
      return id;
    },
    clearTimeout: (id) => {
      const item = timers.timeouts.find((timeout) => timeout.id === id);
      if (item) item.fired = true;
    },
    Date: class FakeDate extends Date {
      static now() { return timers.now; }
    },
  };
  const bridge = createBridge({ root, options: { audioCache: cache } });
  const call = (action, payload) => bridge(action, JSON.stringify({ accountId: 'guest', ...payload }));
  const flush = async () => {
    while (timers.microtasks.length) {
      const tasks = timers.microtasks.splice(0);
      for (const task of tasks) await task();
    }
  };
  const fireLatest = () => {
    const item = [...timers.timeouts].reverse().find((timeout) => !timeout.fired);
    if (item) { item.fired = true; item.handler(); return true; }
    return false;
  };
  const fireAndFlush = async (id) => {
    fire(id);
    await flush();
  };
  const tracks = [
    { sentenceId: 'a', role: 'target', language: 'en', key: 'a-target' },
    { sentenceId: 'a', role: 'source', language: 'zh-Hant', key: 'a-source' },
    { sentenceId: 'b', role: 'target', language: 'en', key: 'b-target' },
    { sentenceId: 'b', role: 'source', language: 'zh-Hant', key: 'b-source' },
  ];
  const settle = async () => {
    await flush();
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flush();
  };
  return { cache, timers, root, bridge, call, flush, fireLatest, settle, tracks, Audio: root.Audio };
}

test('loop playback follows target then source and continues to next sentence', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-1',
    order: 'targetFirst',
    durationMs: 15 * 60 * 1000,
    tracks: env.tracks,
    gapMs: { language: 10, sentence: 20 },
  });
  await env.flush();
  await new Promise((resolve) => setTimeout(resolve, 30));
  let status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-1' }));
  assert.equal(status.state, 'playing');
  assert.equal(status.phase, 'target');
  assert.equal(status.sentenceIndex, 0);

  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-1' }));
  assert.equal(status.phase, 'source');
  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-1' }));
  assert.equal(status.sentenceIndex, 1);
  assert.equal(status.phase, 'target');
  assert.equal(env.Audio.instances.length, 1, 'loop keeps one audio element for every track');
});

test('audio unlock primes the reusable loop element before the first track', async () => {
  const env = makeEnvironment();

  await env.call('audioUnlock');
  await env.flush();

  assert.equal(env.Audio.instances.length, 2);
  assert.match(env.Audio.playSources[0], /^data:audio\/wav;base64,/);

  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-unlocked',
    order: 'targetFirst',
    durationMs: 60000,
    tracks: env.tracks,
  });
  await env.flush();

  assert.equal(env.Audio.instances.length, 2);
});

test('loop playback exposes a retryable ready state when autoplay is blocked', async () => {
  const env = makeEnvironment({ blocked: true });
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }

  const result = JSON.parse(await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-autoplay',
    order: 'targetFirst',
    durationMs: 60000,
    tracks: env.tracks,
  }));

  assert.equal(result.state, 'ready');
  assert.equal(result.stopReason, 'autoplay_blocked');
});

test('source-first order and an order change apply from the next sentence', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-2',
    order: 'sourceFirst',
    durationMs: 60000,
    tracks: env.tracks,
    gapMs: { language: 0, sentence: 0 },
  });
  await env.flush();
  let status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-2' }));
  assert.equal(status.phase, 'source');
  await env.call('audioLoopOrder', { sessionId: 'session-2', order: 'targetFirst' });
  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-2' }));
  assert.equal(status.sentenceIndex, 0);
  assert.equal(status.phase, 'target');
  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-2' }));
  assert.equal(status.sentenceIndex, 1);
  assert.equal(status.phase, 'target');
});

test('pausing loop audio freezes remaining duration and extends deadline upon resume', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-3',
    order: 'targetFirst',
    durationMs: 60000,
    tracks: env.tracks,
  });
  await env.flush();
  env.timers.now = 101000;
  await env.call('audioLoopPause', { sessionId: 'session-3' });
  let status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-3' }));
  assert.equal(status.state, 'paused');
  assert.equal(status.remainingMs, 59000);
  env.timers.now = 170000;
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-3' }));
  assert.equal(status.state, 'paused');
  assert.equal(status.remainingMs, 59000);
  await env.call('audioLoopResume', { sessionId: 'session-3' });
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-3' }));
  assert.equal(status.state, 'playing');
  assert.equal(status.remainingMs, 59000);
});

test('audioSpeed updates active loop playback rate and persists for subsequent tracks', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-speed',
    order: 'targetFirst',
    durationMs: 60000,
    speed: 1.0,
    tracks: env.tracks,
  });
  await env.flush();
  assert.equal(env.root.Audio.lastInstance.playbackRate, 1.0);

  await env.call('audioSpeed', { speed: 1.5 });
  assert.equal(env.root.Audio.lastInstance.playbackRate, 1.5);
});

test('absolute deadline timer ends playback without a status poll', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-deadline',
    order: 'targetFirst',
    durationMs: 60000,
    tracks: env.tracks,
  });
  await env.flush();

  assert.equal(env.timers.timeouts.filter((timer) => !timer.fired).length, 1);
  env.timers.now += 60000;
  assert.equal(env.fireLatest(), true);
  await env.flush();

  const status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-deadline' }));
  assert.equal(status.state, 'ended');
  assert.equal(status.stopReason, 'timeout');
});

test('an order change while paused applies after the current sentence', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest',
    sessionId: 'session-paused-order',
    order: 'targetFirst',
    durationMs: 60000,
    tracks: env.tracks,
    gapMs: { language: 0, sentence: 0 },
  });
  await env.flush();
  await env.call('audioLoopPause', { sessionId: 'session-paused-order' });
  await env.call('audioLoopOrder', { sessionId: 'session-paused-order', order: 'sourceFirst' });
  let status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-paused-order' }));
  assert.equal(status.order, 'targetFirst');

  await env.call('audioLoopResume', { sessionId: 'session-paused-order' });
  await env.flush();
  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-paused-order' }));
  assert.equal(status.sentenceIndex, 0);
  assert.equal(status.phase, 'source');
  assert.equal(status.order, 'targetFirst');

  env.root.Audio.lastInstance?.emitAsync('ended');
  await env.flush();
  env.fireLatest();
  await env.settle();
  status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'session-paused-order' }));
  assert.equal(status.sentenceIndex, 1);
  assert.equal(status.phase, 'source');
  assert.equal(status.order, 'sourceFirst');
});

test('stale session controls cannot affect the active loop', async () => {
  const env = makeEnvironment();
  for (const track of env.tracks) {
    await env.call('audioEnsure', { accountId: 'guest', key: track.key, url: `https://example.test/${track.key}.mp3` });
  }
  await env.call('audioLoopStart', {
    accountId: 'guest', sessionId: 'old', order: 'targetFirst', durationMs: 60000, tracks: env.tracks,
  });
  await env.call('audioLoopStart', {
    accountId: 'guest', sessionId: 'new', order: 'targetFirst', durationMs: 60000, tracks: env.tracks,
  });
  await env.flush();
  await env.call('audioLoopPause', { sessionId: 'old' });
  const status = JSON.parse(await env.call('audioLoopStatus', { sessionId: 'new' }));
  assert.equal(status.state, 'playing');
  assert.equal(status.sessionId, 'new');
});
