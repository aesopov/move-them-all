/* One fullscreen request per explicit action. No-fill/error still permits it. */
(function () {
  let active = false, sdk, statusReady = false, paying = false;
  let desired = false, applied, syncing = false;
  function disabled() {
    const state = window.PairUpPurchases ? JSON.parse(window.PairUpPurchases.snapshot()) : null;
    return !!state && (!state.ready || state.owned.includes('disable_ads'));
  }
  async function syncBanner() {
    desired = statusReady && !paying && !disabled();
    if (syncing || !sdk?.adv) return;
    syncing = true;
    try {
      while (applied !== desired) {
        const target = desired;
        if (target) await sdk.adv.showBannerAdv();
        else await sdk.adv.hideBannerAdv();
        applied = target;
      }
    } catch (_) { /* No banner support/no fill must never block gameplay. */ }
    finally { syncing = false; }
  }
  window.PairUpAds = {
    async init(value, player) {
      sdk = value;
      window.PairUpPurchases?.listen(syncBanner);
      // Hide first; ownership and paying status must be resolved before showing.
      syncBanner();
      try { paying = (player || await sdk.getPlayer()).getPayingStatus() === 'paying'; }
      catch (_) { paying = false; }
      statusReady = true;
      syncBanner();
    },
    show(callback) {
      if (disabled()) { callback('disabled'); return; }
      if (active) { callback('busy'); return; }
      active = true;
      let finished = false;
      const finish = result => {
        if (finished) return;
        finished = true; active = false;
        window.GodotYandexBridge?.refocusCanvas();
        callback(result);
      };
      try {
        const sdk = window.GodotYandexBridge?.ysdk;
        if (!sdk?.adv) { finish('unavailable'); return; }
        sdk.adv.showFullscreenAdv({callbacks:{
          onOpen() {},
          onClose: shown => finish(shown ? 'closed' : 'not_shown'),
          onError: () => finish('error'),
          onOffline: () => finish('offline')
        }});
      } catch (_) { finish('error'); }
    }
  };
})();
