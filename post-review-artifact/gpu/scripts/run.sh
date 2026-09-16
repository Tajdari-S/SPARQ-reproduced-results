#!/usr/bin/env bash
# GPU baseline for Figure 10, post-review: one run type at every scale factor,
# with table loading outside the timed region.
#
#   RAPIDS_PYTHON=/myenv/rapids_env/bin/python bash run.sh          # 3 repetitions
#   REPS=1 SF1_DIR=/data/sf1/ SF10_DIR=/data/sf10/ SF100_DIR=/data/sf100/ bash run.sh
#
# The separator ('|' or ',') is detected per file; SSB_SEP overrides it.
#
# ~14 minutes per repetition on an A100 40 GB with the data page-cached, almost
# all of it SF100. Writes results/logs/uniform_loadfixed_rep<N>.log and rebuilds
# results/gpu_uniform_results.csv from every rep log present.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${RAPIDS_PYTHON:-python3}"
REPS="${REPS:-3}"
LOGS="$HERE/../results/logs"
WORK="${WORK:-/tmp/sparq_gpu_post_review}"
export SF1_DIR="${SF1_DIR:-/p/pd/pim/sf1/}"
export SF10_DIR="${SF10_DIR:-/p/pd/pim/sf10/}"
export SF100_DIR="${SF100_DIR:-/p/pd/ssb-dbgen/sf100/}"
# numba-cuda 0.0.17 (RAPIDS 24.12) segfaults on driver 580 / CUDA 13 without this
export NUMBA_CUDA_USE_NVIDIA_BINDING=1 PYTHONUNBUFFERED=1

mkdir -p "$LOGS" "$WORK"
# Read every table once so the first repetition does not pay a cold read the
# later ones skip. Loading is outside the timer either way; this keeps reps comparable.
if [ "${WARM:-1}" = "1" ]; then
  echo "[warm] reading tables into the page cache ..."
  for d in "$SF1_DIR" "$SF10_DIR" "$SF100_DIR"; do
    for t in lineorder date customer supplier part; do cat "$d$t.tbl" > /dev/null 2>&1; done
  done
fi

start=$(ls "$LOGS"/uniform_loadfixed_rep*.log 2>/dev/null | wc -l)
for i in $(seq 1 "$REPS"); do
  n=$((start + i))
  log="$LOGS/uniform_loadfixed_rep$n.log"
  echo "[rep $n] $(date '+%F %T') -> $log"
  (cd "$WORK" && cp "$HERE/BestGPU_uniform_loadfixed.py" . && "$PY" BestGPU_uniform_loadfixed.py) > "$log" 2>&1
  grep -aE 'Processing SF|Join computed|Join failed' "$log" | sed 's/^/    /'
done
python3 "$HERE/make_tables.py"
