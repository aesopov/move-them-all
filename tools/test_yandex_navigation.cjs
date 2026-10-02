const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const entries = [{external: true}, {otherState: 42}];
let index = 1, popstate, backs = 0;
const env = {
  history: {
    get state() { return entries[index]; },
    replaceState(state) { entries[index] = state; },
    pushState(state) { entries.splice(++index, entries.length, state); }
  },
  addEventListener(name, fn) { assert.equal(name, 'popstate'); popstate = fn; }
};
env.window = env;
vm.runInNewContext(fs.readFileSync('web/yandex/navigation.js', 'utf8'), env);
const nav = env.PairUpNavigation;
nav.subscribe(() => backs++);
const back = () => { index--; if (index > 0) popstate(); };
nav.setLevelActive(true);
assert.equal(entries.length, 3, 'Direct launch creates a menu destination');
assert.equal(env.history.state.otherState, 42, 'Preserves unrelated history state');
back();
assert.equal(backs, 1, 'Android Back reaches Godot without leaving the iframe');
back();
assert.equal(backs, 2, 'Back remains protected while Godot waits for loading/ad completion');
nav.setLevelActive(false);
for (let i = 0; i < 20; i++) {
  nav.setLevelActive(true);
  nav.setLevelActive(false);
}
assert.equal(entries.length, 3, 'UI back/replay does not accumulate history');
back();
assert.equal(backs, 2, 'Menu Back does not request another scene change');
nav.setLevelActive(true);
assert.equal(entries.length, 3, 'Starting after a menu Back arms navigation again');
back();
nav.setLevelActive(false);
back(); back();
assert.equal(index, 0, 'Menu allows leaving for the host instead of trapping users');
console.log('Navigation: direct launch, Back, delayed exit, replay, and menu exit passed');
