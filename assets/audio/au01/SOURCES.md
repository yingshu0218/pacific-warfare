# AU01 original audio sources

Task date: 2026-11-10. Zero spending, zero accounts, zero audio/API services,
zero downloaded recordings. All 17 representative sounds are newly authored
local procedural signals, not recordings of historical engines or weapons.

The generator is `tools/audio/build_au01.py` (Python standard library). Its
asset-specific deterministic seeds, design descriptions, mastering rules and
source hash are preserved in `source/recipe.json`. Existing local FFmpeg only
encodes the two environment exports and four audition previews. No network
input, pretrained sound model, external library or other game's/film's audio
is used.

Provenance chain for each asset:

1. Generator and recipe with fixed seed and source-code hash.
2. `source/`: original generated 48 kHz, 24-bit PCM WAV.
3. `masters/`: DC-controlled, peak-trimmed 48 kHz, 24-bit PCM WAV.
4. `runtime/`: candidate mono 48 kHz/16-bit WAV or stereo Vorbis environment.
5. `docs/audio/au01-asset-manifest.json`: paths, hashes, format expectations,
   loop sample boundaries, origin, listening and integration status.
6. `docs/audio/au01-checks.json`: independent measurements of the actual files.

The complete AU01 candidate pack carries a root `.gdignore`, and source/master
directories have their own markers. This keeps unreviewed material out of
normal Godot import while other tasks continue. The current game still uses
the existing procedural bank. AU02 must explicitly admit selected runtime
files, apply the manifest's [begin, end) loop sample interval, retain Web
`PLAYBACK_TYPE_STREAM` and idempotent pause, and verify in the current game.

The four previews under `docs/audio/au01/preview/` are offline authored
audition timelines. Their salvo, gunfire, flypast and shore-scene timing is
explicit staging for material review, not a record of simulated gameplay.

Ownership/licensing follows the project's existing authorization. This task
does not grant a new public/open license or change the project's overall
license. In particular, these files are not newly labeled CC0, public domain,
or exact F6F/A6M/naval-gun recordings.

Automated format, level, boundary and rebuild checks are separate from hearing
acceptance. The authoring agent has not heard these files; subjective timbre,
fatigue and scene balance remain for an equipped reviewer. See
`docs/audio/AU01-delivery.md` for the measured results and outstanding scope.
