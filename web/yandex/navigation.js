/* Give Android/browser Back an in-game destination inside the game iframe.
 * Keep at most one extra entry; menu Back can still leave the game. */
(function () {
  const KEY = 'pairUpLevelNavigation';
  let active = false, callback;
  const state = value => ({...window.history.state, [KEY]: value});
  window.PairUpNavigation = {
    subscribe(fn) { callback = fn; },
    setLevelActive(value) {
      active = Boolean(value);
      // Retain the marker when inactive so opening another level reuses it.
      if (active) {
        if (window.history.state?.[KEY] !== 'level') {
          window.history.replaceState(state('select'), '');
          window.history.pushState(state('level'), '');
        }
      }
    }
  };
  window.addEventListener('popstate', () => {
    if (!active) return;
    // Re-arm until Godot can leave safely (a load, ad or payment may be pending).
    window.history.pushState(state('level'), '');
    if (callback) callback();
  });
})();
