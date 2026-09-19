/*
 * Browser boundary for the Flutter Web client.
 *
 * The Dart side talks to exactly one function:
 *   globalThis.selahBridge(action, JSON.stringify(payload))
 *
 * This file intentionally uses browser primitives only.  It is also a small
 * CommonJS module so the contract can be checked with Node's built in test
 * runner without adding a JavaScript dependency to the Flutter project.
 */
(function installSelahBridge(globalObject, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  // Node imports this file for the contract tests.  Install the global entry
  // point only when the object looks like a browser window; constructing an
  // IndexedDB store at module load would otherwise fail in Node.
  if (globalObject && (globalObject.document || globalObject.window === globalObject)) {
    var bridge = api.createBridge({ root: globalObject });
    globalObject.selahBridge = bridge;
    globalObject.selahBridgeHelpers = api.helpers;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function makeApi() {
  'use strict';

  var DB_NAME = 'selah-web';
  var DB_VERSION = 1;
  var SNAPSHOT_STORE = 'snapshots';
  var AUDIO_CACHE = 'selah-audio-v1';
  var RECORDING_LIMIT_MS = 180000;
  var BACKUP_LIMIT_BYTES = 10 * 1024 * 1024;
  var AUDIO_PREFIX = '/__selah_audio/';

  function safeError(message, cause) {
    var error = new Error(message);
    error.name = 'SelahBridgeError';
    if (cause) error.cause = cause;
    return error;
  }

  function jsonResult(value) {
    return JSON.stringify(value === undefined ? null : value);
  }

  function parsePayload(payloadJson) {
    if (payloadJson === undefined || payloadJson === null || payloadJson === '') return {};
    if (typeof payloadJson !== 'string') {
      throw safeError('请求格式无效。');
    }
    try {
      var payload = JSON.parse(payloadJson);
      if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
        throw new Error('payload must be an object');
      }
      return payload;
    } catch (error) {
      if (error && error.name === 'SelahBridgeError') throw error;
      throw safeError('请求格式无效。', error);
    }
  }

  function requiredString(payload, name) {
    var value = payload && payload[name];
    if (typeof value !== 'string' || value.trim() === '') {
      throw safeError('缺少有效的' + name + '。');
    }
    return value.trim();
  }

  function optionalString(payload, name) {
    var value = payload && payload[name];
    if (value === undefined || value === null || value === '') return undefined;
    if (typeof value !== 'string') throw safeError(name + '格式无效。');
    return value;
  }

  function toNumber(value, fallback) {
    if (value === undefined || value === null || value === '') return fallback;
    var number = Number(value);
    return Number.isFinite(number) ? number : fallback;
  }

  function encodePart(value) {
    return encodeURIComponent(String(value)).replace(/%2F/gi, '%252F');
  }

  function originFor(root) {
    var location = root && root.location;
    return location && location.origin ? location.origin : 'https://selah.invalid';
  }

  function audioCacheKey(accountId, key, root) {
    return originFor(root || (typeof globalThis !== 'undefined' ? globalThis : {})) +
      AUDIO_PREFIX + encodePart(accountId) + '/' + encodePart(key);
  }

  function isSameOriginPath(url, root) {
    if (typeof url !== 'string' || url.length === 0) return false;
    if (url.charAt(0) === '/') return true;
    try {
      var parsed = new URL(url, originFor(root || {}));
      return parsed.origin === originFor(root || {});
    } catch (_) {
      return false;
    }
  }

  function chooseRecordingMime(recorder) {
    if (!recorder || typeof recorder.isTypeSupported !== 'function') return '';
    var candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/ogg;codecs=opus',
      'audio/ogg',
    ];
    for (var i = 0; i < candidates.length; i += 1) {
      try {
        if (recorder.isTypeSupported(candidates[i])) return candidates[i];
      } catch (_) {
        // A browser may throw for a MIME it does not know. Try the next one.
      }
    }
    return '';
  }

  function createMemorySnapshotStore() {
    var values = new Map();
    return {
      load: function (accountId) {
        return Promise.resolve(values.has(accountId) ? values.get(accountId) : null);
      },
      save: function (accountId, snapshot) {
        values.set(accountId, snapshot);
        return Promise.resolve(null);
      },
    };
  }

  function createIndexedDbSnapshotStore(root) {
    var indexedDB = root && root.indexedDB;
    if (!indexedDB || typeof indexedDB.open !== 'function') {
      throw safeError('当前浏览器不支持本地学习数据。');
    }
    function open() {
      return new Promise(function (resolve, reject) {
        var request;
        try {
          request = indexedDB.open(DB_NAME, DB_VERSION);
        } catch (error) {
          reject(safeError('本地学习数据无法打开。', error));
          return;
        }
        request.onupgradeneeded = function () {
          var database = request.result;
          if (!database.objectStoreNames.contains(SNAPSHOT_STORE)) {
            database.createObjectStore(SNAPSHOT_STORE, { keyPath: 'accountId' });
          }
        };
        request.onsuccess = function () { resolve(request.result); };
        request.onerror = function () { reject(safeError('本地学习数据无法打开。', request.error)); };
        request.onblocked = function () { reject(safeError('本地学习数据仍在其他页面使用。')); };
      });
    }
    return {
      load: function (accountId) {
        return open().then(function (database) {
          return new Promise(function (resolve, reject) {
            var transaction = database.transaction(SNAPSHOT_STORE, 'readonly');
            var request = transaction.objectStore(SNAPSHOT_STORE).get(accountId);
            request.onsuccess = function () {
              var record = request.result;
              resolve(record ? record.snapshot : null);
              database.close();
            };
            request.onerror = function () {
              reject(safeError('本地学习数据无法读取。', request.error));
              database.close();
            };
          });
        });
      },
      save: function (accountId, snapshot) {
        return open().then(function (database) {
          return new Promise(function (resolve, reject) {
            var transaction;
            try {
              transaction = database.transaction(SNAPSHOT_STORE, 'readwrite');
              transaction.objectStore(SNAPSHOT_STORE).put({
                accountId: accountId,
                snapshot: snapshot,
                savedAt: new Date().toISOString(),
              });
            } catch (error) {
              database.close();
              reject(safeError('本地学习数据无法保存。', error));
              return;
            }
            transaction.oncomplete = function () {
              database.close();
              resolve(null);
            };
            transaction.onerror = function () {
              database.close();
              reject(safeError('本地学习数据无法保存。', transaction.error));
            };
            transaction.onabort = function () {
              database.close();
              reject(safeError('本地学习数据保存已取消。', transaction.error));
            };
          });
        });
      },
    };
  }

  function createUnavailableSnapshotStore() {
    return {
      load: function () { return Promise.reject(safeError('当前浏览器不支持本地学习数据。')); },
      save: function () { return Promise.reject(safeError('当前浏览器不支持本地学习数据。')); },
    };
  }

  function createMemoryAudioCache() {
    var values = new Map();
    return {
      match: function (key) {
        var response = values.get(key) || null;
        return Promise.resolve(response && typeof response.clone === 'function' ? response.clone() : response);
      },
      put: function (key, response) { values.set(key, response); return Promise.resolve(); },
      delete: function (key) { return Promise.resolve(values.delete(key)); },
      keys: function () { return Promise.resolve(Array.from(values.keys()).map(function (url) { return { url: url }; })); },
    };
  }

  function responseBytes(response) {
    if (!response) return Promise.resolve(null);
    if (typeof response.arrayBuffer === 'function') return response.arrayBuffer();
    if (response.bytes && response.bytes instanceof Uint8Array) return Promise.resolve(response.bytes.buffer);
    return Promise.reject(safeError('音频缓存格式无效。'));
  }

  function makeResponse(root, bytes, contentType) {
    var ResponseCtor = root && root.Response;
    if (typeof ResponseCtor !== 'function' && typeof Response === 'function') ResponseCtor = Response;
    if (typeof ResponseCtor === 'function') {
      return new ResponseCtor(bytes, { status: 200, headers: { 'Content-Type': contentType || 'audio/mpeg' } });
    }
    return {
      bytes: bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes),
      headers: { get: function () { return contentType || 'audio/mpeg'; } },
      arrayBuffer: function () { return Promise.resolve(this.bytes.buffer); },
      blob: function () { return Promise.resolve(new Blob([this.bytes], { type: contentType || 'audio/mpeg' })); },
    };
  }

  function getAudioCache(root, provided) {
    if (provided) return Promise.resolve(provided);
    if (root && root.caches && typeof root.caches.open === 'function') {
      return root.caches.open(AUDIO_CACHE);
    }
    return Promise.resolve(createMemoryAudioCache());
  }

  function digestSha256(root, bytes) {
    var cryptoObject = root && root.crypto;
    if (!cryptoObject && typeof crypto !== 'undefined') cryptoObject = crypto;
    if (!cryptoObject || !cryptoObject.subtle || typeof cryptoObject.subtle.digest !== 'function') {
      return Promise.reject(safeError('当前浏览器不支持音频校验。'));
    }
    return cryptoObject.subtle.digest('SHA-256', bytes).then(function (digest) {
      var array = new Uint8Array(digest);
      var hex = '';
      for (var i = 0; i < array.length; i += 1) hex += array[i].toString(16).padStart(2, '0');
      return hex;
    });
  }

  function normaliseHash(hash) {
    return String(hash || '').trim().toLowerCase().replace(/^sha-256:/, '');
  }

  function fetchAudio(root, url) {
    var fetcher = root && root.fetch;
    if (typeof fetcher !== 'function' && typeof fetch === 'function') fetcher = fetch;
    if (typeof fetcher !== 'function') return Promise.reject(safeError('当前浏览器无法下载音频。'));
    return Promise.resolve(fetcher.call(root, url, { cache: 'no-store' })).then(function (response) {
      if (!response || response.ok === false) {
        throw safeError('音频下载失败。');
      }
      return response;
    }).catch(function (error) {
      if (error && error.name === 'SelahBridgeError') throw error;
      throw safeError('音频下载失败。', error);
    });
  }

  function cacheAudio(root, payload, providedCache) {
    var accountId = requiredString(payload, 'accountId');
    var key = requiredString(payload, 'key');
    var url = optionalString(payload, 'url');
    var expectedHash = normaliseHash(optionalString(payload, 'sha256'));
    var cacheKey = audioCacheKey(accountId, key, root);
    return getAudioCache(root, providedCache).then(function (cache) {
      return Promise.resolve(cache.match(cacheKey)).then(function (cached) {
        if (cached) {
          return responseBytes(cached).then(function (bytes) {
            if (!expectedHash) return { cache: cache, bytes: bytes };
            return digestSha256(root, bytes).then(function (hash) {
              if (hash === expectedHash) return { cache: cache, bytes: bytes };
              return Promise.resolve(cache.delete(cacheKey)).then(function () { return null; });
            });
          });
        }
        return null;
      }).then(function (hit) {
        if (hit) return hit;
        if (!url) throw safeError('音频缓存不存在，请先联网获取。');
        return fetchAudio(root, url).then(function (response) {
          return responseBytes(response).then(function (bytes) {
            if (expectedHash) {
              return digestSha256(root, bytes).then(function (hash) {
                if (hash !== expectedHash) throw safeError('音频校验失败，请重试。');
                return bytes;
              });
            }
            return bytes;
          }).then(function (bytes) {
            var contentType = response.headers && typeof response.headers.get === 'function'
              ? response.headers.get('Content-Type') : 'audio/mpeg';
            return Promise.resolve(cache.put(cacheKey, makeResponse(root, bytes, contentType))).then(function () {
              return { cache: cache, bytes: bytes };
            });
          });
        });
      }).then(function (result) {
        return { cached: true, bytes: result.bytes.byteLength || result.bytes.length || 0 };
      });
    }).catch(function (error) {
      if (error && error.name === 'SelahBridgeError') throw error;
      throw safeError('音频缓存失败。', error);
    });
  }

  function responseBlob(root, response, contentType) {
    if (response && typeof response.blob === 'function') return response.blob();
    return responseBytes(response).then(function (bytes) {
      var BlobCtor = root && root.Blob;
      if (typeof BlobCtor !== 'function' && typeof Blob === 'function') BlobCtor = Blob;
      if (typeof BlobCtor !== 'function') throw safeError('当前浏览器无法载入音频。');
      return new BlobCtor([bytes], { type: contentType || 'audio/mpeg' });
    });
  }

  function makeAudioController(root, providedCache) {
    var state = {
      state: 'idle', key: null, positionMs: 0, durationMs: 0, error: undefined,
      element: null, objectUrl: null, listeners: [], speed: 1,
      operation: 0,
    };

    function setState(next, error) {
      state.state = next;
      if (error) state.error = String(error.message || error);
      else if (next !== 'error') state.error = undefined;
      if (state.element) {
        state.positionMs = Math.max(0, Math.round((Number(state.element.currentTime) || 0) * 1000));
        state.durationMs = Number.isFinite(Number(state.element.duration))
          ? Math.max(0, Math.round(Number(state.element.duration) * 1000)) : state.durationMs;
      }
    }

    function removeListeners() {
      if (!state.element) return;
      for (var i = 0; i < state.listeners.length; i += 1) {
        var item = state.listeners[i];
        if (typeof state.element.removeEventListener === 'function') {
          state.element.removeEventListener(item.name, item.handler);
        }
      }
      state.listeners = [];
    }

    function cleanup(resetKey, preserveMetrics) {
      removeListeners();
      if (state.element) {
        try { state.element.pause(); } catch (_) {}
        try { state.element.removeAttribute('src'); } catch (_) {}
        try { state.element.load(); } catch (_) {}
      }
      if (state.objectUrl && root.URL && typeof root.URL.revokeObjectURL === 'function') {
        try { root.URL.revokeObjectURL(state.objectUrl); } catch (_) {}
      }
      state.element = null;
      state.objectUrl = null;
      if (!preserveMetrics) {
        state.positionMs = 0;
        state.durationMs = 0;
      }
      if (resetKey) state.key = null;
    }

    function createAudioElement() {
      var AudioCtor = root && root.Audio;
      if (typeof AudioCtor === 'function') return new AudioCtor();
      if (root && root.document && typeof root.document.createElement === 'function') {
        return root.document.createElement('audio');
      }
      throw safeError('当前浏览器不支持音频播放。');
    }

    function add(name, handler) {
      if (state.element && typeof state.element.addEventListener === 'function') {
        state.element.addEventListener(name, handler);
        state.listeners.push({ name: name, handler: handler });
      }
    }

    function play(payload) {
      var accountId = requiredString(payload, 'accountId');
      var key = requiredString(payload, 'key');
      var url = optionalString(payload, 'url');
      var speed = Math.min(2, Math.max(0.5, toNumber(payload.speed, state.speed || 1)));
      var operation = state.operation + 1;
      state.operation = operation;
      state.speed = speed;
      return cacheAudio(root, payload, providedCache).then(function () {
        if (operation !== state.operation) throw safeError('音频播放已取消。');
        return getAudioCache(root, providedCache).then(function (cache) {
          if (operation !== state.operation) throw safeError('音频播放已取消。');
          return Promise.resolve(cache.match(audioCacheKey(accountId, key, root))).then(function (response) {
            if (operation !== state.operation) throw safeError('音频播放已取消。');
            if (!response) throw safeError('音频缓存不存在，请先联网获取。');
            return response;
          });
        });
      }).then(function (response) {
        if (operation !== state.operation) throw safeError('音频播放已取消。');
        if (!response) throw safeError('音频播放已取消。');
        cleanup(false);
        state.key = key;
        state.state = 'loading';
        return responseBlob(root, response).then(function (blob) {
          if (operation !== state.operation) throw safeError('音频播放已取消。');
          var URLCtor = root && root.URL;
          if (URLCtor && typeof URLCtor.createObjectURL === 'function') {
            state.objectUrl = URLCtor.createObjectURL(blob);
          } else if (url) {
            state.objectUrl = url;
          } else {
            throw safeError('当前浏览器无法载入音频。');
          }
          state.element = createAudioElement();
          if (operation !== state.operation) {
            cleanup(false);
            throw safeError('音频播放已取消。');
          }
          state.element.src = state.objectUrl;
          state.element.playbackRate = speed;
          add('loadedmetadata', function () { setState(state.state); });
          add('timeupdate', function () { setState(state.state); });
          add('playing', function () { setState('playing'); });
          add('pause', function () {
            if (state.state !== 'ended' && state.state !== 'idle') setState('paused');
          });
          add('ended', function () {
            setState('ended');
            // Keep the final position and duration visible in audioStatus while
            // releasing the Blob URL and event listeners.
            cleanup(false, true);
          });
          add('error', function () {
            setState('error', safeError('音频播放失败。'));
            cleanup(false, true);
          });
          var result = state.element.play();
          if (result && typeof result.then === 'function') {
            return result.then(function () {
              if (operation !== state.operation) throw safeError('音频播放已取消。');
              setState('playing');
              return null;
            });
          }
          if (operation === state.operation) setState('playing');
          return null;
        });
      }).catch(function (error) {
        if (operation !== state.operation) throw safeError('音频播放已取消。');
        setState('error', error);
        cleanup(false, true);
        if (error && error.name === 'SelahBridgeError') throw error;
        throw safeError('音频播放失败。', error);
      });
    }

    function pause() {
      if (!state.element) return null;
      try { state.element.pause(); } catch (error) { throw safeError('音频暂停失败。', error); }
      setState('paused');
      return null;
    }

    function resume() {
      if (!state.element) return null;
      var result;
      try { result = state.element.play(); } catch (error) { throw safeError('音频播放失败。', error); }
      if (result && typeof result.then === 'function') {
        return result.then(function () { setState('playing'); return null; }).catch(function (error) {
          setState('error', error); throw safeError('音频播放失败。', error);
        });
      }
      setState('playing');
      return null;
    }

    function stop() {
      state.operation += 1;
      cleanup(true);
      setState('idle');
      return null;
    }

    function seek(payload) {
      var positionMs = Math.max(0, toNumber(payload.positionMs, 0));
      if (state.element) {
        var duration = Number(state.element.duration);
        if (Number.isFinite(duration) && duration >= 0) positionMs = Math.min(positionMs, Math.round(duration * 1000));
        try { state.element.currentTime = positionMs / 1000; } catch (error) { throw safeError('音频跳转失败。', error); }
      }
      state.positionMs = positionMs;
      return null;
    }

    function speed(payload) {
      var next = Math.min(2, Math.max(0.5, toNumber(payload.speed, 1)));
      state.speed = next;
      if (state.element) state.element.playbackRate = next;
      return null;
    }

    function status() {
      if (state.element) {
        state.positionMs = Math.max(0, Math.round((Number(state.element.currentTime) || 0) * 1000));
        if (Number.isFinite(Number(state.element.duration))) state.durationMs = Math.max(0, Math.round(Number(state.element.duration) * 1000));
      }
      var result = { state: state.state, key: state.key, positionMs: state.positionMs, durationMs: state.durationMs };
      if (state.error) result.error = state.error;
      return result;
    }

    return { play: play, pause: pause, resume: resume, stop: stop, seek: seek, speed: speed, status: status };
  }

  function makeRecorderController(root) {
    var state = {
      recording: false, recorder: null, stream: null, chunks: [], mimeType: '', startedAt: 0,
      durationMs: 0, blob: null, timer: null, stopPromise: null, resolveStop: null, rejectStop: null,
      stopRequested: false, cancelled: false,
      operation: 0,
    };

    function now() {
      var performanceObject = root && root.performance;
      if (performanceObject && typeof performanceObject.now === 'function') return performanceObject.now();
      return Date.now();
    }

    function clearTimer() {
      if (state.timer !== null) {
        var clear = root && root.clearTimeout;
        if (typeof clear !== 'function' && typeof clearTimeout === 'function') clear = clearTimeout;
        if (typeof clear === 'function') clear.call(root, state.timer);
      }
      state.timer = null;
    }

    function releaseTracks() {
      if (state.stream && typeof state.stream.getTracks === 'function') {
        var tracks = state.stream.getTracks();
        for (var i = 0; i < tracks.length; i += 1) {
          try { tracks[i].stop(); } catch (_) {}
        }
      }
      state.stream = null;
    }

    function finish(blob, error) {
      clearTimer();
      releaseTracks();
      state.recording = false;
      state.durationMs = Math.min(RECORDING_LIMIT_MS, Math.max(0, Math.round(now() - state.startedAt)));
      if (!state.cancelled && blob && typeof blob.arrayBuffer === 'function') state.blob = blob;
      state.recorder = null;
      var resolve = state.resolveStop;
      var reject = state.rejectStop;
      state.resolveStop = null;
      state.rejectStop = null;
      if (error) {
        state.stopPromise = null;
        if (reject) reject(error);
      } else if (resolve && !state.cancelled) {
        resolve(state.blob);
      }
      if (state.cancelled) state.blob = null;
    }

    function start() {
      if (state.recording) throw safeError('已经在录音中。');
      var navigatorObject = root && root.navigator;
      var MediaRecorderCtor = root && root.MediaRecorder;
      if (!navigatorObject || !navigatorObject.mediaDevices || typeof navigatorObject.mediaDevices.getUserMedia !== 'function' || typeof MediaRecorderCtor !== 'function') {
        throw safeError('当前浏览器不支持录音。');
      }
      state.blob = null;
      state.chunks = [];
      state.durationMs = 0;
      state.cancelled = false;
      state.stopRequested = false;
      var operation = state.operation + 1;
      state.operation = operation;
      return Promise.resolve().then(function () {
        return navigatorObject.mediaDevices.getUserMedia({ audio: true });
      }).then(function (stream) {
        if (operation !== state.operation) {
          if (stream && typeof stream.getTracks === 'function') stream.getTracks().forEach(function (track) { try { track.stop(); } catch (_) {} });
          throw safeError('录音已取消。');
        }
        state.stream = stream;
        state.mimeType = chooseRecordingMime(MediaRecorderCtor);
        var recorder;
        try {
          recorder = state.mimeType ? new MediaRecorderCtor(stream, { mimeType: state.mimeType }) : new MediaRecorderCtor(stream);
        } catch (error) {
          releaseTracks();
          throw safeError('当前浏览器无法开始录音。', error);
        }
        state.recorder = recorder;
        state.mimeType = recorder.mimeType || state.mimeType || 'audio/webm';
        state.startedAt = now();
        state.recording = true;
        state.stopPromise = new Promise(function (resolve, reject) {
          state.resolveStop = resolve;
          state.rejectStop = reject;
        });
        recorder.ondataavailable = function (event) {
          if (event && event.data && event.data.size > 0) state.chunks.push(event.data);
        };
        recorder.onerror = function (event) {
          finish(null, safeError('录音发生错误。', event && event.error));
        };
        recorder.onstop = function () {
          var BlobCtor = root && root.Blob;
          if (typeof BlobCtor !== 'function' && typeof Blob === 'function') BlobCtor = Blob;
          try {
            var blob = BlobCtor ? new BlobCtor(state.chunks, { type: state.mimeType }) : null;
            if (!blob) throw safeError('录音数据为空。');
            finish(blob);
          } catch (error) {
            finish(null, safeError('录音数据无法保存。', error));
          }
        };
        try {
          recorder.start();
        } catch (error) {
          finish(null, safeError('当前浏览器无法开始录音。', error));
          throw safeError('当前浏览器无法开始录音。', error);
        }
        var set = root && root.setTimeout;
        if (typeof set !== 'function' && typeof setTimeout === 'function') set = setTimeout;
        if (typeof set === 'function') {
          state.timer = set.call(root, function () {
            if (state.recording && state.recorder) {
              state.stopRequested = true;
              try { state.recorder.stop(); } catch (error) { finish(null, safeError('录音停止失败。', error)); }
            }
          }, RECORDING_LIMIT_MS);
        }
        return { mimeType: state.mimeType };
      }).catch(function (error) {
        if (operation !== state.operation) throw safeError('录音已取消。');
        if (error && error.name === 'SelahBridgeError') throw error;
        releaseTracks();
        throw safeError('无法使用麦克风，请检查权限。', error);
      });
    }

    function blobToBase64(blob) {
      return blob.arrayBuffer().then(function (buffer) {
        var bytes = new Uint8Array(buffer);
        var binary = '';
        var chunkSize = 0x8000;
        for (var i = 0; i < bytes.length; i += chunkSize) {
          var chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
          binary += String.fromCharCode.apply(null, chunk);
        }
        var btoaFunction = root && root.btoa;
        if (typeof btoaFunction !== 'function' && typeof btoa === 'function') btoaFunction = btoa;
        if (typeof btoaFunction === 'function') return btoaFunction(binary);
        if (typeof Buffer !== 'undefined') return Buffer.from(bytes).toString('base64');
        throw safeError('录音数据无法编码。');
      });
    }

    function stop() {
      if (!state.recording) {
        if (!state.blob) throw safeError('没有可提交的录音。');
        var existing = state.blob;
        state.blob = null;
        return blobToBase64(existing).then(function (base64) {
          return { base64: base64, mimeType: state.mimeType, durationMs: state.durationMs };
        });
      }
      var promise = state.stopPromise;
      if (!state.stopRequested) {
        state.stopRequested = true;
        try { state.recorder.stop(); } catch (error) {
          finish(null, safeError('录音停止失败。', error));
        }
      }
      return promise.then(function (blob) {
        if (!blob || typeof blob.arrayBuffer !== 'function') throw safeError('录音数据为空。');
        return blobToBase64(blob).then(function (base64) {
          state.blob = null;
          state.stopPromise = null;
          return { base64: base64, mimeType: state.mimeType, durationMs: state.durationMs };
        });
      });
    }

    function cancel() {
      state.operation += 1;
      clearTimer();
      if (state.recording && state.recorder) {
        state.cancelled = true;
        state.stopRequested = true;
        try { state.recorder.stop(); } catch (_) { releaseTracks(); }
        // Stopping tracks is safe before MediaRecorder's asynchronous stop
        // event and guarantees the microphone is released on every cancel path.
        releaseTracks();
      } else {
        releaseTracks();
      }
      state.blob = null;
      state.chunks = [];
      state.recording = false;
      state.recorder = null;
      state.stopPromise = null;
      state.resolveStop = null;
      state.rejectStop = null;
      return null;
    }

    function status() {
      var duration = state.recording ? Math.min(RECORDING_LIMIT_MS, Math.max(0, Math.round(now() - state.startedAt))) : state.durationMs;
      return { recording: state.recording, durationMs: duration };
    }

    return { start: start, stop: stop, cancel: cancel, status: status };
  }

  function makeLoopAudioController(root, providedCache) {
    var active = null;
    var pendingTimerIds = [];
    var deadlineTimerId = null;

    function nowMs() {
      var DateCtor = root && root.Date ? root.Date : Date;
      return DateCtor.now();
    }

    function setTimer(handler, delay) {
      var set = root && root.setTimeout;
      if (typeof set !== 'function' && typeof setTimeout === 'function') set = setTimeout;
      if (typeof set !== 'function') return null;
      var id;
      function wrapped() {
        var expiredId = id;
        handler();
      }
      id = set.call(root, wrapped, Math.max(0, delay || 0));
      pendingTimerIds.push(id);
      return id;
    }

    function clearAdvanceTimers() {
      var clear = root && root.clearTimeout;
      if (typeof clear !== 'function' && typeof clearTimeout === 'function') clear = clearTimeout;
      if (typeof clear === 'function') {
        pendingTimerIds.forEach(function (id) { if (id != null) clear.call(root, id); });
      }
      pendingTimerIds = [];
    }

    function clearDeadlineTimer() {
      var clear = root && root.clearTimeout;
      if (typeof clear !== 'function' && typeof clearTimeout === 'function') clear = clearTimeout;
      if (deadlineTimerId != null && typeof clear === 'function') clear.call(root, deadlineTimerId);
      deadlineTimerId = null;
    }

    function clearTimers() {
      clearAdvanceTimers();
      clearDeadlineTimer();
    }

    function armDeadline(session) {
      if (!session || session.deadlineAtMs == null || deadlineTimerId != null) return;
      var remaining = session.deadlineAtMs - nowMs();
      if (remaining <= 0) {
        finish('timeout');
        return;
      }
      var set = root && root.setTimeout;
      if (typeof set !== 'function' && typeof setTimeout === 'function') set = setTimeout;
      if (typeof set !== 'function') return;
      deadlineTimerId = set.call(root, function () {
        deadlineTimerId = null;
        if (active !== session) return;
        finish('timeout');
      }, Math.max(0, remaining));
    }

    function cleanupElement(session) {
      if (!session || !session.element) return;
      var element = session.element;
      if (typeof element.removeEventListener === 'function') {
        (session.listeners || []).forEach(function (item) {
          element.removeEventListener(item.name, item.handler);
        });
      }
      try { element.pause(); } catch (_) {}
      try { element.removeAttribute('src'); } catch (_) {}
      try { element.load(); } catch (_) {}
      if (session.objectUrl && root.URL && typeof root.URL.revokeObjectURL === 'function') {
        try { root.URL.revokeObjectURL(session.objectUrl); } catch (_) {}
      }
      session.element = null;
      session.objectUrl = null;
      session.listeners = [];
    }

    function createAudioElement() {
      var AudioCtor = root && root.Audio;
      if (typeof AudioCtor === 'function') return new AudioCtor();
      if (root && root.document && typeof root.document.createElement === 'function') {
        return root.document.createElement('audio');
      }
      throw safeError('当前浏览器不支持音频播放。');
    }

    function addListener(session, name, handler) {
      if (session.element && typeof session.element.addEventListener === 'function') {
        session.element.addEventListener(name, handler);
        session.listeners.push({ name: name, handler: handler });
      }
    }

    function idleStatus() {
      return {
        sessionId: null, state: 'idle', phase: null, sentenceIndex: 0, sentenceCount: 0,
        remainingMs: 0, deadlineAtMs: null, order: 'targetFirst', stopReason: null,
      };
    }

    function orderedTracks(item, order) {
      return order === 'sourceFirst' ? [item.source, item.target] : [item.target, item.source];
    }

    function validateStart(payload) {
      var accountId = requiredString(payload, 'accountId');
      var sessionId = requiredString(payload, 'sessionId');
      var order = payload.order === 'sourceFirst' ? 'sourceFirst' : 'targetFirst';
      var durationMs = toNumber(payload.durationMs, 0);
      if (!Number.isFinite(durationMs) || durationMs < 1 || durationMs > 12 * 60 * 60 * 1000) {
        throw safeError('循环听时长无效。');
      }
      if (!Array.isArray(payload.tracks) || payload.tracks.length === 0) {
        throw safeError('循环听缺少音频。');
      }
      var bySentence = new Map();
      var orderIndex = 0;
      payload.tracks.forEach(function (track) {
        if (!track || typeof track !== 'object') throw safeError('循环听音频无效。');
        var sentenceId = requiredString(track, 'sentenceId');
        var role = track.role === 'source' ? 'source' : (track.role === 'target' ? 'target' : '');
        if (!role) throw safeError('循环听音频语言无效。');
        var key = requiredString(track, 'key');
        if (!bySentence.has(sentenceId)) {
          bySentence.set(sentenceId, {
            sentenceId: sentenceId,
            orderIndex: orderIndex += 1,
            target: null,
            source: null,
          });
        }
        var item = bySentence.get(sentenceId);
        if (item[role]) throw safeError('循环听音频重复。');
        item[role] = { sentenceId: sentenceId, role: role, key: key };
      });
      var items = Array.from(bySentence.values()).sort(function (a, b) {
        return a.orderIndex - b.orderIndex;
      });
      if (items.some(function (item) { return !item.target || !item.source; })) {
        throw safeError('循环听需要中英双语音频。');
      }
      return {
        accountId: accountId,
        sessionId: sessionId,
        order: order,
        durationMs: durationMs,
        items: items,
        languageGapMs: toNumber(payload.gapMs && payload.gapMs.language, 1000),
        sentenceGapMs: toNumber(payload.gapMs && payload.gapMs.sentence, 2000),
        speed: Math.min(2, Math.max(0.5, toNumber(payload.speed, 1))),
      };
    }

    function snapshot() {
      if (!active) return idleStatus();
      var remaining = active.deadlineAtMs == null
        ? active.durationMs
        : Math.max(0, active.deadlineAtMs - nowMs());
      return {
        sessionId: active.sessionId,
        state: active.state,
        phase: active.phase,
        sentenceIndex: active.itemIndex,
        sentenceCount: active.items.length,
        remainingMs: remaining,
        deadlineAtMs: active.deadlineAtMs,
        order: active.order,
        stopReason: active.stopReason,
      };
    }

    function finish(reason) {
      if (!active) return;
      clearTimers();
      cleanupElement(active);
      active.state = 'ended';
      active.phase = null;
      active.remainingMs = 0;
      active.deadlineAtMs = active.deadlineAtMs || nowMs();
      active.stopReason = reason;
    }

    function isCurrent(payload, session) {
      var expected = session || active;
      return !!expected && !!payload && payload.sessionId === expected.sessionId &&
        payload.accountId === expected.accountId;
    }

    function currentTrack(session) {
      var item = session.items[session.itemIndex];
      return orderedTracks(item, session.order)[session.trackIndex];
    }

    function playTrack() {
      var session = active;
      if (!session) return Promise.resolve(null);
      if (session.deadlineAtMs != null && session.deadlineAtMs <= nowMs()) {
        finish('timeout');
        return Promise.resolve(null);
      }
      var track = currentTrack(session);
      session.phase = track.role;
      session.state = 'playing';
      cleanupElement(session);
      return getAudioCache(root, providedCache).then(function (cache) {
        if (active !== session) return null;
        var key = audioCacheKey(session.accountId, track.key, root);
        return Promise.resolve(cache.match(key)).then(function (response) {
          if (!response) throw safeError('音频缓存不存在，请先联网获取。');
          return responseBlob(root, response, 'audio/mpeg');
        }).then(function (blob) {
          if (active !== session) return null;
          var URLCtor = root && root.URL;
          if (URLCtor && typeof URLCtor.createObjectURL === 'function') {
            session.objectUrl = URLCtor.createObjectURL(blob);
          } else {
            throw safeError('当前浏览器无法载入音频。');
          }
          session.element = createAudioElement();
          session.element.src = session.objectUrl;
          session.element.playbackRate = session.speed;
          addListener(session, 'playing', function () {
            if (active !== session) return;
            if (session.deadlineAtMs == null) {
              session.deadlineAtMs = nowMs() + session.durationMs;
              armDeadline(session);
            } else {
              armDeadline(session);
            }
            session.state = 'playing';
          });
          addListener(session, 'ended', function () {
            if (active !== session || session.phase !== track.role) return;
            cleanupElement(session);
            onTrackEnded(session);
          });
          addListener(session, 'error', function () {
            if (active !== session) return;
            session.state = 'error';
            session.stopReason = 'audio_error';
            cleanupElement(session);
          });
          var result = session.element.play();
          if (result && typeof result.then === 'function') return result.then(function () { return null; });
          return null;
        });
      }).catch(function (error) {
        if (active === session) {
          cleanupElement(session);
          var errorName = String(error && error.name || '').toLowerCase();
          var errorMessage = String(error && (error.message || error) || '').toLowerCase();
          if (errorName === 'notallowederror' || errorMessage.indexOf('autoplay') >= 0 || errorMessage.indexOf('not allowed') >= 0) {
            session.state = 'ready';
            session.stopReason = 'autoplay_blocked';
            return snapshot();
          }
          session.state = 'error';
          session.stopReason = 'audio_error';
        }
        if (error && error.name === 'SelahBridgeError') throw error;
        throw safeError('音频播放失败。', error);
      });
    }

    function scheduleAdvance(session, delay) {
      if (session.deadlineAtMs != null) {
        var remaining = session.deadlineAtMs - nowMs();
        if (remaining <= 0) {
          finish('timeout');
          return;
        }
        delay = Math.min(delay, remaining);
      }
      session.state = 'gap';
      session.gapStartedAtMs = nowMs();
      session.gapRemainingMs = delay;
      setTimer(function () {
        if (active !== session) return;
        if (session.deadlineAtMs != null && session.deadlineAtMs <= nowMs()) {
          finish('timeout');
          return;
        }
        session.gapStartedAtMs = null;
        session.gapRemainingMs = null;
        playTrack();
      }, delay);
    }

    function onTrackEnded(session) {
      if (session.trackIndex === 0) {
        session.trackIndex = 1;
        scheduleAdvance(session, session.languageGapMs);
        return;
      }
      session.trackIndex = 0;
      session.itemIndex = (session.itemIndex + 1) % session.items.length;
      if (session.pendingOrder) {
        session.order = session.pendingOrder;
        session.pendingOrder = null;
      }
      scheduleAdvance(session, session.sentenceGapMs);
    }

    function start(payload) {
      var config = validateStart(payload);
      if (active) {
        clearTimers();
        cleanupElement(active);
      }
      active = {
        accountId: config.accountId,
        sessionId: config.sessionId,
        items: config.items,
        order: config.order,
        pendingOrder: null,
        itemIndex: 0,
        trackIndex: 0,
        phase: null,
        state: 'starting',
        durationMs: config.durationMs,
        deadlineAtMs: null,
        stopReason: null,
        languageGapMs: config.languageGapMs,
        sentenceGapMs: config.sentenceGapMs,
        gapRemainingMs: null,
        gapStartedAtMs: null,
        speed: config.speed,
        element: null,
        objectUrl: null,
        listeners: [],
      };
      return playTrack();
    }

    function pause(payload) {
      if (!active || !isCurrent(payload)) return snapshot();
      clearAdvanceTimers();
      if (active.deadlineAtMs != null && active.deadlineAtMs <= nowMs()) {
        finish('timeout');
        return snapshot();
      }
      active.state = 'paused';
      if (active.gapStartedAtMs != null && active.gapRemainingMs != null) {
        active.gapRemainingMs = Math.max(
          0,
          active.gapRemainingMs - (nowMs() - active.gapStartedAtMs),
        );
      }
      if (active.element) {
        try { active.element.pause(); } catch (_) {}
      }
      return snapshot();
    }

    function resume(payload) {
      if (!active || !isCurrent(payload)) return Promise.resolve(snapshot());
      if (active.deadlineAtMs != null && active.deadlineAtMs <= nowMs()) {
        finish('timeout');
        return Promise.resolve(snapshot());
      }
      if (active.element) {
        active.state = 'playing';
        try {
          var result = active.element.play();
          if (result && typeof result.then === 'function') return result.then(function () { return snapshot(); });
        } catch (error) {
          active.state = 'error';
          active.stopReason = 'audio_error';
          throw safeError('音频播放失败。', error);
        }
        return Promise.resolve(snapshot());
      }
      if (active.gapRemainingMs != null) {
        active.state = 'gap';
        scheduleAdvance(active, active.gapRemainingMs);
        return Promise.resolve(snapshot());
      }
      return playTrack().then(function () { return snapshot(); });
    }

    function next(payload) {
      if (!active || !isCurrent(payload)) return Promise.resolve(snapshot());
      if (active.deadlineAtMs != null && active.deadlineAtMs <= nowMs()) {
        finish('timeout');
        return Promise.resolve(snapshot());
      }
      clearAdvanceTimers();
      active.trackIndex = 0;
      active.itemIndex = (active.itemIndex + 1) % active.items.length;
      if (active.pendingOrder) {
        active.order = active.pendingOrder;
        active.pendingOrder = null;
      }
      return playTrack().then(function () { return snapshot(); });
    }

    function setOrder(payload) {
      if (!active || !isCurrent(payload)) return snapshot();
      var order = payload.order === 'sourceFirst' ? 'sourceFirst' : 'targetFirst';
      if (active.state === 'paused' &&
          active.gapRemainingMs != null &&
          active.trackIndex === 0) {
        active.order = order;
        active.pendingOrder = null;
      } else if (active.state === 'paused') {
        active.pendingOrder = order;
      } else if (active.trackIndex === 0 && active.state === 'gap') {
        active.order = order;
      } else {
        active.pendingOrder = order;
      }
      return snapshot();
    }

    function stop(payload) {
      if (active && (!payload || !payload.sessionId || isCurrent(payload))) finish('user');
      return snapshot();
    }

    return {
      start: start,
      pause: pause,
      resume: resume,
      next: next,
      setOrder: setOrder,
      stop: stop,
      status: function (payload) {
        if (payload && payload.sessionId && active && !isCurrent(payload)) return idleStatus();
        if (active && active.deadlineAtMs != null && active.deadlineAtMs <= nowMs() &&
            active.state !== 'ended') {
          finish('timeout');
        }
        return snapshot();
      },
    };
  }

  function base64UrlToBytes(value) {
    var normalized = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
    while (normalized.length % 4) normalized += '=';
    var binary;
    if (typeof atob === 'function') binary = atob(normalized);
    else if (typeof Buffer !== 'undefined') binary = Buffer.from(normalized, 'base64').toString('binary');
    else throw safeError('当前浏览器无法订阅提醒。');
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  function serviceWorkerRegistration(root) {
    var navigatorObject = root && root.navigator;
    if (!navigatorObject || !navigatorObject.serviceWorker) {
      throw safeError('当前浏览器不支持推送提醒。');
    }
    if (navigatorObject.serviceWorker.ready) return Promise.resolve(navigatorObject.serviceWorker.ready);
    if (typeof navigatorObject.serviceWorker.getRegistration === 'function') {
      return Promise.resolve(navigatorObject.serviceWorker.getRegistration()).then(function (registration) {
        if (!registration) throw safeError('当前浏览器不支持推送提醒。');
        return registration;
      });
    }
    throw safeError('当前浏览器不支持推送提醒。');
  }

  function createBridge(options) {
    options = options || {};
    var root = options.root || (typeof globalThis !== 'undefined' ? globalThis : {});
    var snapshotStore = options.snapshotStore || (root && root.indexedDB
      ? createIndexedDbSnapshotStore(root)
      : createUnavailableSnapshotStore());
    var providedAudioCache = options.audioCache || (!(root && root.caches) ? createMemoryAudioCache() : null);
    var audio = makeAudioController(root, providedAudioCache);
    var loopAudio = makeLoopAudioController(root, providedAudioCache);
    var recorder = makeRecorderController(root);
    var deferredInstallPrompt = null;
    var updateWaiting = null;
    var unloadProtection = false;

    function addListener(name, handler) {
      if (root && typeof root.addEventListener === 'function') root.addEventListener(name, handler);
    }
    addListener('beforeunload', function (event) {
      if (!unloadProtection || !event) return;
      if (typeof event.preventDefault === 'function') event.preventDefault();
      event.returnValue = '';
    });
    addListener('beforeinstallprompt', function (event) {
      if (event && typeof event.preventDefault === 'function') event.preventDefault();
      deferredInstallPrompt = event;
    });
    addListener('appinstalled', function () { deferredInstallPrompt = null; });
    if (root && root.navigator && root.navigator.serviceWorker && typeof root.navigator.serviceWorker.addEventListener === 'function') {
      root.navigator.serviceWorker.addEventListener('message', function (event) {
        if (event && event.data && event.data.type === 'UPDATE_WAITING') updateWaiting = event.data;
      });
    }

    function load(payload) {
      return snapshotStore.load(requiredString(payload, 'accountId'));
    }

    function save(payload) {
      var accountId = requiredString(payload, 'accountId');
      if (!Object.prototype.hasOwnProperty.call(payload, 'snapshot')) throw safeError('缺少学习数据。');
      var snapshot = payload.snapshot;
      if (!snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) throw safeError('学习数据格式无效。');
      return snapshotStore.save(accountId, snapshot);
    }

    function downloadBackup(payload) {
      var filename = requiredString(payload, 'filename');
      var text = payload.text;
      if (typeof text !== 'string') throw safeError('备份内容格式无效。');
      var documentObject = root && root.document;
      var BlobCtor = root && root.Blob;
      if (!documentObject || typeof documentObject.createElement !== 'function' || typeof BlobCtor !== 'function') {
        throw safeError('当前浏览器不支持备份下载。');
      }
      var blob = new BlobCtor([text], { type: 'application/json;charset=utf-8' });
      var URLCtor = root.URL;
      if (!URLCtor || typeof URLCtor.createObjectURL !== 'function') throw safeError('当前浏览器不支持备份下载。');
      var url = URLCtor.createObjectURL(blob);
      var anchor = documentObject.createElement('a');
      anchor.href = url;
      anchor.download = filename;
      anchor.rel = 'noopener';
      if (typeof anchor.click === 'function') anchor.click();
      var revoke = root.setTimeout || (typeof setTimeout === 'function' ? setTimeout : null);
      if (revoke) revoke.call(root, function () { try { URLCtor.revokeObjectURL(url); } catch (_) {} }, 0);
      return null;
    }

    function importBackup() {
      var documentObject = root && root.document;
      if (!documentObject || typeof documentObject.createElement !== 'function') throw safeError('当前浏览器不支持备份导入。');
      return new Promise(function (resolve, reject) {
        var input = documentObject.createElement('input');
        input.type = 'file';
        input.accept = 'application/json,.json';
        input.style.display = 'none';
        var finished = false;
        var focusHandler = function () {
          var set = root && root.setTimeout;
          if (typeof set !== 'function' && typeof setTimeout === 'function') set = setTimeout;
          if (typeof set === 'function') set.call(root, function () {
            if (!finished && (!input.files || input.files.length === 0)) done(resolve, null);
          }, 0);
        };
        function done(callback, value) {
          if (finished) return;
          finished = true;
          if (root && typeof root.removeEventListener === 'function') root.removeEventListener('focus', focusHandler);
          if (input.parentNode && typeof input.parentNode.removeChild === 'function') input.parentNode.removeChild(input);
          callback(value);
        }
        input.onchange = function () {
          var file = input.files && input.files[0];
          if (!file) return done(resolve, null);
          if (file.size > BACKUP_LIMIT_BYTES) return done(reject, safeError('备份文件不能超过 10MB。'));
          var read = typeof file.text === 'function' ? file.text() : new Promise(function (res, rej) {
            var Reader = root.FileReader;
            if (typeof Reader !== 'function') return rej(safeError('当前浏览器无法读取备份。'));
            var reader = new Reader();
            reader.onload = function () { res(reader.result); };
            reader.onerror = function () { rej(reader.error); };
            reader.readAsText(file);
          });
          Promise.resolve(read).then(function (text) {
            var BlobCtor = root && root.Blob;
            if (typeof BlobCtor !== 'function' && typeof Blob === 'function') BlobCtor = Blob;
            if (typeof text !== 'string') throw safeError('备份文件无法读取。');
            if (BlobCtor && new BlobCtor([text]).size > BACKUP_LIMIT_BYTES) throw safeError('备份文件不能超过 10MB。');
            done(resolve, text);
          }).catch(function (error) { done(reject, error && error.name === 'SelahBridgeError' ? error : safeError('备份文件无法读取。', error)); });
        };
        input.oncancel = function () { done(resolve, null); };
        if (root && typeof root.addEventListener === 'function') root.addEventListener('focus', focusHandler);
        if (documentObject.body && typeof documentObject.body.appendChild === 'function') documentObject.body.appendChild(input);
        if (typeof input.click !== 'function') return done(reject, safeError('当前浏览器不支持备份导入。'));
        input.click();
      });
    }

    async function platformInfo() {
      var navigatorObject = root && root.navigator ? root.navigator : {};
      var documentObject = root && root.document;
      var displayStandalone = false;
      if (root && typeof root.matchMedia === 'function') {
        try { displayStandalone = root.matchMedia('(display-mode: standalone)').matches; } catch (_) {}
      }
      var installed = displayStandalone || navigatorObject.standalone === true;
      var canRecord = typeof root.MediaRecorder === 'function' && !!(navigatorObject.mediaDevices && typeof navigatorObject.mediaDevices.getUserMedia === 'function');
      var canNotify = typeof root.Notification === 'function';
      var canPush = !!(navigatorObject.serviceWorker && root.PushManager);
      var storagePersisted = await readStoragePersisted(navigatorObject);
      var registration = null;
      if (navigatorObject.serviceWorker && navigatorObject.serviceWorker.getRegistration) {
        try { registration = await navigatorObject.serviceWorker.getRegistration(); } catch (_) {}
      }
      var kind = installKind(navigatorObject, installed);
      return {
        online: navigatorObject.onLine !== false,
        visibilityState: documentObject && documentObject.visibilityState
          ? documentObject.visibilityState
          : 'visible',
        hidden: !!(documentObject && documentObject.hidden),
        canRecord: canRecord,
        canNotify: canNotify,
        canPush: canPush,
        installed: installed,
        canInstall: kind === 'prompt',
        updateAvailable: !!((registration && registration.waiting) || updateWaiting),
        storagePersisted: storagePersisted,
        installKind: kind,
        buildId: buildId(),
      };
    }

    function buildId() {
      var documentObject = root && root.document;
      if (documentObject && typeof documentObject.querySelector === 'function') {
        try {
          var meta = documentObject.querySelector('meta[name="selah-build-id"]');
          if (meta && typeof meta.content === 'string' && meta.content.trim()) return meta.content.trim();
        } catch (_) {}
      }
      return 'dev';
    }

    function isIos(navigatorObject) {
      var ua = navigatorObject && typeof navigatorObject.userAgent === 'string'
        ? navigatorObject.userAgent : '';
      return /iPad|iPhone|iPod/i.test(ua) ||
        (navigatorObject && navigatorObject.platform === 'MacIntel' && navigatorObject.maxTouchPoints > 1);
    }

    function installKind(navigatorObject, installed) {
      if (installed) return 'installed';
      if (deferredInstallPrompt) return 'prompt';
      if (isIos(navigatorObject)) return 'ios-manual';
      return 'unsupported';
    }

    async function readStoragePersisted(navigatorObject) {
      var storage = navigatorObject && navigatorObject.storage;
      if (!storage || typeof storage.persisted !== 'function') return null;
      try {
        return (await storage.persisted()) === true;
      } catch (_) {
        return null;
      }
    }

    async function persistentStorage() {
      var storage = root && root.navigator && root.navigator.storage;
      if (!storage || typeof storage.persist !== 'function') return false;
      var alreadyPersisted = await readStoragePersisted(root.navigator);
      if (alreadyPersisted === true) return true;
      try {
        return (await storage.persist()) === true;
      } catch (_) {
        return false;
      }
    }

    function requestNotifications() {
      if (typeof root.Notification !== 'function') return 'unsupported';
      if (root.Notification.permission && root.Notification.permission !== 'default') return root.Notification.permission;
      if (typeof root.Notification.requestPermission !== 'function') return 'unsupported';
      return Promise.resolve(root.Notification.requestPermission()).then(function (permission) { return String(permission); }).catch(function (error) {
        throw safeError('通知权限请求失败。', error);
      });
    }

    async function notify(payload) {
      if (typeof root.Notification !== 'function' || root.Notification.permission !== 'granted') throw safeError('请先开启通知权限。');
      var title = requiredString(payload, 'title');
      var body = optionalString(payload, 'body') || '';
      try {
        var workers = root.navigator && root.navigator.serviceWorker;
        var registration = workers && workers.getRegistration ? await workers.getRegistration() : null;
        if (registration && registration.showNotification) {
          await registration.showNotification(title, { body: body, icon: './icons/icon-192.png' });
        } else {
          new root.Notification(title, { body: body });
        }
      } catch (error) {
        throw safeError('通知发送失败。', error);
      }
      return null;
    }

    function install() {
      if (!deferredInstallPrompt) return false;
      var prompt = deferredInstallPrompt;
      deferredInstallPrompt = null;
      try {
        if (typeof prompt.prompt !== 'function') return false;
        prompt.prompt();
        return Promise.resolve(prompt.userChoice).then(function (choice) { return !!choice && choice.outcome === 'accepted'; }).catch(function (error) {
          throw safeError('安装提示无法打开。', error);
        });
      } catch (error) {
        throw safeError('安装提示无法打开。', error);
      }
    }

    async function checkUpdate() {
      var navigatorObject = root && root.navigator;
      var serviceWorker = navigatorObject && navigatorObject.serviceWorker;
      if (!serviceWorker || typeof serviceWorker.getRegistration !== 'function') {
        return { status: 'unsupported', updateAvailable: false, buildId: buildId() };
      }
      var registration;
      try {
        registration = await serviceWorker.getRegistration();
      } catch (_) {
        return { status: 'unsupported', updateAvailable: false, buildId: buildId() };
      }
      if (!registration) return { status: 'unsupported', updateAvailable: false, buildId: buildId() };
      if (typeof registration.update === 'function') {
        try { await registration.update(); } catch (_) {
          return { status: 'unsupported', updateAvailable: false, buildId: buildId() };
        }
      }
      var available = !!(registration.waiting || updateWaiting);
      return {
        status: available ? 'available' : 'latest',
        updateAvailable: available,
        buildId: buildId(),
      };
    }

    function audioCached(payload) {
      var accountId = requiredString(payload, 'accountId');
      var key = requiredString(payload, 'key');
      return getAudioCache(root, providedAudioCache).then(function (cache) { return Promise.resolve(cache.match(audioCacheKey(accountId, key, root))).then(function (value) { return !!value; }); });
    }

    function audioCacheDelete(payload) {
      var accountId = requiredString(payload, 'accountId');
      var key = requiredString(payload, 'key');
      return getAudioCache(root, providedAudioCache).then(function (cache) {
        return Promise.resolve(cache.delete(audioCacheKey(accountId, key, root))).then(function (deleted) {
          return deleted !== false;
        });
      });
    }

    function audioCacheKeys(payload) {
      var accountId = requiredString(payload, 'accountId');
      var prefix = audioCacheKey(accountId, '', root).replace(/\/$/, '') + '/';
      return getAudioCache(root, providedAudioCache).then(function (cache) {
        return Promise.resolve(cache.keys()).then(function (keys) {
          return keys.map(function (request) {
            if (!request || typeof request.url !== 'string' || request.url.indexOf(prefix) !== 0) {
              return null;
            }
            try {
              return decodeURIComponent(request.url.slice(prefix.length));
            } catch (_) {
              return null;
            }
          }).filter(function (key) { return typeof key === 'string' && key.indexOf('loop:') === 0; });
        });
      });
    }

    function audioCacheInfo(payload) {
      var accountId = requiredString(payload, 'accountId');
      var prefix = audioCacheKey(accountId, '', root).replace(/\/$/, '');
      return getAudioCache(root, providedAudioCache).then(function (cache) {
        return Promise.resolve(cache.keys()).then(function (keys) {
          var matching = keys.filter(function (request) { return request && typeof request.url === 'string' && request.url.indexOf(prefix + '/') === 0; });
          return Promise.all(matching.map(function (request) { return Promise.resolve(cache.match(request.url || request)).then(responseBytes); })).then(function (buffers) {
            return { count: buffers.filter(Boolean).length, bytes: buffers.reduce(function (sum, bytes) { return sum + (bytes ? bytes.byteLength : 0); }, 0) };
          });
        });
      });
    }

    function pushSubscribe(payload) {
      var publicKey = requiredString(payload, 'publicKey');
      return serviceWorkerRegistration(root).then(function (registration) {
        if (!registration.pushManager || typeof registration.pushManager.subscribe !== 'function') throw safeError('当前浏览器不支持推送提醒。');
        return Promise.resolve(registration.pushManager.getSubscription ? registration.pushManager.getSubscription() : null).then(function (existing) {
          if (existing) return existing;
          return registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: base64UrlToBytes(publicKey) });
        }).then(function (subscription) {
          if (!subscription) throw safeError('推送订阅失败。');
          if (typeof subscription.toJSON === 'function') return subscription.toJSON();
          return subscription;
        });
      }).catch(function (error) {
        if (error && error.name === 'SelahBridgeError') throw error;
        throw safeError('推送订阅失败。', error);
      });
    }

    function pushUnsubscribe() {
      var navigatorObject = root && root.navigator;
      if (!navigatorObject || !navigatorObject.serviceWorker) return false;
      return serviceWorkerRegistration(root).then(function (registration) {
        if (!registration.pushManager || typeof registration.pushManager.getSubscription !== 'function') return false;
        return Promise.resolve(registration.pushManager.getSubscription()).then(function (subscription) {
          if (!subscription || typeof subscription.unsubscribe !== 'function') return false;
          return Promise.resolve(subscription.unsubscribe()).then(function (value) { return value !== false; });
        });
      }).catch(function (error) {
        if (error && error.name === 'SelahBridgeError') throw error;
        throw safeError('推送退订失败。', error);
      });
    }

    function applyUpdate() {
      var navigatorObject = root && root.navigator;
      var waiting = updateWaiting;
      var serviceWorker = navigatorObject && navigatorObject.serviceWorker;
      var registrationPromise = serviceWorker && typeof serviceWorker.getRegistration === 'function'
        ? Promise.resolve(serviceWorker.getRegistration()) : Promise.resolve(null);
      // A waiting worker must receive the message.  Sending it to the active
      // controller would leave the update waiting forever.
      return registrationPromise.then(function (registration) {
        var candidate = (registration && registration.waiting) || waiting;
        if (candidate && typeof candidate.postMessage === 'function') {
          if (serviceWorker.addEventListener && root.location && root.location.reload) {
            serviceWorker.addEventListener('controllerchange', function () { root.location.reload(); }, { once: true });
          }
          candidate.postMessage({ type: 'APPLY_UPDATE' });
          return true;
        }
        return false;
      });
    }

    var handlers = {
      setUnloadProtection: function (payload) {
        unloadProtection = payload.enabled === true;
        return null;
      },
      load: load,
      save: save,
      downloadBackup: downloadBackup,
      importBackup: importBackup,
      platformInfo: platformInfo,
      persistentStorage: persistentStorage,
      checkUpdate: checkUpdate,
      requestNotifications: requestNotifications,
      notify: notify,
      install: install,
      audioEnsure: function (payload) { return cacheAudio(root, payload, providedAudioCache); },
      audioCached: audioCached,
      audioCacheDelete: audioCacheDelete,
      audioCacheKeys: audioCacheKeys,
      audioUnlock: function () {
        var AudioContextCtor = root && (root.AudioContext || root.webkitAudioContext);
        if (typeof AudioContextCtor !== 'function') return true;
        if (!root.__selahAudioContext) root.__selahAudioContext = new AudioContextCtor();
        var context = root.__selahAudioContext;
        if (!context || typeof context.resume !== 'function') return true;
        return Promise.resolve(context.resume()).then(function () { return true; });
      },
      audioPlay: audio.play,
      audioStatus: function () { return audio.status(); },
      audioPause: function () { return audio.pause(); },
      audioResume: function () { return audio.resume(); },
      audioStop: function () { return audio.stop(); },
      audioSeek: audio.seek,
      audioSpeed: audio.speed,
      audioCacheInfo: audioCacheInfo,
      audioLoopStart: function (payload) { return loopAudio.start(payload); },
      audioLoopStatus: function (payload) { return loopAudio.status(payload || {}); },
      audioLoopPause: function (payload) { return loopAudio.pause(payload || {}); },
      audioLoopResume: function (payload) { return loopAudio.resume(payload || {}); },
      audioLoopNext: function (payload) { return loopAudio.next(payload || {}); },
      audioLoopStop: function (payload) { return loopAudio.stop(payload || {}); },
      audioLoopOrder: function (payload) { return loopAudio.setOrder(payload || {}); },
      contentHash: function (payload) {
        var encoder = root.TextEncoder || (typeof TextEncoder !== 'undefined' && TextEncoder);
        if (!encoder) throw safeError('浏览器无法校验音频内容。');
        return digestSha256(root, new encoder().encode(requiredString(payload, 'text')));
      },
      recordStart: function () { return recorder.start(); },
      recordStop: function () { return recorder.stop(); },
      recordCancel: function () { return recorder.cancel(); },
      recordingStatus: function () { return recorder.status(); },
      pushSubscribe: pushSubscribe,
      pushUnsubscribe: pushUnsubscribe,
      applyUpdate: function () { return applyUpdate(); },
    };

    return function selahBridge(action, payloadJson) {
      if (typeof action !== 'string' || !Object.prototype.hasOwnProperty.call(handlers, action)) {
        return Promise.reject(safeError('不支持的浏览器操作。'));
      }
      var payload;
      try { payload = parsePayload(payloadJson); } catch (error) { return Promise.reject(error); }
      var handler = handlers[action];
      try {
        return Promise.resolve(handler(payload)).then(jsonResult).catch(function (error) {
          if (error && error.name === 'SelahBridgeError') throw error;
          throw safeError('浏览器操作失败。', error);
        });
      } catch (error) {
        return Promise.reject(error && error.name === 'SelahBridgeError' ? error : safeError('浏览器操作失败。', error));
      }
    };
  }

  return {
    createBridge: createBridge,
    helpers: {
      chooseRecordingMime: chooseRecordingMime,
      audioCacheKey: audioCacheKey,
      isSameOriginPath: isSameOriginPath,
      createMemorySnapshotStore: createMemorySnapshotStore,
      createMemoryAudioCache: createMemoryAudioCache,
      constants: { RECORDING_LIMIT_MS: RECORDING_LIMIT_MS, BACKUP_LIMIT_BYTES: BACKUP_LIMIT_BYTES },
    },
  };
});
