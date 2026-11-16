# presence_edit

## Then 0. Encode packets to Snapshot

1 when the body has passed a stage of the presence slice.

1. Encode packets. not timed. Sets packet.
2. Routed? Then goes to: model, relay.
3. Route model. not timed. Reads packet from Encode packets. Sets routed.
4. Route relay. not timed. Reads packet from Encode packets. Sets routed. Not taken in this plan.
5. Seal and take. not timed. Reads routed from Route model or Route relay. Sets sealed.
6. Judge. not timed. Reads sealed from Seal and take. Sets judged.
7. Agreed? Then goes to: agree, passthrough.
8. Agree. not timed. Reads judged from Judge. Sets agreed.
9. Skip agree. not timed. Reads judged from Judge. Sets agreed. Not taken in this plan.
10. Play curve. not timed. Reads agreed from Agree or Skip agree. Sets played.
11. Fit anny. not timed. Sets fitted.
12. Follow. not timed. Reads fitted from Fit anny, played from Play curve. Sets posed.
13. Snapshot. not timed. Reads posed from Follow. Sets snapshot.

