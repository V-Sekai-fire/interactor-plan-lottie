# presence_edit

## Then 0. Bake course to Finish course

1 when a step of the obstacle course is done: clips_baked, clips_on_model, shapes_baked, colliders_checked,
input_ready, clip_picked, posed, grounded, muscle_driven, avatar_follows, finished.

1. Bake course. not timed. Sets shapes_baked.
2. Check colliders. not timed. Reads shapes_baked from Bake course. Sets colliders_checked.
3. Bake clips. not timed. Sets clips_baked.
4. Rig clips on model. not timed. Reads clips_baked from Bake clips. Sets clips_on_model.
5. Input_ready? Then goes to: keyboard or pad, VMC capture.
6. Read keyboard or pad. not timed. Sets input_ready.
7. Read vmc capture. not timed. Sets input_ready. Not taken in this plan.
8. Pick clip. not timed. Reads clips_baked from Bake clips, input_ready from Read keyboard or pad or Read vmc capture. Sets clip_picked.
9. Play clips. not timed. Reads clips_on_model from Rig clips on model, clip_picked from Pick clip. Sets posed.
10. Hold at walls. not timed. Reads colliders_checked from Check colliders, posed from Play clips. Sets grounded.
11. Drive muscles. not timed. Reads grounded from Hold at walls. Sets muscle_driven.
12. Follow muscle skeleton. not timed. Reads muscle_driven from Drive muscles. Sets avatar_follows.
13. Finish course. not timed. Reads avatar_follows from Follow muscle skeleton. Sets finished.

