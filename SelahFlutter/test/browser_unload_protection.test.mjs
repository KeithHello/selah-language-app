import test from 'node:test';
import assert from 'node:assert/strict';
import bridgeModule from '../web/selah_bridge.js';

test('beforeunload protects only while explicitly enabled', async () => {
  const listeners = {};
  const bridge = bridgeModule.createBridge({root: {navigator: {}, addEventListener(name, fn) { listeners[name] = fn; }}});
  let prevented = false;
  const event = {preventDefault() { prevented = true; }};
  listeners.beforeunload?.(event);
  assert.equal(prevented, false);
  await bridge('setUnloadProtection', JSON.stringify({enabled: true}));
  listeners.beforeunload(event);
  assert.equal(prevented, true);
  assert.equal(event.returnValue, '');
  await bridge('setUnloadProtection', JSON.stringify({enabled: false}));
  prevented = false;
  listeners.beforeunload({preventDefault() { prevented = true; }});
  assert.equal(prevented, false);
});
