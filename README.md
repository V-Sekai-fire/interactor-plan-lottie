# interactor-plan-lottie

A Lean 4 converter from planner JSON-LD to a Lottie animation drawn like Unreal Engine Blueprints, and the animation it makes for the poseswap plan.

JSON-LD in, Lottie out: the domain and one plan for each part go in, and one Lottie with a text version comes out (1680 x 720, 30 frames a second). One Sequence node runs a part for each plan, and a camera follows the node that is running, so only part of the graph shows at a time.

- White pins and wires are the sequence: the order the planner runs the steps.
- Coloured pins are facts. A step's inputs are on its left (facts it reads) and its outputs on its right (facts it sets).
- A Branch node is a composite method with two or more alternatives. The way the plan took is lit, and the other is dim.
- Every wire is solid. A dotted line is not a Blueprint thing.
- Under a node, the action's own `description` from the domain, wrapped to the node's width. The domain marks each one in `description_basis`: written (the sentence its own description gives) or drafted (built from what the action reads and sets). The converter draws what the domain says and does not draft anything itself.
- A step's time shows its milliseconds when it has them: `56 ms`, `3.202 s`, `1 min 7 s`.

## Layers have no limit unless you set one

By default a plan is drawn as one layer, however many nodes it has. `--cap N` (nodes) and `--complexity N` (independent paths: the Branch nodes plus one) set a limit. A plan over it is drawn as a layer of Extract nodes. Each Extract node stands for a run of the plan's nodes and opens onto a layer of its own, titled "Inside ..."; a Branch stays with its alternatives, so a run is never cut through one. The words "Extract" and "N nodes" are the converter's own.

Numbers to start from, taken from NASA and JPL's rules for code that must not fail, with a node standing for a statement: 30 nodes (Power of Ten, rule 4: a function is about 60 lines, and 30 for the body of one compound statement) and 10 paths (SWE-220 allows 15 for safety-critical code and reads 10 or less as well structured). Today's four plans (20, 9, 20 and 13 nodes, at most two Branch nodes) fit both. The witness runs the Extract layers at a cap of 7 and a complexity limit of 2.

## Nothing is drawn that the JSON-LD did not say

The converter may hide what the JSON-LD says, but it may not add to it. A node is a plan step, titled from the action's key. Its pins are the facts it reads and sets, its time is its duration, and a caption is a variable's own description. The words that are the converter's own are "Sequence", "Then N", "not timed", "GPU" and a count of inputs the desk states.

`plan_lottie_witness` checks this by planting marks: it renders from an empty domain, then from a domain in which every string carries a mark, and fails if any word on screen has neither.

## What is here

| Path | What it holds |
| --- | --- |
| `PlanLottie/`, `Main.lean` | the converter: `plan_lottie [--grid N] [--transcript out.md] <domain> <out.json> <plan>...` |
| `Witness.lean` | 27 checks, golden, control, invariant and leak, each with a planted fault where it can fail |
| `inputs/` | the poseswap domain and the planner's four plans: the presence slice, one relay tick, the AUX route and the obstacle course |
| `poseswap-plan.lottie.json`, `poseswap-plan.transcript.md` | the animation, and the same graph as text |
| `tests/golden/transcript.md` | the committed text version that the check compares against |
| `lottie/` | each plan as a Lottie of its own, with its text version (`viewer.html?plan=0-presence`, `1-relay`, `2-aux`, `3-course`) |
| `viewer.html` | a page that plays it, with Pause, Restart, speed, a status line, and the text version below |
| `make.sh` | build, draw, check |

## Rebuild it

    ./make.sh

To redraw from a changed domain, plan again in `3d-character-poseswap` and copy the domain and the plans into `inputs/`. The domain lives there, so the copy can drift. Then run `make.sh`, and if the new text version is the one you mean, copy `poseswap-plan.transcript.md` over `tests/golden/transcript.md`.

To play it, serve this folder (`python3 -m http.server`) and open `/viewer.html`. A `file://` page cannot fetch the JSON.

## What it does not have

- The plans are for desks that state every input as on hand. Today's desk cannot reach the edit, and the obstacle course repository has no `project.godot`, so on today's desk the planner calls it unreachable.
- Times for some steps. Only an action with a stated duration shows one; the rest say "not timed".
- The relay's measured numbers and the tick rate. They are not in the domain, so they are not drawn.
- A check in any player but lottie-web. The text is Arial, so a player without system fonts may letter it differently.

## Licence

MIT. See [LICENSE](LICENSE).
