# Sound effects

Original procedural effects created for Pair Up. Regenerate with
`python3 tools/generate_sounds.py` (Python standard library only).
No recordings, external samples or third-party licenses are involved.

Ten short mono 22.05 kHz WAV files total about 197 KiB before Godot import:
select, move, match, unlock, pipe, teleport, splash, sizzle, bomb, complete.
The palette combines soft percussive clicks, bell tones and filtered noise.
Sources have peak headroom and fade envelopes to prevent clipping and clicks.

`Sound` caches imported streams and uses eight reusable players, with a 90 ms
per-effect cooldown for simultaneous clears. Effects follow animation callbacks;
automatic gravity movement is silent until an interaction occurs. Playback uses
Master, so the existing platform/ad mute also covers these sounds, and active
effects stop on application focus loss. The pause menu's sound volume slider is
saved locally in `user://audio.cfg`; zero mutes effects independently of music.

These shared effects belong in the base game pack, independent of world packs.
Test browser audio after a user gesture; browser autoplay policies apply.


## Background music

User-supplied Suno MP3s are copied unchanged from Downloads into `music/`:

- `rippling_arpeggios.mp3` — Rippling Arpeggios, about 3:10. Menus and worlds without a dedicated track.
- `sunlit_mystery.mp3` — Sunlit Mystery, about 2:55. Desert Temple.

`Sound` owns one persistent looping music player, with a brief fade out/in when
tracks change. Moving between levels with the same track does not restart it.
The music defaults to enabled at 35% volume, with an additional 6 dB of headroom.
Turning music off or setting volume to zero pauses the track; enabling it resumes
from the same position. The original MP3s are not transcoded. Looping repeats the
whole track; these are not separately edited seamless musical loops.

Audio settings are available from the welcome screen and the gameplay pause menu.
The shared `AudioSettings` controls expose SFX volume, a music toggle, and music
volume. All seven UI languages are covered. Both volume settings and the music
switch persist independently in `user://audio.cfg`. Existing SFX settings migrate
without resetting their saved value.

Browser music waits for the first tap, mouse press, or keypress. Focus loss,
application suspension and Yandex platform/shop pause all pause the music;
returning respects the enabled/volume preferences. An ordinary in-game pause
keeps music playing so the settings can be heard while adjusting them.

Web exports put each track and its Godot import in a separate hashed `music_*`
pack. Music downloads in the background, is cached using the existing asset-pack
loader, yields to level downloads, and retries failures without blocking gameplay.
Native/editor exports use the local imported files. The Yandex ZIP includes both
music packs and remains self-contained.

Validation: `godot --headless --path . --script tools/test_music.gd` covers track
selection/continuity, looping, independent preferences, toggling, platform/focus
pauses, persistence, and first-gesture startup. `python3 tools/test_web_split.py`
checks that music imports leave the bootstrap and are not decoded as textures.
