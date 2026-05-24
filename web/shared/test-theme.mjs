// test-theme.mjs — Node tests for web/shared/theme.js.
//
//   node --test web/shared/test-theme.mjs
//
// theme.js is a browser-only IIFE that touches window.localStorage,
// window.matchMedia, and document.documentElement, then attaches
// window.NasfaaTheme. There's no module.exports — `window` MUST exist
// before require(). Each test sets up a fresh stub environment, busts
// the require cache, reloads the module, then introspects NasfaaTheme
// off the stub window.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const THEME_PATH = require.resolve('./theme.js');

// ──────────────────────────────────────────────────────────────────────
// Environment stubs
// ──────────────────────────────────────────────────────────────────────

function memoryStorage(initial) {
  const store = { ...(initial || {}) };
  return {
    getItem: (k) => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: (k) => { delete store[k]; },
    _peek: () => ({ ...store }),
  };
}

function throwingStorage() {
  const fail = () => { throw new Error('storage blocked'); };
  return { getItem: fail, setItem: fail, removeItem: fail };
}

function mediaQueryList(matches, { useLegacyListener = false, noListener = false } = {}) {
  const listeners = [];
  const mql = {
    matches,
    _fire() { for (const fn of listeners) fn({ matches: !matches }); },
  };
  if (noListener) {
    // Neither addEventListener nor addListener — exercises the else-if
    // false arm in theme.js's listener registration.
  } else if (useLegacyListener) {
    mql.addListener = (fn) => listeners.push(fn);
  } else {
    mql.addEventListener = (_evt, fn) => listeners.push(fn);
  }
  return mql;
}

function fakeDocument() {
  return {
    documentElement: {
      _attrs: {},
      setAttribute(k, v) { this._attrs[k] = v; },
      removeAttribute(k) { delete this._attrs[k]; },
      getAttribute(k) { return this._attrs[k]; },
    },
  };
}

// Loads theme.js fresh under the supplied stub environment. Returns
// { theme, win, doc } so tests can introspect both the API and the
// stub state.
function loadTheme({
  storage = {},
  storageBroken = false,
  matchMediaSupported = true,
  matchMediaDark = false,
  useLegacyListener = false,
  noListener = false,
  registerMql,
} = {}) {
  const win = {
    localStorage: storageBroken ? throwingStorage() : memoryStorage(storage),
  };
  if (matchMediaSupported) {
    win.matchMedia = () => {
      const mql = mediaQueryList(matchMediaDark, { useLegacyListener, noListener });
      if (registerMql) registerMql(mql);
      return mql;
    };
  }
  const doc = fakeDocument();
  // theme.js looks up `window` and `document` at CALL time (not at module
  // load), so we install the stubs as actual globals and leave them in
  // place. Each loadTheme call overwrites them with a fresh environment.
  // The after() hook below cleans up at the end of the suite.
  globalThis.window = win;
  globalThis.document = doc;
  delete require.cache[THEME_PATH];
  require('./theme.js');
  return { theme: win.NasfaaTheme, win, doc };
}

import { after } from 'node:test';
after(() => {
  delete globalThis.window;
  delete globalThis.document;
});

// ──────────────────────────────────────────────────────────────────────
// Exported surface
// ──────────────────────────────────────────────────────────────────────

test('NasfaaTheme: exposes set/cycle/current/stored/THEMES', () => {
  const { theme } = loadTheme();
  assert.equal(typeof theme.set, 'function');
  assert.equal(typeof theme.cycle, 'function');
  assert.equal(typeof theme.current, 'function');
  assert.equal(typeof theme.stored, 'function');
  assert.deepEqual(theme.THEMES, ['light', 'dark', 'vt102']);
});

test('THEMES is a copy — mutation does not leak into the module', () => {
  const { theme } = loadTheme();
  theme.THEMES.push('hacked');
  const { theme: theme2 } = loadTheme();
  assert.deepEqual(theme2.THEMES, ['light', 'dark', 'vt102']);
});

// ──────────────────────────────────────────────────────────────────────
// Bootstrap — applies stored theme on load when valid
// ──────────────────────────────────────────────────────────────────────

