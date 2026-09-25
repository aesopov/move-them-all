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
saved locally in `user://audio.cfg`; zero mutes effects. No background music yet.

These shared effects belong in the base game pack, independent of world packs.
Test browser audio after a user gesture; browser autoplay policies apply.
