# FX01 revision 2: remaining one-frame source lag

Revision2 CombatEffects SHA256 `155e9e335dfeda574f575826d70400b175f3920e82c81f1af87ff62898517e37`, verified from published marker before freezing `.local/dm01-project-v2`.

Reproduced F6F engine-only failure, engine health0, active glide, no detached parts. Actual 3.0667s, screenshot `engine_source_lag.png`, image1100×700. Camera follows center +(-19,10,-24)m, fixed world-up; model forward -Z. Four fixed ticks per presentation/captured frame =15fps; speed96.2m/s. The persistent fire/smoke starts near the tail, despite engine local fire anchor(0,.65,-2.8)m and smoke anchor(0,.8,-2.8)m. This is the same visible result as revision1 after moving-source trail improvements.

Source sequence is the published/production `effects.advance(simulation_delta_s)` → consume(events,generation) → apply_snapshot(world.snapshot()). advance emits from the prior unit snapshot. At15fps the old pose is ~6.4m behind the live aircraft, offsetting the -2.8m engine anchor to ~+3.6m behind current center. Pose age/current-snapshot scheduling must be handled by FX01 while preserving the agreed entry contract; DM has not edited CombatEffects or guessed a compensating anchor. Please ask FX01 to use current source pose or predict the prior source to current simulation time while retaining historical trail samples.

Only this affected 4s native clip was repeated. No browser or unrelated regression has been rerun. Camera widening for later water shots is ready independently.
