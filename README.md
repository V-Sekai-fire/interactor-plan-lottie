# interactor-plan-lottie

A Lottie animation of the poseswap plan, drawn as a railroad diagram, and the script that draws it.

The animation has three scenes, 45.7 s in all (1680 x 720, 30 frames a second):

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

Scenes 1 and 3 are drawn from the domain: a rail joins an earlier step that sets a fact to a later step that reads it, and rails that a longer path already implies are dropped. Scene 2 is drawn by hand from the relay's docs, so it does not follow the domain.

## What it does not have

- Times for most of the presence slice. Only the model loads, the edit and the score have been timed, so the others say "not timed". Image-to-mesh and matting are not timed either, so the 91 minutes of scene 3 leaves them out.
- A link from scene 1 to scene 3. The domain does not connect the edited image to the garment image, so no rail is drawn.
- The relay numbers are the repository's own, measured at 256 people on Linux with two shared vCPUs, on loopback. They are not a real network.
- A check in any player but lottie-web. The text is Arial, so a player without system fonts may letter it differently.

## Licence

MIT. See [LICENSE](LICENSE).
