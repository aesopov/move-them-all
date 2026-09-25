# Resuming a game

The progress record now includes a timestamped `current_run`. Yandex stores it
with scores and skipped levels using the existing `PairUpSave` bridge. Scores
merge by maximum; the run uses the newest timestamp, including empty tombstones
after completion. Account-scoped journals prevent one player's checkpoint being
loaded into another account.

Checkpoints capture item positions (including removed item IDs), locks, terrain,
move count, elapsed active time, timer status and the most recent 20 undo steps.
The original level supplies immutable item properties and transport rules. A
level-file fingerprint rejects checkpoints from an older edited level layout.
Restart still uses the original board, and goal counts retain removed pieces.

Save after each logical move (before animations), undo, initial settling and
restart; also every five seconds of active play, on focus loss, pause and return
to level selection. Saving before animations makes a close during an animation
resume at the fully resolved move. Offline time does not advance the timer.
Designer test sessions do not save or replace campaign checkpoints.

Yandex startup automatically resumes a valid checkpoint from the welcome screen.
A delayed cloud read can also resume while still on that screen, but never
interrupts a level or level selection. Selecting the saved level also resumes it.
Completion writes a tombstone so an older cloud copy cannot resurrect the run.

The bridge journals synchronously and coalesces cloud writes (at least 3.5 seconds
apart), with offline retries. An OS kill may interrupt the latest network upload:
same-device recovery uses the journal; another device gets the last synced state.
There is no dependency on an asynchronous unload request completing.

Validation:

```
node tools/test_yandex_progress.cjs
godot --headless --path . --script tools/test_checkpoints.gd
godot --headless --path . --script tools/test_resume_scene.gd
```

SDK reference: https://yandex.com/dev/games/doc/en/sdk/sdk-player
