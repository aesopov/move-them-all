const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
let callbacks, refocus=0, requests=0, mode='normal';
const env={GodotYandexBridge:{refocusCanvas(){refocus++;},ysdk:{adv:{showFullscreenAdv(options){requests++;if(mode==='throw')throw Error('offline');callbacks=options.callbacks;if(mode==='immediate')callbacks.onClose(false);}}}}};
env.window=env;vm.runInNewContext(fs.readFileSync('web/yandex/ads.js','utf8'),env);
const results=[];
env.PairUpAds.show(x=>results.push(x));
callbacks.onOpen();assert.deepEqual(results,[],'Action waits while ad is open');
env.PairUpAds.show(x=>results.push(x));assert.equal(requests,1,'Double click cannot open a second ad');
callbacks.onClose(true);callbacks.onError({});assert.deepEqual(results,['busy','closed'],'Terminal callback happens once');
for(const terminal of ['onError','onOffline']){env.PairUpAds.show(x=>results.push(x));callbacks[terminal]();callbacks.onClose(false);}
assert.deepEqual(results.slice(2),['error','offline']);
mode='immediate';env.PairUpAds.show(x=>results.push(x));assert.equal(results.at(-1),'not_shown');
mode='throw';env.PairUpAds.show(x=>results.push(x));assert.equal(results.at(-1),'error');
assert.equal(refocus,5);
console.log('Fullscreen ads: close, no-fill, error, offline, exception and duplicate callbacks passed');
(async()=>{
  const tick=()=>new Promise(r=>setImmediate(r));
  async function scenario(status, owned=[], ready=true) {
    let state={ready,owned}, listener, release;
    const banners=[], fullscreen=[];
    const sdk={adv:{
      async showBannerAdv(){banners.push('show');if(release===true)await new Promise(r=>release=r);},
      async hideBannerAdv(){banners.push('hide');},
      showFullscreenAdv({callbacks}){fullscreen.push(1);callbacks.onClose(false);}
    }};
    const context={window:null,GodotYandexBridge:{ysdk:sdk,refocusCanvas(){}},PairUpPurchases:{snapshot:()=>JSON.stringify(state),listen(fn){listener=fn;}}};
    context.window=context;
    vm.runInNewContext(fs.readFileSync('web/yandex/ads.js','utf8'),context);
    await context.PairUpAds.init(sdk,{getPayingStatus:()=>status});await tick();
    return {banners,fullscreen,api:context.PairUpAds,change(s){state=s;listener();},hold(){release=true;},release(){release();}};
  }
  for(const status of ['not_paying','partially_paying','unknown']){
    const a=await scenario(status);assert.deepEqual(a.banners,['hide','show']);
  }
  const paying=await scenario('paying');assert.deepEqual(paying.banners,['hide']);
  paying.api.show(()=>{});assert.equal(paying.fullscreen.length,1,'Paying status only suppresses banners');
  const owned=await scenario('not_paying',['disable_ads']);assert.deepEqual(owned.banners,['hide']);
  owned.api.show(x=>assert.equal(x,'disabled'));assert.equal(owned.fullscreen.length,0);
  const pending=await scenario('not_paying',[],false);assert.deepEqual(pending.banners,['hide']);
  pending.hold();pending.change({ready:true,owned:[]});await tick();
  pending.change({ready:true,owned:['disable_ads']});pending.release();await tick();
  assert.deepEqual(pending.banners,['hide','show','hide'],'Purchase hides even an in-flight banner');
  pending.change({ready:true,owned:[]});await tick();assert.equal(pending.banners.at(-1),'show','Test reset restores banners');
  console.log('Ad policy: all paying statuses, recovery gate, permanent entitlement, reset and in-flight banner race passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
