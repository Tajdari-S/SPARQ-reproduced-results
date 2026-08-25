#!/usr/bin/env bash
# Reproduce the SPARQ join latencies for Figure 7 at SF1.
#
#   bash reproduce.sh
#
# Self-contained: the traces and the simulator config ship in this directory.
# Builds the simulator if needed, runs one simulation per join, and prints the
# latency next to the value the paper plots.
#
# Disk: each simulation writes a command trace of roughly 1 GB. This script
# deletes each one as soon as it has read the number it needs, so peak usage
# stays near 1 GB rather than 3 GB.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This repo ships traces and config but not the simulator source. Point
# DRAMSIM3_SRC at a DRAMsim3 checkout, or at the SPARQ artifact:
#   git clone https://github.com/Tajdari-S/JSPIM
#   DRAMSIM3_SRC=JSPIM/SPARQ/sparq-sim/DRAMsim3 bash 02-sparq/reproduce.sh
SIM="${DRAMSIM3_SRC:-$HERE/../../JSPIM/SPARQ/sparq-sim/DRAMsim3}"
if [ ! -f "$SIM/CMakeLists.txt" ]; then
    echo "DRAMsim3 source not found at: $SIM"
    echo "Set DRAMSIM3_SRC, e.g.:"
    echo "  git clone https://github.com/Tajdari-S/JSPIM"
    echo "  DRAMSIM3_SRC=JSPIM/SPARQ/sparq-sim/DRAMsim3 bash \$0"
    exit 1
fi
BUILD="${BUILD:-$SIM/build_cmdtrace}"
CFG="${CFG:-$HERE/config/SPARQ_DDR4_8Gb_x16_3200.ini}"  # ships in this repo
WORK="${WORK:-/tmp/sparq_latency_repro}"
TCK_NS=0.625          # DDR4-3200 memory clock period

SF="${1:-1}"          # scale factor: 1 (default) or 10
# join -> trace column.  C2=custkey, C3=partkey, C4=suppkey
declare -A COL=( [customer]=C2 [part]=C3 [supplier]=C4 )
# published Figure 7 values, ns
if [ "$SF" = "10" ]; then
    declare -A PLOTTED=( [customer]=8472425 [part]=12407645 [supplier]=9333137.5 )
else
    declare -A PLOTTED=( [customer]=743997.5 [part]=1076788.75 [supplier]=968215 )
fi

echo "=============================================="
echo " SPARQ latency reproduction - Figure 7, SF${SF}"
echo "=============================================="

# --- 1. simulator, built with CMD_TRACE ------------------------------------
# The latency is the last read cycle from dramsim3ch_<n>cmd.trace, and that
# file is emitted ONLY when DRAMsim3 is compiled with -DCMD_TRACE. It is a
# compile-time flag, not a config option: a default build runs fine, writes no
# command trace, and the aggregation step then finds nothing to read.
if [ ! -x "$BUILD/dramsim3main" ]; then
    echo "[build] compiling with CMD_TRACE=ON ..."
    mkdir -p "$BUILD" && (cd "$BUILD" && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMD_TRACE=ON >/dev/null 2>&1 \
        && make -j"$(nproc)" >/dev/null 2>&1) || { echo "  build FAILED"; exit 1; }
fi
echo "[build] $BUILD/dramsim3main"
echo "[config] $CFG"

mkdir -p "$WORK"
OUT="$HERE/results/sparq_latency_reproduction_sf${SF}.csv"
echo "sf,col,table,last_read_cycle,ns,plotted_ns,ratio" > "$OUT"

printf "\n%-10s %16s %14s %14s %8s\n" "join" "last_read_cycle" "reproduced_ns" "plotted_ns" "ratio"
printf -- "------------------------------------------------------------------------\n"

for tbl in customer part supplier; do
    c="${COL[$tbl]}"
    gz="$HERE/traces/lineorder_sf${SF}_${c}_x16.txt.gz"
    [ -f "$gz" ] || { echo "  missing $gz"; continue; }

    w="$WORK/$tbl"; rm -rf "$w"; mkdir -p "$w"; cd "$w"
    zcat "$gz" > trace.txt

    # -c is a CYCLE CAP, not a stop condition: the simulator runs to this limit
    # regardless, so num_cycles in dramsim3.txt is always 999990000 and is NOT
    # the completion time. The completion time comes from the command trace.
    "$BUILD/dramsim3main" "$CFG" -c 999990000 -t trace.txt >/dev/null 2>&1

    cyc=$(tac dramsim3ch_0cmd.trace 2>/dev/null | grep -m1 "read" | awk '{print $1}')
    if [ -z "$cyc" ]; then
        printf "%-10s %16s\n" "$tbl" "FAILED (no command trace - is CMD_TRACE on?)"
        echo "$SF,$c,$tbl,,,${PLOTTED[$tbl]}," >> "$OUT"
    else
        ns=$(python3 -c "print(f'{$cyc * $TCK_NS:.1f}')")
        ratio=$(python3 -c "print(f'{$ns / ${PLOTTED[$tbl]}:.2f}')")
        printf "%-10s %16s %14s %14s %8s\n" "$tbl" "$cyc" "$ns" "${PLOTTED[$tbl]}" "${ratio}x"
        echo "$SF,$c,$tbl,$cyc,$ns,${PLOTTED[$tbl]},$ratio" >> "$OUT"
    fi
    # the command trace is ~1 GB; drop it now that the number is extracted
    rm -f dramsim3ch_0cmd.trace trace.txt
done

echo
echo "latency (ns) = last_read_cycle x ${TCK_NS}      # DDR4-3200 tCK"
echo "results -> $OUT"
