#!/usr/bin/env bash
# Figure 9, all six columns, NFS vs local.
#
# Fig9.py plots six columns (C-0..C-5) per scale factor for each of
# duckdb_distinct and duckdb_where. An earlier pass measured only C-0 and C-1,
# which left ten of the twelve DuckDB bars carrying their original NFS values and
# made the regenerated figure look unchanged.
#
# The predicates below are taken verbatim from /p/pd/run_benchmark_cols.sh, which
# is what produced the plotted values. They differ per column AND per scale
# factor, so they cannot be guessed. Note two irregularities at SF100: column03
# is named `partkey`, and column05 is an integer date rather than a DATE.
#
# The plotted values correspond to the materialised form (COPY ... TO
# '/dev/null'), not the COUNT form that run_benchmark_cols.sh logs -- verified
# because the materialised form reproduces the plotted numbers to within 2% on
# NFS while the COUNT form is orders of magnitude faster.
set -uo pipefail

V113="${V113:-/p/pd/newduckdb/duckdb}"
NUMA_NODE="${NUMA_NODE:-0}"
REPS="${REPS:-2}"
PIN="numactl --cpunodebind=${NUMA_NODE} --membind=${NUMA_NODE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/results/fig9_all_columns.csv"
mkdir -p "$(dirname "$OUT")"
echo "sf,column,series,storage,rep,seconds" > "$OUT"

parse_time() { grep -oE 'real[[:space:]]+[0-9.]+' | head -1 | awk '{print $2}'; }

# sf -> nfs db | local db
declare -A NFSDB=( [1]=/p/pd/ssb_sf1.duckdb [10]=/p/pd/ssb_sf10.duckdb [100]=/p/pd/duckdb_work/ssb_sf100.duckdb )
declare -A LOCDB=( [1]=/tmp/figdb_local/ssb_sf1.duckdb [10]=/tmp/figdb_local/ssb_sf10.duckdb [100]=/tmp/sf100_local.duckdb )
# SF1/SF10 local copies are made by queue_all.sh before this runs.

# sf -> per-column predicate, verbatim from run_benchmark_cols.sh
preds_1=("column00 = 1000000" "column01 = 3" "column02 = 10000" "column03 = 100000" "column04 = 500" "column05 = DATE '1995-02-18'")
preds_10=("column00 = 5000000" "column01 = 3" "column02 = 100000" "column03 = 300000" "column04 = 10000" "column05 = DATE '1995-02-18'")
preds_100=("column00 = 50000000" "column01 = 3" "column02 = 1000000" "partkey = 500000" "column04 = 100000" "column05 = 19960102")
cols_1=(column00 column01 column02 column03 column04 column05)
cols_10=(column00 column01 column02 column03 column04 column05)
cols_100=(column00 column01 column02 partkey column04 column05)

measure() {  # measure <db> <storage> <sf> <cidx> <series> <sql>
  local DB="$1" ST="$2" SF="$3" CI="$4" SER="$5" SQL="$6" shown=""
  [ -f "$DB" ] || { printf "  %-6s %-14s %-16s (no db)\n" "$ST" "C-$CI" "$SER"; return; }
  for r in $(seq 1 "$REPS"); do
    local raw sec
    raw=$($PIN "$V113" "$DB" 2>&1 <<EOSQL
.timer on
${SQL}
EOSQL
)
    sec=$(echo "$raw" | parse_time)
    if echo "$raw" | grep -qE '^Error:|Conversion Error|Binder Error|Catalog Error'; then sec=""; fi
    echo "${SF},C-${CI},${SER},${ST},${r},${sec:-}" >> "$OUT"
    shown="$shown ${sec:-ERR}"
  done
  printf "  %-6s %-6s %-14s %s\n" "$ST" "C-$CI" "$SER" "$shown"
}

SFS=(${SFS:-1 10 100})
for SF in "${SFS[@]}"; do
  eval "cols=(\"\${cols_${SF}[@]}\")"
  eval "preds=(\"\${preds_${SF}[@]}\")"
  echo "=============================================================="
  echo "  SF${SF}   reps=${REPS}"
  echo "=============================================================="
  for i in 0 1 2 3 4 5; do
    C="${cols[$i]}"; P="${preds[$i]}"
    measure "${NFSDB[$SF]}" nfs   "$SF" "$i" distinct "COPY (SELECT DISTINCT ${C} FROM lineorder) TO '/dev/null' (FORMAT CSV);"
    measure "${LOCDB[$SF]}" local "$SF" "$i" distinct "COPY (SELECT DISTINCT ${C} FROM lineorder) TO '/dev/null' (FORMAT CSV);"
    measure "${NFSDB[$SF]}" nfs   "$SF" "$i" where    "COPY (SELECT * FROM lineorder WHERE ${P}) TO '/dev/null' (FORMAT CSV);"
    measure "${LOCDB[$SF]}" local "$SF" "$i" where    "COPY (SELECT * FROM lineorder WHERE ${P}) TO '/dev/null' (FORMAT CSV);"
  done
done

echo
echo "results -> $OUT"
