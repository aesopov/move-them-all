const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
class Element {
  constructor(tag) { this.tag = tag; this.children = []; this.textContent = ''; }
  appendChild(child) { this.children.push(child); }
  replaceChildren() { this.children = []; }
  setAttribute() {}
  addEventListener() {}
  focus() {}
  remove() {}
  querySelectorAll() { return this.children.flatMap(c => [...(c.tag === 'button' ? [c] : []), ...c.querySelectorAll()]); }
}
const body = new Element('body');
const state = {ready:true, busy:false, paying:false, paid_skips:99, owned:[], catalog:[{id:'skips_5',title:'Five skips',description:'Skip levels',price:'50'}]};
let listener, finish;
const api = {
  snapshot: () => JSON.stringify(state),
  listen: fn => listener=fn,
  setModal: () => listener(),
  refresh: () => { state.busy=true; listener(); return new Promise(resolve=>finish=resolve); }
};
const context = {window:{PairUpPurchases:api},document:{body,head:new Element('head'),createElement:tag=>new Element(tag),getElementById:()=>null},GodotYandexBridge:{refocusCanvas(){}}};
vm.runInNewContext(fs.readFileSync('web/yandex/shop.js','utf8'),context);
(async()=>{
  api.openShop('["skips_5"]');
  const panel=body.children[0].children[0], status=panel.children[1], list=panel.children[2];
  assert.equal(list.children.length,0,'Never render the cached balance on open');
  assert.equal(status.textContent,'Checking purchases…');
  state.ready=false; state.paid_skips=0; listener();
  assert.equal(list.children.length,0,'Intermediate empty recovery data stays hidden');
  state.ready=true; state.busy=false; state.paid_skips=5; listener(); finish();
  await Promise.resolve(); await Promise.resolve();
  assert.equal(list.children[0].textContent,'Purchased skips: 5');
  const card=list.children[1];
  state.busy=true; listener();
  assert.equal(list.children[1],card,'Background refresh preserves card DOM');
  assert(list.querySelectorAll().every(button=>button.disabled),'No purchase during refresh');
  console.log('Shop: loading first, no intermediate balances, stable cards during refresh passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
