/* Client-side Yandex fulfillment. Only SDK receipts create credits. Never consume
 * a receipt before the receipt + its five credit slots are durably cloud-saved. */
(function () {
  'use strict';
  const KEY = 'pairUpPurchasesV1';
  const known = id => id === 'disable_ads' || id === 'skips_5' || id === 'unlock_all_levels' || /^unlock_world_(0[1-9]|1[01])$/.test(id);
  const empty = () => ({version: 1, receipts: [], spent: {}});
  let sdk, payments, player, owner, ledger = empty(), owned = [], catalog = [];
  let ready = false, busy = false, modal = false, paying = false, error = '', retry, subscriber;
  let tail = Promise.resolve(), queued = 0;
  const listeners = new Set();
  let committed = {ready: false, owned: [], catalog: [], paid_skips: 0, paid_skipped: []};
  function snapshot() {
    // Publish financial data atomically, never midway through recovery/fulfillment.
    if (!busy) committed = {ready, owned: [...owned], catalog,
      paid_skips: ledger.receipts.length * 5 - Object.keys(ledger.spent).length,
      paid_skipped: [...new Set(Object.values(ledger.spent))]};
    return {...committed, busy, modal, paying, error};
  }
  function publish() {
    if (!busy && owner) window.PairUpSave?.recordPaidSkips?.(owner, [...new Set(Object.values(ledger.spent))]);
    if (subscriber) subscriber(JSON.stringify(snapshot())); for (const fn of listeners) fn(); }
  function normalize(data) {
    const value = empty();
    if (!data || typeof data !== 'object') return value;
    value.receipts = [...new Set((Array.isArray(data.receipts) ? data.receipts : [])
      .filter(token => typeof token === 'string' && token.length > 0))];
    for (const token of value.receipts) for (let slot = 0; slot < 5; slot++) {
      const key = `${token}:${slot}`, path = data.spent?.[key];
      if (typeof path === 'string' && /^res:\/\/levels\/world_\d+\/level_\d+\.json$/.test(path)) value.spent[key] = path;
    }
    return value;
  }
  async function context() {
    const next = await sdk.getPlayer();
    const id = next.getUniqueID();
    if (!id) throw Error('player_unavailable');
    if ((owner && owner !== id) || (window.PairUpSave?.owner && window.PairUpSave.owner() !== 'offline' && window.PairUpSave.owner() !== id)) {
      ready = false; owned = []; ledger = empty();
      throw Error('account_changed'); // Reload aligns both progression and purchases with the new account.
    }
    owner = id; player = next;
    const data = await player.getData([KEY]);
    const remote = normalize(data[KEY]);
    // A Player read can lag a successful flushed write. Never discard an
    // acknowledged receipt or spend when refreshing the same account.
    const merged = normalize({receipts: [...remote.receipts, ...ledger.receipts],
      spent: {...ledger.spent, ...remote.spent}});
    if (JSON.stringify(merged) !== JSON.stringify(remote)) await persist(merged);
    else ledger = remote;
  }
  async function persist(next) {
    await window.PairUpStorage.write(player, {[KEY]: next});
    ledger = next;
    publish();
  }
  async function fulfill(purchase) {
    if (!purchase || !known(purchase.productID)) return;
    if (purchase.productID !== 'skips_5') {
      if (!owned.includes(purchase.productID)) owned.push(purchase.productID);
      return; // Permanent products MUST remain in getPurchases().
    }
    const token = purchase.purchaseToken;
    if (typeof token !== 'string' || !token) throw Error('invalid_receipt');
    if (!ledger.receipts.includes(token)) {
      const next = JSON.parse(JSON.stringify(ledger));
      next.receipts.push(token);
      await persist(next);
    }
    // A crash here is safe: on retry the cloud token prevents a second grant.
    await payments.consumePurchase(token);
  }
  async function recover() {
    ready = false;
    if (!payments) payments = await sdk.getPayments({signed: false});
    await context();
    const purchases = await payments.getPurchases();
    if (!Array.isArray(purchases)) throw Error('invalid_purchases');
    owned = purchases.filter(p => known(p.productID) && p.productID !== 'skips_5').map(p => p.productID);
    let failure;
    // One failed consumable must not prevent recovery of the other receipts.
    for (const purchase of purchases) {
      try { await fulfill(purchase); } catch (e) { failure = e; }
    }
    publish();
    if (failure) throw failure;
    const products = await payments.getCatalog();
    catalog = products.filter(p => known(p.id)).map(p => ({id: p.id, title: p.title,
      description: p.description, price: p.price, priceValue: p.priceValue,
      priceCurrencyCode: p.priceCurrencyCode,
      currencyImage: typeof p.getPriceCurrencyImage === 'function' ? p.getPriceCurrencyImage('small') : ''}));
    ready = true;
  }
  function transaction(task) {
    queued++; busy = true;
    const run = async () => {
      busy = true; error = ''; publish();
      try {
        // Serializes read-modify-write across tabs where Web Locks are supported.
        if (window.navigator?.locks) return await navigator.locks.request('pair-up-purchases', task);
        return await task();
      } catch (e) {
        ready = false;
        error = e.message === 'account_changed' ? 'account_changed' : 'unavailable';
        clearTimeout(retry);
        if (error !== 'account_changed') retry = setTimeout(() => api.refresh(), 30000);
        console.warn('[Pair Up] Purchase operation deferred', e);
        return {ok: false, error};
      } finally { queued--; busy = queued > 0; publish(); }
    };
    const result = tail.then(run, run);
    tail = result.catch(() => {});
    return result;
  }
  const api = window.PairUpPurchases = {
    canReset() {
      try { return new URLSearchParams(window.location.search).get('purchase-testing') === '1' || localStorage.getItem('pairUpPurchaseTesting') === '1'; }
      catch (_) { return false; }
    },
    reset(callback) {
      const finish = result => { if (callback) callback(JSON.stringify(result)); return result; };
      if (!api.canReset() || busy || !sdk) return Promise.resolve(finish({ok:false}));
      return transaction(async () => {
        if (!payments) payments = await sdk.getPayments({signed:false});
        await context();
        const receipts = await payments.getPurchases();
        for (const receipt of receipts) {
          if (known(receipt.productID)) await payments.consumePurchase(receipt.purchaseToken);
        }
        // Explicit testing reset: discard credits only after outstanding receipts are removed.
        if (!window.PairUpSave?.resetPurchases) throw Error('storage_unavailable');
        ledger = empty(); owned = [];
        await window.PairUpSave.resetPurchases(player, ledger);
        ready = true;
        return {ok:true};
      }).then(finish);
    },
    init(value) { sdk = value; return api.refresh(); },
    subscribe(fn) { subscriber = fn; publish(); },
    listen(fn) { listeners.add(fn); },
    snapshot() { return JSON.stringify(snapshot()); },
    setModal(value) { modal = !!value; publish(); },
    refresh() {
      clearTimeout(retry);
      return transaction(async () => { await recover(); return {ok: true}; });
    },
    buy(id) {
      if (busy || !ready || !known(id)) return Promise.resolve({ok: false, error: 'unavailable'});
      return transaction(async () => {
        await recover(); // Recover pending charges BEFORE accepting another payment.
        if ((id !== 'disable_ads' && owned.includes('unlock_all_levels')) || owned.includes(id)) return {ok: false, error: 'owned'};
        if (!catalog.some(p => p.id === id)) return {ok: false, error: 'unavailable'};
        let receipt;
        try {
          paying = true; publish();
          receipt = await payments.purchase({id});
        }
        catch (_) {
          // Rejection can also be a lost success response: recover before offering retry.
          await recover();
          return {ok: false, error: 'cancelled'};
        } finally { paying = false; publish(); }
        // Checkout may authorize/switch accounts. Never credit the previous player.
        await context();
        await fulfill(receipt);
        publish();
        return {ok: true};
      });
    },
    spend(path, callback) {
      const finish = result => { if (callback) callback(JSON.stringify(result)); return result; };
      if (busy || !ready || !/^res:\/\/levels\/world_\d+\/level_\d+\.json$/.test(path))
        return Promise.resolve(finish({ok: false}));
      return transaction(async () => {
        await recover();
        if (Object.values(ledger.spent).includes(path)) return {ok: true};
        if (owned.includes('unlock_all_levels')) return {ok: false};
        for (const token of ledger.receipts) for (let slot = 0; slot < 5; slot++) {
          const key = `${token}:${slot}`;
          if (Object.hasOwn(ledger.spent, key)) continue;
          const next = JSON.parse(JSON.stringify(ledger));
          next.spent[key] = path;
          // Spending and the skipped path are one durable record; reload cannot lose access.
          await persist(next);
          return {ok: true};
        }
        return {ok: false};
      }).then(finish);
    }
  };
  window.addEventListener('online', () => { if (sdk && !busy) api.refresh(); });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && sdk && !busy && !modal) api.refresh();
  });
})();
