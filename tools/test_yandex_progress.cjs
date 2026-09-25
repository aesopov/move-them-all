const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('web/yandex/platform.js', 'utf8');
const path = n => `res://levels/world_01/level_0${n}.json`;
const tick = async () => { for (let i=0;i<30;i++) await Promise.resolve(); };
async function setup({cloud={}, failRead=false, failWrite=false, storage=new Map(), id='alice'}={}) {
  let readFailure=failRead, writeFailure=failWrite, now=100000, serial=0;
  const timers=new Map(), writes=[], calls=[];
  const player={getUniqueID:()=>id,
    getData:async()=>{calls.push('read');if(readFailure)throw Error('offline');return cloud;},
    setData:async(data,flush)=>{calls.push('write');assert.equal(flush,true);if(writeFailure)throw Error('offline');writes.push(data);}};
  const env={console:{warn(){}}, Date:{now:()=>now},
    localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
    document:{documentElement:{},addEventListener(){}}, addEventListener(){},
    setTimeout(fn,delay){const id=++serial;timers.set(id,{fn,at:now+delay});return id;},clearTimeout:id=>timers.delete(id),
    GodotYandexBridge:{ysdk:{getPlayer:async()=>player},init:(_,cb)=>cb(JSON.stringify({success:true,data:{environment:{i18n:{lang:'ru'}}}}))}};
  env.window=env;vm.runInNewContext(source,env);await tick();await env.mergeYandexReady;
  return {env,storage,writes,calls,
    recover(){readFailure=false;writeFailure=false;},
    async advance(ms){now+=ms;for(const [id,t] of [...timers])if(t.at<=now){timers.delete(id);t.fn();}await tick();}};
}
(async()=>{
  const a=await setup({cloud:{pairUpProgress:{scores:{[path(1)]:2000},skipped:[path(2)]}}});
  const loaded=JSON.parse(a.env.PairUpSave.load(JSON.stringify({[path(1)]:1000,[path(3)]:700})));
  assert.equal(loaded.scores[path(1)],2000);assert.equal(loaded.scores[path(3)],700);
  assert.deepEqual(loaded.skipped,[path(2)]);
  a.env.PairUpSave.save(JSON.stringify({scores:{[path(1)]:2500},skipped:[path(2),path(4)]}));
  a.env.PairUpSave.save(JSON.stringify({scores:{[path(1)]:2400},skipped:[path(4)]}));
  assert.equal(JSON.parse(a.storage.get('pairUpSave:alice')).scores[path(1)],2500);
  await a.advance(4000);assert.equal(a.writes.length,1);assert.equal(a.calls[0],'read');
  assert.deepEqual(Array.from(a.writes[0].pairUpProgress.skipped),[path(2),path(4)]);
  const b=await setup({failRead:true,cloud:{pairUpProgress:{scores:{[path(5)]:900},skipped:[path(1)]}}});
  b.env.PairUpSave.load('{}');b.env.PairUpSave.save(JSON.stringify({scores:{[path(2)]:1200},skipped:[path(3)]}));
  await b.advance(4000);assert.equal(b.writes.length,0,'Never overwrite unread cloud data');
  b.recover();await b.advance(30000);await b.advance(4000);
  assert.equal(b.writes[0].pairUpProgress.scores[path(5)],900);
  assert.equal(b.writes[0].pairUpProgress.scores[path(2)],1200);
  assert.equal(b.writes[0].pairUpProgress.skipped.length,2);
  const c=await setup({failWrite:true});c.env.PairUpSave.load('{}');
  c.env.PairUpSave.save(JSON.stringify({skipped:[path(1)]}));await c.advance(4000);
  assert.equal(c.writes.length,0);c.recover();await c.advance(15000);assert.equal(c.writes.length,1);
  const d=await setup({storage:a.storage,id:'bob'});
  const bob=JSON.parse(d.env.PairUpSave.load(JSON.stringify({[path(1)]:9999})));
  assert.deepEqual(bob.scores,{});assert.deepEqual(bob.skipped,[],'Other account does not inherit skips');
  const run = {updated_at: 101000, state: {path: path(2), board: {cells:[12,-1], locks:[0,0], terrain:[], moves:3}, elapsed:19}};
  a.env.PairUpSave.save(JSON.stringify({current_run:run}));
  assert.deepEqual(JSON.parse(a.storage.get('pairUpSave:alice')).current_run,run,'Checkpoint immediately journaled');
  const reopened = await setup({storage:a.storage,cloud:{pairUpProgress:{current_run:{...run,updated_at:100000}}}});
  assert.deepEqual(JSON.parse(reopened.env.PairUpSave.load('{}')).current_run,run,'Local latest survives older cloud');
  await reopened.advance(4000);
  assert.deepEqual(JSON.parse(JSON.stringify(reopened.writes[0].pairUpProgress.current_run)),run,'Checkpoint uploaded');
  const freshDevice = await setup({cloud:{pairUpProgress:{current_run:run}}});
  assert.deepEqual(JSON.parse(freshDevice.env.PairUpSave.load('{}')).current_run,run,'New device restores cloud checkpoint');
  reopened.env.PairUpSave.save(JSON.stringify({current_run:{updated_at:102000,state:{}}}));
  const completed = await setup({storage:reopened.storage,cloud:{pairUpProgress:{current_run:run}}});
  assert.deepEqual(JSON.parse(completed.env.PairUpSave.load('{}')).current_run.state,{},'Cleared run cannot resurrect');
  const other = await setup({storage:freshDevice.storage,id:'charlie'});
  assert.deepEqual(JSON.parse(other.env.PairUpSave.load('{}')).current_run.state,{},'Other account never inherits current run');
  console.log('Yandex progress: cloud merge, migration, coalescing, offline retry, checkpoint recovery, tombstones and account isolation passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
