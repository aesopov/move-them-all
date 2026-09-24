/* Player data is loaded before Godot starts; failures fall back to an account-scoped
 * local journal. Never upload defaults until a successful cloud read. */
(function () {
  const KEY = 'pairUpProgress';
  const empty = () => ({version: 1, scores: {}, skipped: []});
  const read = key => { try { return JSON.parse(localStorage.getItem(key)); } catch (_) { return null; } };
  const write = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} };
  function merge(...records) {
    const result = empty();
    for (const record of records) {
      if (!record || typeof record !== 'object' || Array.isArray(record)) continue;
      const scores = record.scores || record;
      for (const [path, value] of Object.entries(scores)) {
        if (path.startsWith('res://levels/') && Number.isFinite(value) && value > 0)
          result.scores[path] = Math.max(result.scores[path] || 0, Math.floor(value));
      }
      for (const path of Array.isArray(record.skipped) ? record.skipped : []) {
        if (typeof path === 'string' && path.startsWith('res://levels/') && !result.skipped.includes(path))
          result.skipped.push(path);
      }
    }
    return result;
  }
  async function bounded(promise) {
    let timer;
    try {
      return await Promise.race([promise, new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('Player storage timeout')), 6000);
      })]);
    } finally { clearTimeout(timer); }
  }
  let player, ready = false, connecting = false, saving = false, dirty = false;
  let callback, retry, saveTimer, lastWrite = 0;
  let owner = read('pairUpLastPlayer') || 'offline';
  let state = merge(read(`pairUpSave:${owner}`));
  function publish() {
    write(`pairUpSave:${owner}`, state);
    if (callback) callback(JSON.stringify(state));
  }
  function scheduleSave(delay = 0) {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(flush, Math.max(delay, 3500 - (Date.now() - lastWrite)));
  }
  async function flush() {
    if (!ready || !dirty || saving) return;
    saving = true;
    dirty = false;
    lastWrite = Date.now();
    try {
      await bounded(player.setData({[KEY]: JSON.parse(JSON.stringify(state))}, true));
    } catch (error) {
      dirty = true;
      console.warn('[Pair Up] Cloud save deferred', error);
    } finally {
      saving = false;
      if (dirty) scheduleSave(15000);
    }
  }
  async function connect() {
    if (connecting || ready) return;
    connecting = true;
    try {
      player = await bounded(GodotYandexBridge.ysdk.getPlayer());
      const id = player.getUniqueID();
      if (!id) throw new Error('Player ID unavailable');
      if (owner !== id) {
        // An account switch must not inherit another account's journal.
        state = merge(read(`pairUpSave:${id}`), owner === 'offline' ? state : null);
        owner = id;
      }
      write('pairUpLastPlayer', owner);
      publish();
      const data = await bounded(player.getData([KEY]));
      state = merge(state, data[KEY]);
      ready = true;
      dirty = true;
      publish();
      scheduleSave();
    } catch (error) {
      console.warn('[Pair Up] Cloud progress unavailable; keeping local progress', error);
      clearTimeout(retry);
      retry = setTimeout(connect, 30000);
    } finally { connecting = false; }
  }
  window.PairUpSave = {
    subscribe(fn) { callback = fn; },
    load(legacyJson) {
      // Import the old Godot-only save once, never into every new account.
      if (!read('pairUpLegacyImported')) {
        state = merge(state, JSON.parse(legacyJson));
        write('pairUpLegacyImported', true);
        dirty = true;
        publish();
        scheduleSave();
      }
      return JSON.stringify(state);
    },
    save(json) {
      state = merge(state, JSON.parse(json));
      dirty = true;
      publish();
      scheduleSave();
    }
  };
  window.mergeYandexReady = new Promise((resolve, reject) => {
    GodotYandexBridge.init('{}', async json => {
      const result = JSON.parse(json);
      if (!result.success) { reject(new Error(result.error)); return; }
      window.mergeYandexLanguage = result.data.environment.i18n.lang || 'en';
      document.documentElement.lang = window.mergeYandexLanguage;
      // A slow cloud request must not block playing indefinitely.
      let timeout;
      await Promise.race([connect(), new Promise(done => { timeout = setTimeout(done, 8000); })]);
      clearTimeout(timeout);
      resolve();
    });
  });
  window.addEventListener('online', () => { if (!ready) connect(); else scheduleSave(); });
})();
document.addEventListener('contextmenu', event => event.preventDefault());
