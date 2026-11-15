# presence_edit

## Then 0. Encode packets to Score

1 when the body has passed a stage of the presence slice.

1. Encode packets. not timed. Sets packet.
2. Routed? Then goes to: model, relay.
3. Route model. not timed. Reads packet from Encode packets. Sets routed.
4. Route relay. not timed. Reads packet from Encode packets. Sets routed. Not taken in this plan.
5. Seal and take. not timed. Reads routed from Route model or Route relay. Sets sealed.
6. Judge. not timed. Reads sealed from Seal and take. Sets judged.
7. Agreed? Then goes to: agree, passthrough.
8. Agree. not timed. Reads judged from Judge. Sets agreed. Not taken in this plan.
9. Skip agree. not timed. Reads judged from Judge. Sets agreed.
10. Play curve. not timed. Reads agreed from Agree or Skip agree. Sets played.
11. Fit anny. not timed. Sets fitted.
12. Follow. not timed. Reads fitted from Fit anny, played from Play curve. Sets posed.
13. Snapshot. not timed. Reads posed from Follow. Sets snapshot.
14. Load qwen25vl conditioner. 4 s · GPU. Sets qwen25vl_conditioner, GPU.
15. Load omnigen2 vae. 1 s · GPU. Reads GPU from Load qwen25vl conditioner. Sets omnigen2_vae, GPU.
16. Load omnigen2 transformer. 4 s · GPU. Reads GPU from Load omnigen2 vae. Sets omnigen2_transformer, GPU.
17. Load editscore lora. 1 s. Sets editscore_lora.
18. Merge editscore lora. 1 s · GPU. Reads GPU from Load omnigen2 transformer, omnigen2_transformer from Load omnigen2 transformer, editscore_lora from Load editscore lora. Sets editscore_merged, GPU.
19. Edit. 1 min 7 s · GPU. Reads GPU from Merge editscore lora, snapshot from Snapshot, qwen25vl_conditioner from Load qwen25vl conditioner, omnigen2_transformer from Load omnigen2 transformer, omnigen2_vae from Load omnigen2 vae, editscore_merged from Merge editscore lora. Sets edited, GPU.
20. Score. 22 s · GPU. Reads GPU from Edit, edited from Edit. Sets scored, GPU.

## Then 1. Drain sockets to Wait for next tick

1 when a step of one relay tick is done: datagrams, person, offered, handled, ticked, caught_up, next_tick.

1. Drain sockets. not timed. Sets datagrams.
2. Identify sender. not timed. Reads datagrams from Drain sockets. Sets person.
3. Offer frame. not timed. Reads person from Identify sender, datagrams from Drain sockets. Sets offered.
4. Handled? Then goes to: forward, refuse.
5. Send to others. not timed. Reads offered from Offer frame. Sets handled.
6. Count refused. not timed. Reads person from Identify sender. Sets handled. Not taken in this plan.
7. Tick zones. not timed. Reads handled from Send to others or Count refused. Sets ticked.
8. Catch up if late. not timed. Reads ticked from Tick zones. Sets caught_up.
9. Wait for next tick. not timed. Reads caught_up from Catch up if late. Sets next_tick.

## Then 2. Relabel coco to Rig aux parts

1 when a step of the AUX part-labelling and rigging route is done: coco_relabelled, synth_set, part_detector,
unit_cube_source, part_labels, warp_built, motion_lag, hair_cards, spring_chains, scale_sidecar; composites
labelled_parts, soft_rigid_known and rigged; also usd_stage (the source ingested into OpenUSD in its own units) and …

1. Relabel coco. 10 s est. Sets coco_relabelled.
2. Make synth set. 8 min 32 s. Sets synth_set.
3. Train part detector. 19 min 24 s · GPU. Reads GPU from Score, coco_relabelled from Relabel coco, synth_set from Make synth set. Sets part_detector, GPU.
4. Source_mesh? Then goes to: dataset, from-image.
5. Use dataset mesh. 1 s est. Sets source_mesh.
6. Pixal3d image to mesh. not timed · GPU. Reads GPU from Train part detector. Sets source_mesh, GPU. Not taken in this plan.
7. Ingest usd. 5 s est. Reads source_mesh from Use dataset mesh or Pixal3d image to mesh. Sets usd_stage.
8. Unitise source. 2 s est. Reads usd_stage from Ingest usd. Sets unit_cube_source.
9. Segment labels. 1 min est. · GPU. Reads GPU from Pixal3d image to mesh, part_detector from Train part detector, unit_cube_source from Unitise source. Sets part_labels, GPU.
10. Write scale sidecar. 2 s est. Reads unit_cube_source from Unitise source. Sets scale_sidecar.
11. Restore units. 5 s est. Reads part_labels from Segment labels, scale_sidecar from Write scale sidecar. Sets metric_labels.
12. Close labelling. 0 s. Reads metric_labels from Restore units. Sets labelled_parts.
13. Build warp. 30 min est. Sets warp_built.
14. Measure motion lag. 60 min est. · GPU. Reads GPU from Segment labels, part_labels from Segment labels, warp_built from Build warp. Sets motion_lag, GPU.
15. Soft_rigid_known? Then goes to: decide-soft-or-rigid, decide-by-class-prior.
16. Classify soft rigid. 1 s est. Reads labelled_parts from Close labelling, motion_lag from Measure motion lag. Sets soft_rigid_known.
17. Classify by class prior. 1 s est. Reads labelled_parts from Close labelling. Sets soft_rigid_known, soft_rigid_prior_only. Not taken in this plan.
18. Make hair cards. 1 min 28 s. Sets hair_cards.
19. Make spring chains. 2 s. Reads hair_cards from Make hair cards, scale_sidecar from Write scale sidecar. Sets spring_chains.
20. Rig aux parts. 1 min est. Reads labelled_parts from Close labelling, soft_rigid_known from Classify soft rigid or Classify by class prior, spring_chains from Make spring chains. Sets rigged.

## Then 3. Bake course to Finish course

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

