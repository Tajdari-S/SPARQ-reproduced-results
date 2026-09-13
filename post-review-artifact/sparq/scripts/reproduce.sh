#!/usr/bin/env bash
# Reproduce the SPARQ join latencies under either memory geometry.
#
#   bash reproduce.sh x8  1        # the configuration Figures 7 and 10 were plotted with
#   bash reproduce.sh x16 1        # the configuration 02-sparq/ ships
#   TABLES="customer date" bash reproduce.sh x8 10
#
# Method is identical to 02-sparq/reproduce.sh: one DRAMsim3 run per join, and
# latency = cycle of the last READ in the command trace x 0.625 ns (DDR4-3200).
# Only the config and the probe traces change with the geometry.
#
# Disk: each simulation writes a command trace, deleted as soon as the cycle is
# read. Set WORK to put it on a larger disk.
set -uo pipefail

GEOM="${1:-x8}"
SF="${2:-1}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"   # repository root
TCK_NS=0.625

case "$GEOM" in
  x8)  CFG="$HERE/config/SPARQ_DDR4_8Gb_x8_3200.ini";  TRACES="$HERE/traces" ;;
  x16) CFG="$HERE/config/SPARQ_DDR4_8Gb_x16_3200.ini"; TRACES="$REPO/02-sparq/traces" ;;
  *)   echo "geometry must be x8 or x16"; exit 1 ;;
esac

# The simulator source lives in the full artifact:
#   git clone https://github.com/Tajdari-S/JSPIM
#   DRAMSIM3_SRC=JSPIM/SPARQ/sparq-sim/DRAMsim3 bash reproduce.sh x8 1
SIM="${DRAMSIM3_SRC:-$REPO/../JSPIM/SPARQ/sparq-sim/DRAMsim3}"
BUILD="${BUILD:-$SIM/build_cmdtrace}"
WORK="${WORK:-/tmp/sparq_post_review_${GEOM}_sf${SF}}"
TABLES="${TABLES:-customer part supplier date}"
# Cycle cap. DRAMsim3 always runs to -c, so the cap sets the runtime; the result
# is the last READ cycle and is identical for any cap above completion (checked:
# SF1 customer gives the same cycle at 1e7 and 999,990,000, and 1,190,396 at 1e7
# matches the March run at 2,999,990,000). Completion is <= ~2M, ~26M and ~162M
# cycles at SF1/10/100.
case "$SF" in 1) DEF_CAP=10000000 ;; 10) DEF_CAP=50000000 ;; *) DEF_CAP=250000000 ;; esac
CAP="${CAP:-$DEF_CAP}"

declare -A COL=( [customer]=C2 [part]=C3 [supplier]=C4 [date]=C5 )
# Figures 7 and 10, ns
declare -A PLOTTED
if [ "$SF" = "10" ]; then
    PLOTTED=( [customer]=8472425 [part]=12407645 [supplier]=9333137.5 [date]=7642613.125 )
else
    PLOTTED=( [customer]=743997.5 [part]=1076788.75 [supplier]=968215 [date]=764128.125 )
fi

if [ ! -x "$BUILD/dramsim3main" ]; then
    [ -d "$SIM/src" ] || { echo "Set DRAMSIM3_SRC to JSPIM/SPARQ/sparq-sim/DRAMsim3"; exit 1; }
    # CMD_TRACE is a compile-time flag: without it no command trace is written
    echo "[build] compiling with CMD_TRACE=ON ..."
    mkdir -p "$BUILD" && (cd "$BUILD" && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMD_TRACE=ON >/dev/null 2>&1 \
        && make -j"$(nproc)" >/dev/null 2>&1) || { echo "  build FAILED"; exit 1; }
fi

mkdir -p "$HERE/results" "$WORK"
OUT="$HERE/results/sparq_${GEOM}_sf${SF}.csv"
[ -f "$OUT" ] || echo "sf,geometry,table,col,last_read_cycle,ns,plotted_ns,ratio" > "$OUT"

echo "SPARQ latency, geometry=$GEOM SF$SF  config=$(basename "$CFG")"
printf "%-10s %16s %14s %14s %8s\n" "join" "last_read_cycle" "ns" "plotted_ns" "ratio"
for tbl in $TABLES; do
    c="${COL[$tbl]}"
    gz="$TRACES/lineorder_sf${SF}_${c}_${GEOM}.txt.gz"
    [ -f "$gz" ] || { printf "%-10s %16s\n" "$tbl" "no $GEOM trace - skipped"; continue; }

    w="$WORK/$tbl"; rm -rf "$w"; mkdir -p "$w"; cd "$w"
    zcat "$gz" > trace.txt
    "$BUILD/dramsim3main" "$CFG" -c "$CAP" -t trace.txt >/dev/null 2>&1
    cyc=$(tac dramsim3ch_0cmd.trace 2>/dev/null | grep -m1 "read" | awk '{print $1}')
    rm -f dramsim3ch_0cmd.trace trace.txt

    if [ -z "$cyc" ]; then
        printf "%-10s %16s\n" "$tbl" "FAILED (no command trace - is CMD_TRACE on?)"; continue
    fi
    if [ "$cyc" -gt $((CAP * 95 / 100)) ]; then
        printf "%-10s %16s\n" "$tbl" "FAILED (completion $cyc is near the cap $CAP; rerun with a larger CAP)"; continue
    fi
    ns=$(python3 -c "print(f'{$cyc * $TCK_NS:.1f}')")
    ratio=$(python3 -c "print(f'{$ns / ${PLOTTED[$tbl]}:.2f}')")
    printf "%-10s %16s %14s %14s %8s\n" "$tbl" "$cyc" "$ns" "${PLOTTED[$tbl]}" "${ratio}x"
    echo "$SF,$GEOM,$tbl,$c,$cyc,$ns,${PLOTTED[$tbl]},$ratio" >> "$OUT"
done
echo "results -> $OUT"
