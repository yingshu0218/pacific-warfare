# FX01 revision 1 integration observation

Frozen input: `docs/showcase/evidence/DM01/frozen-input.json`, FX01 revision1 / CombatEffects 3e7d161e… . Actual F6F engine hits at1.0167s, engine=0, no wing break, active glide. Capture uses published advance → consume → apply_snapshot once per captured frame, four real ticks = 1/15s.

At3.0667s `engine_source_lag.png` shows the persistent engine fire at the tail rather than engine/nose. Authoritative engine emitter is local (0,.65,-2.8); plane travels ~6.4m per presented frame, so prior-snapshot source + anchor appears ~3.6m behind current center. This is a rendering sample-age issue, not DM part selection. Please have FX01 keep its ownership and account for current simulation delta/velocity while preserving the published entry order. Do not fix by changing historical model anchors or damage state. Need a refreshed freeze marker and targeted rerender of engine/smoke clips; no Chrome has run yet.

`single_wing_3s.png` confirms correct independent marked wing separation and continuously rotating main body. `water_close_9s.png` is a close review camera (~33m), actual single unit_impact at7.6167s, and shows the tall plume clipped at the top; DM review camera will widen for the water phase so complete motion is inspectable. FX01 may judge its own mesh style from this image; DM does not edit it.
