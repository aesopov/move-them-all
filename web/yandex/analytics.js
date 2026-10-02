/* Yandex-only gameplay metrics. Never delay gameplay on analytics delivery. */
(function () {
  const COUNTER = 113340672;
  const events = new Set(['level_started', 'level_completed', 'level_restarted', 'level_skipped', 'level_exited']);
  const host = location.hostname;
  const testing = new URLSearchParams(location.search).get('purchase-testing') === '1';
  let localTesting = false;
  try { localTesting = localStorage.getItem('pairUpPurchaseTesting') === '1'; } catch (_) {}
  const enabled = !['localhost', '127.0.0.1', '::1', '[::1]', ''].includes(host) && !testing && !localTesting;
  window.PairUpAnalytics = {
    track(event, json) {
      if (!enabled || !events.has(event)) return;
      try {
        const data = JSON.parse(json);
        if (!/^world_\d+\/level_\d+$/.test(data.level) || !/^[a-f0-9]{64}$/.test(data.revision)) return;
        // Hierarchy allows reports/segments by level, revision, then outcome.
        window.ym(COUNTER, 'reachGoal', event, {levels: {[data.level]: {[data.revision]: {[event]: {
          moves: data.moves, seconds: data.seconds, resumed: data.resumed,
          score: data.score || 0
        }}}}});
      } catch (_) { /* Blocked analytics must never break the game. */ }
    }
  };
  if (!enabled) return;
  window.ym = window.ym || function () { (window.ym.a = window.ym.a || []).push(arguments); };
  window.ym.l = Date.now();
  const src = 'https://mc.yandex.ru/metrika/tag.js?id=' + COUNTER;
  if (!Array.from(document.scripts).some(script => script.src === src)) {
    const script = document.createElement('script');
    script.async = true;
    script.src = src;
    document.head.appendChild(script);
  }
  window.ym(COUNTER, 'init', {
    webvisor: false, clickmap: false, trackLinks: false,
    accurateTrackBounce: true, referrer: document.referrer, url: location.href
  });
})();