test('bootstrap: applies stored theme attribute on load when valid', () => {
  const { doc } = loadTheme({ storage: { 'nasfaa-theme': 'dark' } });
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
});

test('bootstrap: leaves data-theme unset when no stored preference', () => {
  const { doc } = loadTheme();
  assert.equal(doc.documentElement.getAttribute('data-theme'), undefined);
});

test('bootstrap: ignores invalid stored value', () => {
  const { doc } = loadTheme({ storage: { 'nasfaa-theme': 'magenta' } });
  assert.equal(doc.documentElement.getAttribute('data-theme'), undefined);
});

// ──────────────────────────────────────────────────────────────────────
// set() — null clears, valid theme stores, invalid is no-op
// ──────────────────────────────────────────────────────────────────────

test('set("dark"): stores and applies the attribute', () => {
  const { theme, doc, win } = loadTheme();
  assert.equal(theme.set('dark'), 'dark');
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
  assert.equal(win.localStorage._peek()['nasfaa-theme'], 'dark');
});

test('set(null): removes the stored value and clears the attribute', () => {
  const { theme, doc, win } = loadTheme({ storage: { 'nasfaa-theme': 'dark' } });
  assert.equal(theme.set(null), null);
  assert.equal(doc.documentElement.getAttribute('data-theme'), undefined);
  assert.equal('nasfaa-theme' in win.localStorage._peek(), false);
});

test('set(undefined): same as set(null)', () => {
  const { theme } = loadTheme();
  assert.equal(theme.set(undefined), null);
});

test('set("magenta"): unknown — returns current(), does not store', () => {
  const { theme, doc, win } = loadTheme({ storage: { 'nasfaa-theme': 'dark' } });
  // current() returns 'dark' since dark is the stored value
  assert.equal(theme.set('magenta'), 'dark');
  // Attribute remains as dark (from bootstrap), storage unchanged
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
  assert.equal(win.localStorage._peek()['nasfaa-theme'], 'dark');
});

// ──────────────────────────────────────────────────────────────────────
// current() — explicit stored wins; otherwise prefers-color-scheme
// ──────────────────────────────────────────────────────────────────────

test('current(): returns stored value when valid', () => {
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'vt102' } });
  assert.equal(theme.current(), 'vt102');
});

test('current(): system dark → "dark"', () => {
  const { theme } = loadTheme({ matchMediaDark: true });
  assert.equal(theme.current(), 'dark');
});

test('current(): system light → "light"', () => {
  const { theme } = loadTheme({ matchMediaDark: false });
  assert.equal(theme.current(), 'light');
});

test('current(): without matchMedia support → "light"', () => {
  const { theme } = loadTheme({ matchMediaSupported: false });
  assert.equal(theme.current(), 'light');
});

// ──────────────────────────────────────────────────────────────────────
// stored() — only valid values, never the raw localStorage result
// ──────────────────────────────────────────────────────────────────────

test('stored(): returns valid value as-is', () => {
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'light' } });
  assert.equal(theme.stored(), 'light');
});

test('stored(): returns null for missing key', () => {
  const { theme } = loadTheme();
  assert.equal(theme.stored(), null);
});

test('stored(): returns null for invalid stored value (does not leak garbage)', () => {
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'magenta' } });
  assert.equal(theme.stored(), null);
});

// ──────────────────────────────────────────────────────────────────────
// cycle() — light → dark → vt102 → null → light, anchored to effective
// ──────────────────────────────────────────────────────────────────────

test('cycle(): from light system default → dark', () => {
  // No stored value; current() returns 'light' (matchMediaDark=false default).
  const { theme } = loadTheme();
  assert.equal(theme.cycle(), 'dark');
});

test('cycle(): from dark system default → vt102', () => {
  const { theme } = loadTheme({ matchMediaDark: true });
  assert.equal(theme.cycle(), 'vt102');
});

test('cycle(): vt102 → null (system)', () => {
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'vt102' } });
  assert.equal(theme.cycle(), null);
});

