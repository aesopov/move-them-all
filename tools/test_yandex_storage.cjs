const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const env={navigator:{}};env.window=env;
vm.runInNewContext(fs.readFileSync('web/yandex/storage.js','utf8'),env);
const clone=x=>JSON.parse(JSON.stringify(x));
let data={existing:true}, failRead=false,failWrite=false,writes=0,active=0,max=0;
const player={getUniqueID:()=> 'alice',getData:async()=>{if(failRead)throw Error('read');return clone(data);},
  setData:async value=>{active++;max=Math.max(max,active);await Promise.resolve();active--;if(failWrite)throw Error('write');data=clone(value);writes++;}};
(async()=>{
  await Promise.all([env.PairUpStorage.write(player,{progress:{score:10}}),env.PairUpStorage.write(player,{purchases:{credits:5}})]);
  assert.deepEqual(data,{existing:true,progress:{score:10},purchases:{credits:5}});
  assert.equal(max,1);
  failRead=true;await assert.rejects(env.PairUpStorage.write(player,{progress:{score:20}}));assert.equal(writes,2);
  failRead=false;failWrite=true;await assert.rejects(env.PairUpStorage.write(player,{purchases:{credits:4}}));assert.equal(data.purchases.credits,5);
  failWrite=false;await env.PairUpStorage.write(player,{progress:{score:20}});assert.equal(data.purchases.credits,5);
  console.log('Shared storage: concurrent writers, read/write failures, retry and unrelated fields passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
