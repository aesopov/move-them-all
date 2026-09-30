/* setData writes a player record: every writer must preserve unrelated keys.
 * Share one queue so a progress autosave cannot overwrite a purchase grant. */
(function () {
  'use strict';
  let tail = Promise.resolve();
  const clone = value => JSON.parse(JSON.stringify(value));
  window.PairUpStorage = {
    write(player, patch) {
      const update = clone(patch), owner = player.getUniqueID();
      const save = async () => {
        if (!owner || player.getUniqueID() !== owner) throw Error('account_changed');
        const current = await player.getData();
        if (!current || typeof current !== 'object' || Array.isArray(current)) throw Error('invalid_player_data');
        if (player.getUniqueID() !== owner) throw Error('account_changed');
        // Read failure must never result in writing an incomplete/default record.
        await player.setData({...current, ...update}, true);
      };
      const run = () => window.navigator?.locks
        ? window.navigator.locks.request('pair-up-player-data', save) : save();
      const result = tail.then(run, run);
      tail = result.catch(() => {});
      return result;
    }
  };
})();
