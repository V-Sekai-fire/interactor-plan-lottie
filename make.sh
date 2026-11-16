#!/usr/bin/env bash
# Build the converter, draw the plans in inputs/ as one Lottie and its text version, and each plan as a Lottie of its own in lottie/, then run the checks.
# A layer has no node limit unless --cap N or --complexity N is passed (README); a plan over a limit becomes a layer of Extract nodes, each opening onto a layer of its own.
# The committed golden is tests/golden/transcript.md: after a change you mean to make, copy poseswap-plan.transcript.md over it.
# To redraw from a changed domain, copy the domain and the planner's plans into inputs/ first (see README).
set -euo pipefail
cd "$(dirname "$0")"
lake build plan_lottie plan_lottie_witness
PLANS=(inputs/plan-*.jsonld)
.lake/build/bin/plan_lottie --transcript poseswap-plan.transcript.md inputs/domain.jsonld poseswap-plan.lottie.json "${PLANS[@]}"
mkdir -p lottie
for p in "${PLANS[@]}"; do n=$(basename "$p" .jsonld); n=${n#plan-}; .lake/build/bin/plan_lottie --transcript "lottie/$n.transcript.md" inputs/domain.jsonld "lottie/$n.lottie.json" "$p"; done
.lake/build/bin/plan_lottie_witness inputs/domain.jsonld tests/golden/transcript.md "${PLANS[@]}"
