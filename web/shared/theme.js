/* theme.js — theme switcher for NASFAA web pages.
 *
 * Plain script (no modules) so it works from file://. Attaches to
 * window.NasfaaTheme. The CSS in tokens.css handles prefers-color-scheme
 * automatically; this script only intervenes when the user has chosen
 * an explicit theme.
 *
 * Storage key: 'nasfaa-theme' in localStorage. Allowed values:
 *   'light' | 'dark' | 'vt102' | null (null = follow system preference)
 */
(function () {
  'use strict';

  var STORAGE_KEY = 'nasfaa-theme';
  var THEMES = ['light', 'dark', 'vt102'];
  // Cycle order: light -> dark -> vt102 -> system (null) -> light ...
  var CYCLE = ['light', 'dark', 'vt102', null];

  function safeGet() {
    try { return window.localStorage.getItem(STORAGE_KEY); }
    catch (e) { return null; }
  }

  function safeSet(value) {
    try {
      if (value === null) window.localStorage.removeItem(STORAGE_KEY);
      else window.localStorage.setItem(STORAGE_KEY, value);
    } catch (e) { /* private browsing / disabled storage — fail silent */ }
  }

  function isValidTheme(t) {
    return THEMES.indexOf(t) !== -1;
  }

  function applyAttribute(theme) {
    var root = document.documentElement;
    if (theme === null || theme === undefined) {
      root.removeAttribute('data-theme');
    } else {
      root.setAttribute('data-theme', theme);
    }
  }

  /**
   * Set the active theme.
   * @param {('light'|'dark'|'vt102'|null)} themeName — null clears the
   *   stored preference and reverts to prefers-color-scheme.
   */
  function set(themeName) {
    if (themeName === null || themeName === undefined) {
      safeSet(null);
      applyAttribute(null);
      return null;
    }
    if (!isValidTheme(themeName)) {
      // Unknown theme — ignore rather than corrupt state.
      return current();
    }
    safeSet(themeName);
    applyAttribute(themeName);
    return themeName;
  }

  /**
   * Rotate through light -> dark -> vt102 -> system -> light.
   *
   * When a theme is stored, cycle from there. When nothing is stored
   * yet (first load, following system preference), cycle from the
   * effective theme so the first click always produces a visible change
   * — otherwise the first click could resolve `null -> light` while
   * the system already renders light, looking like a no-op.
   */
  function cycle() {
    var stored = safeGet();
    var startKey = isValidTheme(stored) ? stored : current();
    var index = CYCLE.indexOf(startKey);
    if (index === -1) index = 0;
    var next = CYCLE[(index + 1) % CYCLE.length];
    return set(next);
  }

  /**
   * Return the currently effective theme name.
   * If user has set an explicit theme, return it. Otherwise compute
   * from prefers-color-scheme.
   */
  function current() {
    var stored = safeGet();
    if (isValidTheme(stored)) return stored;
    if (window.matchMedia &&
        window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return 'dark';
    }
    return 'light';
  }

  /**
   * Return the stored preference (or null if none).
   */
  function stored() {
    var s = safeGet();
    return isValidTheme(s) ? s : null;
  }

  // ---- Bootstrap on script load --------------------------------
  // Apply stored theme attribute (if any). If nothing is stored,
  // leave the attribute off so the @media query in tokens.css
  // controls the palette.
  var initial = safeGet();
  if (isValidTheme(initial)) {
    applyAttribute(initial);
  }

  // Listen for system preference changes. We don't need to do anything
  // when an explicit theme is set (CSS attribute wins). But if no
  // explicit theme is set, the browser will re-evaluate the @media
  // query automatically — we still fire a small no-op apply so that
  // any page-level listener can react if it wants.
  if (window.matchMedia) {
    var mql = window.matchMedia('(prefers-color-scheme: dark)');
    var onChange = function () {
      if (!isValidTheme(safeGet())) {
        // Re-apply (clear) to ensure no stale attribute lingers and
        // to trigger any custom observers.
        applyAttribute(null);
      }
    };
    if (mql.addEventListener) mql.addEventListener('change', onChange);
    else if (mql.addListener) mql.addListener(onChange); // Safari < 14
  }

  window.NasfaaTheme = {
    set: set,
    cycle: cycle,
    current: current,
    stored: stored,
    THEMES: THEMES.slice()
  };
})();
