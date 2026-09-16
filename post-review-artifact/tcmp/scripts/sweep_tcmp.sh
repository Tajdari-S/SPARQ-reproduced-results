#!/usr/bin/env bash
# Comparator-delay (tCMP) sensitivity sweep, Section 5.3.4.
#
#   bash sweep_tcmp.sh x8  1 10          # SF1 and SF10 with the traces shipped here
#   X8_SF100_DIR=/path/to/sf100/traces bash sweep_tcmp.sh x8 100
#   bash sweep_tcmp.sh x16 1 10
#
# For each join and tCMP in 0..4, runs DRAMsim3 with `tCMP = <t>` and records the
# completion cycle: the cycle of the last READ in the command trace. This is the
# metric behind every SPARQ latency in the paper, and the one getting_started.sh
# uses. It is monotonic in tCMP; DRAMsim3's average_read_latency is not (see README).
#
# The command trace is written into a FIFO and reduced to its last READ line on the
# fly, so no multi-GB trace touches the disk (~11 GB per SF100 join otherwise).
# Results append to ../results/tcmp_sweep.csv. JOBS sets parallelism (default 20).
set -uo pipefail

GEOM="${1:?geometry: x8 or x16}"; shift
SFS=("$@"); [ ${#SFS[@]} -eq 0 ] && SFS=(1 10)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PR="$(cd "$HERE/.." && pwd)"               # post-review-artifact/
REPO="$(cd "$PR/.." && pwd)"
SIM="${DRAMSIM3_SRC:-$REPO/../JSPIM/SPARQ/sparq-sim/DRAMsim3}"
BIN="${BUILD:-$SIM/build_cmdtrace}/dramsim3main"
[ -x "$BIN" ] || { echo "build the simulator first: bash $PR/sparq/scripts/reproduce.sh x8 1"; exit 1; }
OUT="$HERE/results/tcmp_sweep.csv"
WORK="${WORK:-/tmp/sparq_tcmp_sweep}"
JOBS="${JOBS:-20}"
mkdir -p "$HERE/results" "$WORK"
[ -f "$OUT" ] || echo "geometry,sf,table,col,tcmp,completion_cycle,latency_ns" > "$OUT"

case "$GEOM" in
  x8)  CFG="$PR/sparq/config/SPARQ_DDR4_8Gb_x8_3200.ini";  COLS="C2 C3 C4 C5" ;;
  x16) CFG="$PR/sparq/config/SPARQ_DDR4_8Gb_x16_3200.ini"; COLS="C2 C3 C4" ;;  # no x16 date trace
  *) echo "geometry must be x8 or x16"; exit 1 ;;
esac

trace_for() {  # sf col -> path (plain or .gz)
    local sf=$1 c=$2
    if [ "$GEOM" = x8 ]; then
        if [ "$sf" = 100 ]; then
            echo "${X8_SF100_DIR:?set X8_SF100_DIR to the directory holding lineorder_LatencyRankoptd_ch1_sf100_C*.txt}/lineorder_LatencyRankoptd_ch1_sf100_${c}.txt"
        else
            echo "$PR/sparq/traces/lineorder_sf${sf}_${c}_x8.txt.gz"
        fi
    else
        if [ "$sf" = 100 ]; then
            echo "${X16_SF100_DIR:?set X16_SF100_DIR}/lineorder_LatencyRankoptd_ch1_sf100_${c}_x16.txt"
        else
            echo "$REPO/02-sparq/traces/lineorder_sf${sf}_${c}_x16.txt.gz"
        fi
    fi
}

one() {  # sf col tcmp
    local sf=$1 c=$2 t=$3 d tr cap cyc
    d="$WORK/${GEOM}_sf${sf}_${c}_t${t}"; rm -rf "$d"; mkdir -p "$d"; cd "$d" || return
    sed "s/^tCMP = 0/tCMP = $t/" "$CFG" > cfg.ini
    tr="$(trace_for "$sf" "$c")"
    case "$tr" in *.gz) zcat "$tr" > trace.txt ;; *) ln -s "$tr" trace.txt ;; esac
    # cycle cap = run length; completion is <= ~2M / ~26M / ~162M cycles at SF1/10/100
    case "$sf" in 1) cap=10000000 ;; 10) cap=50000000 ;; *) cap=250000000 ;; esac
    mkfifo dramsim3ch_0cmd.trace
    awk '$2=="read"{c=$1} END{print c}' < dramsim3ch_0cmd.trace > last &
    "$BIN" cfg.ini -c "$cap" -t trace.txt > /dev/null 2>&1
    wait
    cyc="$(cat last)"
    declare -A NAME=( [C2]=customer [C3]=part [C4]=supplier [C5]=date )
    if [ -z "$cyc" ] || [ "$cyc" -gt $((cap * 95 / 100)) ]; then
        echo "  FAILED ${GEOM} SF${sf} ${c} tCMP=${t} (cycle '${cyc}', cap ${cap})"
    else
        echo "$GEOM,$sf,${NAME[$c]},$c,$t,$cyc,$(python3 -c "print($cyc*0.625)")" >> "$OUT"
    fi
    cd "$WORK" && rm -rf "$d"
}
export -f one trace_for
export GEOM CFG PR REPO BIN WORK OUT X8_SF100_DIR X16_SF100_DIR 2>/dev/null

for sf in "${SFS[@]}"; do
    echo "[$(date +%T)] $GEOM SF$sf: tCMP 0-4 x {$COLS}"
    for c in $COLS; do for t in 0 1 2 3 4; do echo "$sf $c $t"; done; done \
        | xargs -P "$JOBS" -n 3 bash -c 'one "$@"' _
done
echo "results -> $OUT"
