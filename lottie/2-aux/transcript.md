# presence_edit

## Then 0. Relabel coco to Rig aux parts

1 when a step of the AUX part-labelling and rigging route is done: coco_relabelled, synth_set, part_detector,
unit_cube_source, part_labels, warp_built, motion_lag, hair_cards, spring_chains, scale_sidecar; composites
labelled_parts, soft_rigid_known and rigged; also usd_stage (the source ingested into OpenUSD in its own units) and …

1. Relabel coco. 7.81 s. Sets coco_relabelled.
2. Make synth set. 8 min 32 s. Sets synth_set.
3. Train part detector. 19 min 24 s · GPU. Reads coco_relabelled from Relabel coco, synth_set from Make synth set. Sets part_detector, GPU.
4. Source_mesh? Then goes to: dataset, from-image.
5. Use dataset mesh. 1 s est. Sets source_mesh.
6. Pixal3d image to mesh. not timed · GPU. Reads GPU from Train part detector. Sets source_mesh, GPU. Not taken in this plan.
7. Ingest usd. 658 ms. Reads source_mesh from Use dataset mesh or Pixal3d image to mesh. Sets usd_stage.
8. Unitise source. 698 ms. Reads usd_stage from Ingest usd. Sets unit_cube_source.
9. Segment labels. 1 min est. · GPU. Reads GPU from Pixal3d image to mesh, part_detector from Train part detector, unit_cube_source from Unitise source. Sets part_labels, GPU.
10. Write scale sidecar. 423 ms. Reads unit_cube_source from Unitise source. Sets scale_sidecar.
11. Restore units. 741 ms. Reads part_labels from Segment labels, scale_sidecar from Write scale sidecar. Sets metric_labels.
12. Close labelling. 0 s. Reads metric_labels from Restore units. Sets labelled_parts.
13. Build warp. 30 min est. Sets warp_built.
14. Measure motion lag. 60 min est. · GPU. Reads GPU from Segment labels, part_labels from Segment labels, warp_built from Build warp. Sets motion_lag, GPU.
15. Soft_rigid_known? Then goes to: decide-soft-or-rigid, decide-by-class-prior.
16. Classify soft rigid. 1 s est. Reads labelled_parts from Close labelling, motion_lag from Measure motion lag. Sets soft_rigid_known.
17. Classify by class prior. 1 s est. Reads labelled_parts from Close labelling. Sets soft_rigid_known, soft_rigid_prior_only. Not taken in this plan.
18. Make hair cards. 21.082 s. Sets hair_cards.
19. Make spring chains. 2 s. Reads hair_cards from Make hair cards, scale_sidecar from Write scale sidecar. Sets spring_chains.
20. Rig aux parts. 1 min est. Reads labelled_parts from Close labelling, soft_rigid_known from Classify soft rigid or Classify by class prior, spring_chains from Make spring chains. Sets rigged.

