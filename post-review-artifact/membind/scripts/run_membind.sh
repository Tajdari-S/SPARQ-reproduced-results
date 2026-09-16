#!/usr/bin/env bash
# Three repetitions of each mode, interleaved, sampling per-node memory of the
# running DuckDB every 15 s to confirm where its pages live.
#
#   DATA=/path/to/sf100 bash run_membind.sh        # ~15 min with the data page-cached
#   python3 analyze_membind.py
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES="$HERE/../results"
REPS="${REPS:-3}"
sample() {
    while sleep 15; do
        p=$(ps -u "$(id -u)" -o pid=,comm= | awk '$2=="duckdb"{print $1; exit}')
        [ -n "$p" ] && numastat -p "$p" 2>/dev/null | awk -v t="$1" '/^Total/{print t, $0}' >> "$RES/numastat.log"
    done
}
for r in $(seq 1 "$REPS"); do
    for m in none mem1; do
        echo "=== rep $r, MODE $m, $(date +%T) ==="
        sample "rep$r-$m" & sp=$!
        TAG="rep$r" MODE="$m" bash "$HERE/fig11_membind.sh"
        kill "$sp" 2>/dev/null
    done
done
python3 "$HERE/analyze_membind.py"
