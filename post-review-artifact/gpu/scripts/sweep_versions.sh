#!/bin/bash
# Run every GPU join script version at SF1 and SF10 and log the output, to find
# which one reproduces the paper's GPU bars. SF100 is skipped (its path is pointed
# at a nonexistent directory) so the sweep takes ~20 minutes rather than hours.
#
#   SRC=/p/pd/NVIDIARapids RAPIDS_PYTHON=/myenv/rapids_env/bin/python bash sweep_versions.sh
#   python3 parse_version_sweep.py
#
# Each script runs on a copy; the originals are never modified. The only patches
# are protocol ucx->tcp (UCX crashes in libucs on our host; with one worker no
# data crosses the wire) and the SF100 path.
HERE="$(cd "$(dirname "$0")" && pwd)"
R="$HERE/../results/logs"
PY="${RAPIDS_PYTHON:-python3}"
SRC="${SRC:-/p/pd/NVIDIARapids}"
mkdir -p "$R/version_sweep"
: > "$R/version_sweep/PROGRESS"
# warm the page cache so no script pays a cold NFS read the others do not
for f in /p/pd/pim/sf1/{lineorder,date,customer,supplier,part}.tbl /p/pd/pim/sf10/{lineorder,date,customer,supplier,part}.tbl; do
  cat "$f" > /dev/null 2>&1
done
echo "page cache warmed $(date +%T)" >> "$R/version_sweep/PROGRESS"
# numba-cuda 0.0.17 segfaults on driver 580 / CUDA 13 without this
export NUMBA_CUDA_USE_NVIDIA_BINDING=1 PYTHONUNBUFFERED=1
SCRIPTS="BestGPU.py BestGPUReport.py FinalJoin.py NewFinalJoin.py join_VF.py test13.py test1.py test2.py test3.py test4.py test5.py test6.py test7.py test8.py test9.py test10.py"
for s in $SCRIPTS; do
  d="$R/version_sweep/work_${s%.py}"; mkdir -p "$d"; cd "$d"
  cp "$SRC/$s" .
  sed -i -e 's/protocol="ucx"/protocol="tcp"/' \
         -e 's#/p/pd/ssb-dbgen/sf100/#/nonexistent_phase1/sf100/#g' \
         -e 's#/p/pd/pim/sf100/#/nonexistent_phase1/sf100/#g' "$s"
  log="$R/version_sweep/${s%.py}.log"
  { echo "### $s  start $(date '+%F %T')  gpu_mem_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"; diff "$SRC/$s" "$s"; } > "$log"
  setsid timeout 900 "$PY" "$s" >> "$log" 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    avail=$(df --output=avail -k / | tail -1)
    [ "$avail" -lt 5000000 ] && { echo "### WATCHDOG: / below 5 GB free, killing" >> "$log"; kill -- -$pid 2>/dev/null; }
    sleep 5
  done
  wait $pid; rc=$?
  pkill -f "$d" 2>/dev/null; sleep 3
  echo "### $s  end $(date '+%F %T')  rc=$rc" >> "$log"
  echo "$s rc=$rc $(date '+%T')" >> "$R/version_sweep/PROGRESS"
  cd "$HERE"; rm -rf "$d"
done
echo ALLDONE >> "$R/version_sweep/PROGRESS"
