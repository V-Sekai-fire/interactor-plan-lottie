# presence_edit

## Then 0. Fetch clips to Play curve

1 when the body has passed a stage of the presence slice.

1. Fetch clips. not timed. Sets clips.
2. Encode packets. not timed. Reads clips from Fetch clips. Sets packet.
3. Routed? Then goes to: model, relay.
4. Route model. not timed. Reads packet from Encode packets. Sets routed.
5. Route relay. not timed. Reads packet from Encode packets. Sets routed. Not taken in this plan.
6. Seal and take. not timed. Reads routed from Route model or Route relay. Sets sealed.
7. Judge. not timed. Reads sealed from Seal and take. Sets judged.
8. Agreed? Then goes to: agree, passthrough.
9. Agree. not timed. Reads judged from Judge. Sets agreed. Not taken in this plan.
10. Skip agree. not timed. Reads judged from Judge. Sets agreed.
11. Play curve. not timed. Reads agreed from Agree or Skip agree. Sets played.

