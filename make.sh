#!/usr/bin/env bash
# Build the converter, draw every plan in inputs/plans/ as a Lottie of its own and the first four together as lottie/all, then run the checks.
# A layer has no node limit unless --cap N or --complexity N is passed to plan_lottie (README).
# Each plan has a golden text version in tests/golden/<n>.transcript.md, and the combined one is tests/golden/all.transcript.md.
# After a change you mean to make, copy lottie/<n>.transcript.md over its golden.
set -euo pipefail
cd "$(dirname "$0")"
lake build plan_lottie plan_lottie_witness
BIN=.lake/build/bin
DOM=inputs/domain.jsonld
mkdir -p lottie
for p in inputs/plans/*.jsonld; do
  n=$(basename "$p" .jsonld)
  $BIN/plan_lottie --transcript "lottie/$n.transcript.md" $DOM "lottie/$n.lottie.json" "$p"
  $BIN/plan_lottie_witness $DOM "tests/golden/$n.transcript.md" "$p"
done
CORE=(inputs/plans/[0-3]-*.jsonld)
$BIN/plan_lottie --transcript lottie/all.transcript.md $DOM lottie/all.lottie.json "${CORE[@]}"
$BIN/plan_lottie_witness $DOM tests/golden/all.transcript.md "${CORE[@]}"