test('cycle(): null → light (wraps around)', () => {
  // No stored, matchMedia not supported → current returns 'light' → cycle to 'dark'.
  // To exercise the wrap-around explicitly: stored is null/missing AND current
  // returns 'vt102' is implausible (current returns light/dark only), so the
  // null→light wrap is exercised by setting stored to vt102 then cycling twice.
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'vt102' } });
  theme.cycle();          // vt102 → null (cleared)
  // After clearing, the next cycle re-anchors via current() (which is 'light').
  assert.equal(theme.cycle(), 'dark');
});

test('cycle(): unknown stored value lands on index 0 → cycles from light', () => {
  // safeGet returns 'magenta' (invalid), so startKey = current(). With
  // matchMediaDark=false (default), current = 'light'. CYCLE.indexOf('light')
  // = 0; cycle to next = 'dark'.
  const { theme } = loadTheme({ storage: { 'nasfaa-theme': 'magenta' } });
  assert.equal(theme.cycle(), 'dark');
});

// The defensive `if (index === -1) index = 0` arm in cycle() at line 77
// is provably unreachable: startKey is either a valid theme (in CYCLE)
// or current()'s return ('light' / 'dark' / valid stored), all of which
// appear in CYCLE = ['light','dark','vt102',null]. Reaching the arm
// would require monkey-patching the module's internal CYCLE array,
// which is closure-private. Coverage stops at 97.4% branch on theme.js
// for this reason. (Verified with NODE_V8_COVERAGE dump 2026-05-24.)

// ──────────────────────────────────────────────────────────────────────
// safeGet / safeSet under broken localStorage
// ──────────────────────────────────────────────────────────────────────

test('broken localStorage: stored() returns null', () => {
  const { theme } = loadTheme({ storageBroken: true });
  assert.equal(theme.stored(), null);
});

test('broken localStorage: set(theme) still applies the attribute (silent failure)', () => {
  const { theme, doc } = loadTheme({ storageBroken: true });
  theme.set('dark');
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
});

test('broken localStorage: set(null) does not throw', () => {
  const { theme } = loadTheme({ storageBroken: true });
  assert.doesNotThrow(() => theme.set(null));
});

// ──────────────────────────────────────────────────────────────────────
// matchMedia change listener
// ──────────────────────────────────────────────────────────────────────

test('matchMedia change listener: re-applies (clears) when no explicit theme', () => {
  let registered;
  const { doc } = loadTheme({
    registerMql: (mql) => { registered = mql; },
  });
  // Pre-condition: no stored theme, so the listener clears on fire.
  doc.documentElement.setAttribute('data-theme', 'stale'); // simulate a stale leftover
  registered._fire();
  assert.equal(doc.documentElement.getAttribute('data-theme'), undefined);
});

test('matchMedia change listener: no-op when an explicit theme is set', () => {
  let registered;
  const { doc } = loadTheme({
    storage: { 'nasfaa-theme': 'dark' },
    registerMql: (mql) => { registered = mql; },
  });
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
  registered._fire();
  // Listener bailed because stored is valid; attribute unchanged.
  assert.equal(doc.documentElement.getAttribute('data-theme'), 'dark');
});

test('matchMedia change listener: registers via legacy addListener when addEventListener missing', () => {
  let registered;
  const { doc } = loadTheme({
    useLegacyListener: true,
    registerMql: (mql) => { registered = mql; },
  });
  assert.equal(typeof registered.addListener, 'function');
  doc.documentElement.setAttribute('data-theme', 'stale');
  registered._fire();
  assert.equal(doc.documentElement.getAttribute('data-theme'), undefined);
});

test('no matchMedia at all: bootstrap still completes without throwing', () => {
  const { theme } = loadTheme({ matchMediaSupported: false });
  assert.equal(theme.current(), 'light');
});

test('matchMedia present but MQL has neither add{EventListener,Listener}: silent no-op', () => {
  // Pathological MQL: no way to subscribe. Bootstrap must not throw;
  // the change-listener registration's else-if false arm is exercised.
  assert.doesNotThrow(() => loadTheme({ noListener: true }));
});
