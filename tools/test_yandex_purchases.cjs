const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('web/yandex/purchases.js', 'utf8');
const KEY = 'pairUpPurchasesV1';
const path = n => `res://levels/world_01/level_${String(n).padStart(2, '0')}.json`;
const clone = x => JSON.parse(JSON.stringify(x));
async function setup(options = {}) {
  const backend = options.backend || {data: {}, pending: [], next: 0};
  const calls = [], timers = new Map();
  let failRead = !!options.failRead, failWrite = !!options.failWrite, failConsume = false, lostWrite = false, lostBuy = false, cancelled = false;
  let staleData = null;
  let owner = 'alice', serial = 0, activeWrites = 0, maxWrites = 0;
  const player = {
    getUniqueID: () => owner,
    getData: async () => { calls.push('read'); if (failRead) throw Error('offline'); return clone(staleData || backend.data); },
    setData: async (data, flush) => {
      assert.equal(flush, true); calls.push('save');
      activeWrites++; maxWrites = Math.max(maxWrites, activeWrites); await Promise.resolve(); activeWrites--;
      if (failWrite) throw Error('save failed');
      Object.assign(backend.data, clone(data));
      if (lostWrite) throw Error('ack lost');
    }
  };
  const payment = {
    getPurchases: async () => { calls.push('purchases'); return clone(backend.pending); },
    getCatalog: async () => ['skips_5', 'unlock_world_03', 'unlock_all_levels'].map(id => ({id, title:id,
      description:'Description', price:'50 YAN', priceValue:'50', priceCurrencyCode:'YAN', getPriceCurrencyImage: () => 'https://example.test/currency.png'})),
    purchase: async ({id}) => {
      calls.push(`buy:${id}`); if (cancelled) throw Error('cancelled');
      const receipt = {productID:id, purchaseToken:`receipt-${++backend.next}`};
      backend.pending.push(receipt);
      if (lostBuy) throw Error('response lost');
      return clone(receipt);
    },
    consumePurchase: async token => {
      calls.push(`consume:${token}`);
      assert(backend.data[KEY]?.receipts.includes(token), 'Must durably grant BEFORE consuming');
      if (failConsume) throw Error('consume failed');
      backend.pending = backend.pending.filter(p => p.purchaseToken !== token);
    }
  };
  const env = {console:{warn(){}}, navigator:{}, document:{addEventListener(){}}, addEventListener(){},
    setTimeout:(fn, ms) => { const id=++serial;timers.set(id,{fn,ms});return id; },clearTimeout:id=>timers.delete(id)};
  env.window=env;
  vm.runInNewContext(source,env);
  const api=env.PairUpPurchases;
  const sdk={getPlayer:async()=>player,getPayments:async options=>{assert.equal(options.signed,false);return payment;}};
  await api.init(sdk);
  return {api,backend,calls,timers,view:()=>JSON.parse(api.snapshot()),maxWrites:()=>maxWrites,
    staleData:v=>staleData=v,failRead:v=>failRead=v,failWrite:v=>failWrite=v,failConsume:v=>failConsume=v,
    lostWrite:v=>lostWrite=v,lostBuy:v=>lostBuy=v,cancel:v=>cancelled=v,owner:v=>owner=v};
}
(async () => {
  const offline=await setup({failRead:true,backend:{data:{},pending:[{productID:'skips_5',purchaseToken:'offline-receipt'}],next:0}});
  assert.equal(offline.view().ready,false);
  assert(!offline.calls.includes('save'),'Startup failed read cannot write defaults');
  assert(!offline.calls.some(c=>c.startsWith('consume:')),'Startup failed read cannot consume');
  assert.equal(offline.timers.size,1,'Recovery schedules retry without opening shop');
  offline.failRead(false);
  await [...offline.timers.values()][0].fn();
  assert.equal(offline.view().paid_skips,5,'Automatic startup retry restores pending credits');
  const a=await setup({backend:{data:{},pending:[{productID:'skips_5',purchaseToken:'initial'},
    {productID:'unlock_world_03',purchaseToken:'world'}, {productID:'old_unknown',purchaseToken:'unknown'}],next:0}});
  assert.equal(a.view().paid_skips,5,'Startup recovery without opening shop');
  assert.deepEqual(a.view().owned,['unlock_world_03']);
  assert.deepEqual(a.backend.pending.map(p=>p.purchaseToken),['world','unknown'],'Never consume permanent/unknown products');
  assert(a.calls.indexOf('save') < a.calls.indexOf('consume:initial'));
  await a.api.refresh(); assert.equal(a.view().paid_skips,5,'Repeated recovery is idempotent');
  assert.equal(a.view().catalog[0].currencyImage,'https://example.test/currency.png');
  assert((await a.api.buy('skips_5')).ok); assert.equal(a.view().paid_skips,10);
  assert((await a.api.spend(path(6))).ok); assert.equal(a.view().paid_skips,9);
  assert((await a.api.spend(path(6))).ok); assert.equal(a.view().paid_skips,9,'Same level cannot spend twice');
  const stale = await setup();
  await stale.api.buy('skips_5');
  stale.staleData({});
  await stale.api.refresh();
  assert.equal(stale.view().paid_skips,5,'Stale read preserves acknowledged credits');
  assert((await stale.api.spend(path(7))).ok);
  assert.equal(stale.view().paid_skips,4,'Spending after stale read deducts exactly one');
  await stale.api.refresh();
  assert.equal(stale.view().paid_skips,4,'Stale read cannot resurrect spent credits');
  const reopened=await setup({backend:a.backend});
  assert.equal(reopened.view().paid_skips,9); assert.deepEqual(reopened.view().paid_skipped,[path(6)]);
  assert(!((await reopened.api.spend('bad')).ok));
  a.failWrite(true); const writesBefore=a.calls.filter(c=>c.startsWith('consume:')).length;
  assert(!(await a.api.buy('skips_5')).ok);
  assert.equal(a.calls.filter(c=>c.startsWith('consume:')).length,writesBefore,'Failed grant must remain pending');
  a.failWrite(false); await a.api.refresh(); assert.equal(a.view().paid_skips,14);
  a.failConsume(true); assert(!(await a.api.buy('skips_5')).ok);
  assert.equal(a.view().paid_skips,19,'Credits persisted even if consume fails');
  a.failConsume(false); await a.api.refresh(); assert.equal(a.view().paid_skips,19,'Consume retry grants no extra credits');
  a.lostWrite(true); assert(!(await a.api.buy('skips_5')).ok);
  a.lostWrite(false); await a.api.refresh(); assert.equal(a.view().paid_skips,24,'Lost save acknowledgment cannot double grant');
  a.lostBuy(true); await a.api.buy('skips_5'); assert.equal(a.view().paid_skips,29,'Lost checkout response recovered');
  a.lostBuy(false); a.cancel(true); await a.api.buy('skips_5'); assert.equal(a.view().paid_skips,29,'Cancellation grants nothing'); a.cancel(false);
  a.failRead(true); assert(!(await a.api.refresh()).ok); assert.equal(a.view().ready,false);
  a.failRead(false); await a.api.refresh();
  const double=await Promise.all([a.api.buy('skips_5'), a.api.buy('skips_5')]);
  assert.equal(double.filter(r=>r.ok).length,1,'Rapid double click opens one checkout');
  assert.equal(a.maxWrites(),1,'Writes serialized');
  assert((await a.api.buy('unlock_all_levels')).ok);
  const before=a.calls.filter(c=>c.startsWith('buy:')).length;
  assert(!(await a.api.buy('skips_5')).ok); assert(!(await a.api.buy('unlock_world_03')).ok);
  assert.equal(a.calls.filter(c=>c.startsWith('buy:')).length,before,'Owned all blocks redundant purchases');
  assert(!(await a.api.spend(path(7))).ok,'Unlock all blocks redundant paid skip');
  assert(a.backend.pending.some(p=>p.productID==='unlock_all_levels'));
  a.owner('bob'); await a.api.refresh();
  assert.equal(a.view().error,'account_changed'); assert.equal(a.view().paid_skips,0); assert.deepEqual(a.view().owned,[]);
  console.log('Yandex purchases: startup recovery, durable grant-before-consume, retry deduplication, permanent ownership, paid spending, reload, lost responses, cancellation, account isolation and double-click guard passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
