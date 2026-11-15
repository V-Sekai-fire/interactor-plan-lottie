# interactor-plan-lottie

A Lottie animation of the poseswap plan, drawn like Unreal Engine Blueprints, and the script that draws it.

The animation has three scenes, 42.7 s in all (1680 x 720, 30 frames a second). A camera follows the node that is running, so only part of the graph shows at a time:

- White pins and wires are the sequence: the order the planner runs the steps. An alternative is a Branch node.
- Coloured pins are facts. A step's inputs are on its left (facts it reads) and its outputs on its right (facts it sets). A wire joins the step that sets a fact to the step that reads it. The red GPU pin is passed from one GPU step to the next, so GPU steps take turns.
- A line at the foot of a node counts the facts the desk states and no step sets.

1. The presence slice: motion clips, packets, routing (the zone-router model or the relay), seal, judge, agree, play the curve, fit and follow the avatar, snapshot, then the OmniGen2 edit and the EditScore score.
2. Inside the relay: the loop of `transport-zone-relay` that runs 64 times a second, taken from that repository's `docs/zone-net.md` and `docs/zone-relay.md`.
3. The AUX route: from an image or a mesh to labelled, rigged garment parts, with the longest chain in red.

## What is here

| Path | What it holds |
| --- | --- |
| `poseswap-plan.lottie.json` | the animation |
| `tools/make_poseswap_lottie.py` | the script that draws it |
| `plans/aux-route-ready.plan.json` | the planner's plan that scene 3 is drawn from |
| `viewer.html` | a page that plays the JSON |

## Rebuild it

The domain is not copied here. It lives in `V-Sekai-fire/3d-character-poseswap`, and the animation was drawn from commit `d5a66b6` (branch `dev/image-route`), with the plan made by `persona_plan` from `interactor-taskweft-persona`.

    cd 3d-character-poseswap
    bash tools/aux.sh plan /aux/rigged problems/aux-route-ready.jsonld     # writes out/plan.json
    python3 ../interactor-plan-lottie/tools/make_poseswap_lottie.py domains/presence-edit.jsonld out/plan.json ../interactor-plan-lottie/poseswap-plan.lottie.json

Scenes 1 and 3 are drawn from the domain, so a step added to it shows up on a redraw. Scene 2 is drawn by hand from the relay's docs, so it does not follow the domain.

The planner runs independent steps side by side, and the white wire lists them one after another. Its sequence is the planner's step order, not a schedule.

## What it does not have

- Times for most of the presence slice. Only the model loads, the edit and the score have been timed, so the others say "not timed". Image-to-mesh and matting are not timed either, so the 91 minutes of scene 3 leaves them out.
- A link from scene 1 to scene 3. The domain does not connect the edited image to the garment image, so no rail is drawn.
- The relay numbers are the repository's own, measured at 256 people on Linux with two shared vCPUs, on loopback. They are not a real network.
- A check in any player but lottie-web. The text is Arial, so a player without system fonts may letter it differently.

## Licence

MIT. See [LICENSE](LICENSE).
