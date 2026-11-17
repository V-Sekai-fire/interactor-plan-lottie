# presence_edit

## Then 0. Drain sockets to Wait for next tick

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

