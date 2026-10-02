const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/yandex/analytics.js', 'utf8');
function setup(hostname = 'game.example', search = '', stored = null) {
  const scripts = [];
  const env = {location: {hostname, search, href: `https://${hostname}/${search}`}, URLSearchParams,
    localStorage: {getItem: () => stored}, document: {scripts, referrer: '',
      head: {appendChild: s => scripts.push(s)}, createElement: () => ({})}};
  env.window = env;
  vm.runInNewContext(source, env);
  return {env, scripts};
}
const payload = JSON.stringify({level: 'world_01/level_02', revision: 'a'.repeat(64), moves: 15, seconds: 32, resumed: false, score: 1000});
const {env, scripts} = setup();
assert.equal(scripts.length, 1);
assert.equal(scripts[0].async, true);
assert.equal(env.ym.a[0][0], 113340672);
assert.equal(env.ym.a[0][2].webvisor, false);
for (const event of ['level_started', 'level_completed', 'level_restarted', 'level_skipped', 'level_exited']) env.PairUpAnalytics.track(event, payload);
assert.equal(env.ym.a.length, 6);
assert.equal(env.ym.a[2][2], 'level_completed');
assert.equal(env.ym.a[2][3].levels['world_01/level_02']['a'.repeat(64)].level_completed.score, 1000);
for (const value of ['oops', '{}', JSON.stringify({level:'custom/test',revision:'a'.repeat(64)})]) env.PairUpAnalytics.track('level_started', value);
env.PairUpAnalytics.track('unknown', payload);
assert.equal(env.ym.a.length, 6);
env.ym = () => { throw Error('blocked'); };
assert.doesNotThrow(() => env.PairUpAnalytics.track('level_started', payload));
for (const args of [['localhost'], ['127.0.0.1'], ['game.example', '?purchase-testing=1'], ['game.example', '', '1']]) {
  const test = setup(...args);
  test.env.PairUpAnalytics.track('level_started', payload);
  assert.equal(test.scripts.length, 0);
  assert.equal(test.env.ym, undefined);
}
console.log('Metrica: counter, five events, revision breakdown, blocked delivery and test exclusion passed');
