#!/usr/bin/env bash
# Build the converter, draw the plans in inputs/ as one Lottie and its text version, then run the checks.
# The committed golden is tests/golden/transcript.md: after a change you mean to make, copy poseswap-plan.transcript.md over it.
# To redraw from a changed domain, copy the domain and the planner's plans into inputs/ first (see README).
set -euo pipefail
cd "$(dirname "$0")"
lake build plan_lottie plan_lottie_witness
PLANS=(inputs/plan-*.jsonld)
.lake/build/bin/plan_lottie --transcript poseswap-plan.transcript.md inputs/domain.jsonld poseswap-plan.lottie.json "${PLANS[@]}"
.lake/build/bin/plan_lottie_witness inputs/domain.jsonld tests/golden/transcript.md "${PLANS[@]}"
