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
14. Load qwen25vl conditioner. 3.202 s · GPU. Sets qwen25vl_conditioner, GPU.
15. Load omnigen2 vae. 97 ms · GPU. Reads GPU from Load qwen25vl conditioner. Sets omnigen2_vae, GPU.
16. Load omnigen2 transformer. 3.26 s · GPU. Reads GPU from Load omnigen2 vae. Sets omnigen2_transformer, GPU.
17. Load editscore lora. 6 ms. Sets editscore_lora.
18. Merge editscore lora. 174 ms · GPU. Reads GPU from Load omnigen2 transformer, omnigen2_transformer from Load omnigen2 transformer, editscore_lora from Load editscore lora. Sets editscore_merged, GPU.
19. Edit. 1 min 7 s · GPU. Reads GPU from Merge editscore lora, snapshot from Snapshot, qwen25vl_conditioner from Load qwen25vl conditioner, omnigen2_transformer from Load omnigen2 transformer, omnigen2_vae from Load omnigen2 vae, editscore_merged from Merge editscore lora. Sets edited, GPU.
20. Score. 21.45 s · GPU. Reads GPU from Edit, edited from Edit. Sets scored, GPU.

