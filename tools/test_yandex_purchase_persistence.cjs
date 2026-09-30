const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const clone = x => JSON.parse(JSON.stringify(x));
const backend = {data:{unrelated:{keep:true}}, pending:[], next:0};
const tick = async () => { for(let i=0;i<100;i++) await Promise.resolve(); };
async function boot() {
  const timers=new Map(); let serial=0;
  const player={getUniqueID:()=> 'alice',
    getData:async keys=>clone(keys ? Object.fromEntries(keys.filter(k=>k in backend.data).map(k=>[k,backend.data[k]])) : backend.data),
    setData:async data=>{await Promise.resolve(); backend.data=clone(data);}};
  const payments={getPurchases:async()=>clone(backend.pending),
    getCatalog:async()=>[{id:'skips_5',price:'50'}],
    purchase:async()=>{const p={productID:'skips_5',purchaseToken:`token-${++backend.next}`}; backend.pending.push(p); return p;},
    consumePurchase:async token=>{
      if (backend.pending.find(p=>p.purchaseToken===token)?.productID === "skips_5")
        assert(backend.data.pairUpPurchasesV1.receipts.includes(token));
      backend.pending=backend.pending.filter(p=>p.purchaseToken!==token);
    }};
  const sdk={getPlayer:async()=>player,getPayments:async()=>payments};
  const storage=new Map();
  const env={console,URLSearchParams,location:{search:""},navigator:{},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
    document:{documentElement:{},addEventListener(){}},addEventListener(){},
    setTimeout:(fn,ms)=>{const id=++serial;timers.set(id,{fn,ms});return id;},clearTimeout:id=>timers.delete(id),
    GodotYandexBridge:{ysdk:sdk,init:(_,cb)=>cb(JSON.stringify({success:true,data:{environment:{i18n:{lang:'en'}}}}))}};
  env.window=env;
  for(const file of ['storage.js','purchases.js','platform.js']) {
    if(fs.existsSync('web/yandex/'+file)) vm.runInNewContext(fs.readFileSync('web/yandex/'+file,'utf8'),env);
  }
  await tick(); await env.mergeYandexReady; await tick();
  return {env,async flush(){for(const [id,t] of [...timers]) if(t.ms<6000){timers.delete(id);t.fn();}await tick();}};
}
(async()=>{
  const first=await boot();
  assert((await first.env.PairUpPurchases.buy('skips_5')).ok);
  first.env.PairUpSave.save(JSON.stringify({scores:{'res://levels/world_01/level_01.json':1000}}));
  await first.flush();
  const second=await boot();
  assert.equal(JSON.parse(second.env.PairUpPurchases.snapshot()).paid_skips,5,'Purchase survives progress autosave and fresh session without local storage');
  const path='res://levels/world_01/level_02.json';
  assert((await second.env.PairUpPurchases.spend(path)).ok);
  await second.flush();
  const third=await boot();
  const state=JSON.parse(third.env.PairUpPurchases.snapshot());
  assert.equal(state.paid_skips,4);
  assert.deepEqual(state.paid_skipped,[path]);
  assert.equal(backend.data.pairUpProgress.scores['res://levels/world_01/level_01.json'],1000);
  assert.deepEqual(backend.data.unrelated,{keep:true});
  assert(!(await third.env.PairUpPurchases.reset()).ok, 'Reset hidden and blocked without testing opt-in');
  third.env.localStorage.setItem('pairUpPurchaseTesting','1');
  backend.pending.push({productID:'unlock_all_levels',purchaseToken:'all-test'});
  assert((await third.env.PairUpPurchases.reset()).ok);
  assert.equal(JSON.parse(third.env.PairUpPurchases.snapshot()).paid_skips,0);
  const afterReset=await boot();
  assert.equal(JSON.parse(afterReset.env.PairUpPurchases.snapshot()).paid_skips,0,'Reset survives restart');
  assert.deepEqual(backend.data.pairUpProgress.paid_skipped,[]);
  assert.equal(backend.data.pairUpProgress.scores['res://levels/world_01/level_01.json'],1000);
  assert.equal(backend.pending.length,0,'Permanent test unlock consumed');
  console.log('Integrated persistence: buy → autosave → fresh session → spend → autosave → fresh session passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
