#!/usr/bin/env bash
# Re-measure the paper's DuckDB baselines with the database on LOCAL disk.
#
# The figures were measured against databases under /p/pd, which is NFS
# (corezfs02:/p/pd). A cold query there pays a first-read over the network that
# a local run does not: same file, same binary, same pinning, up to 11x apart.
# Warm runs are identical, so the effect only reaches measurements that start
# from a fresh process - which is exactly the cold protocol the figures use.
#
# This script measures each figure's DuckDB series twice, from the SAME database
# file: once where the figures had it (NFS) and once copied to local disk. The
# local column is the corrected baseline.
#
# Usage: bash corrected_baselines.sh [SF ...]      # default 1 10
set -uo pipefail

SFS=("$@"); [ ${#SFS[@]} -eq 0 ] && SFS=(1 10)
DUCKDB="${DUCKDB:-/p/pd/newduckdb/duckdb}"
NFS_DIR="${NFS_DIR:-/p/pd}"
LOCAL_DIR="${LOCAL_DIR:-/tmp/figdb_local}"
NUMA_NODE="${NUMA_NODE:-0}"
REPS="${REPS:-3}"
PIN="numactl --cpunodebind=${NUMA_NODE} --membind=${NUMA_NODE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/results/corrected_baselines.csv"

mkdir -p "$LOCAL_DIR" "$(dirname "$OUT")"
echo "figure,series,sf,name,storage,rep,seconds" > "$OUT"

parse_time() { grep -oE 'real[[:space:]]+[0-9.]+' | head -1 | awk '{print $2}'; }

measure() {  # measure <db> <storage> <figure> <series> <sf> <name> <sql>
  local DB="$1" ST="$2" FIG="$3" SER="$4" SF="$5" NAME="$6" SQL="$7" shown=""
  for r in $(seq 1 "$REPS"); do
    local raw sec
    raw=$($PIN "$DUCKDB" "$DB" 2>&1 <<EOSQL
.timer on
${SQL}
EOSQL
)
    sec=$(echo "$raw" | parse_time)
    if echo "$raw" | grep -qE '^Error:|Conversion Error|Binder Error|Catalog Error'; then sec=""; fi
    echo "${FIG},${SER},${SF},${NAME},${ST},${r},${sec:-}" >> "$OUT"
    shown="$shown ${sec:-ERR}"
  done
  printf "    %-10s %-22s %s\n" "$ST" "$NAME" "$shown"
}

for SF in "${SFS[@]}"; do
  NFS_DB="${NFS_DIR}/ssb_sf${SF}.duckdb"
  LOC_DB="${LOCAL_DIR}/ssb_sf${SF}.duckdb"
  [ -f "$NFS_DB" ] || { echo "  no $NFS_DB, skipping SF${SF}"; continue; }
  echo "=============================================================="
  echo "  SF${SF}"
  echo "=============================================================="
  if [ ! -f "$LOC_DB" ]; then
    echo "  copying $(du -h "$NFS_DB" | cut -f1) to local disk ..."
    cp "$NFS_DB" "$LOC_DB"
  fi

  # Figures 7 and 10: star joins, output materialised.
  for j in customer part supplier; do
    case $j in
      customer) k="l.column02 = d.column0" ;;
      part)     k="l.column03 = d.column0" ;;
      supplier) k="l.column04 = d.column0" ;;
    esac
    SQL="COPY (SELECT * FROM lineorder l JOIN ${j} d ON ${k}) TO '/dev/null' (FORMAT CSV);"
    measure "$NFS_DB" nfs   fig7_10 duckdb_latencies "$SF" "$j" "$SQL"
    measure "$LOC_DB" local fig7_10 duckdb_latencies "$SF" "$j" "$SQL"
  done

  # Figure 8: self-join, COUNT(*).
  SQL="SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column00 = l2.column00;"
  measure "$NFS_DB" nfs   fig8 duckdb_ms "$SF" selfjoin_orderkey "$SQL"
  measure "$LOC_DB" local fig8 duckdb_ms "$SF" selfjoin_orderkey "$SQL"

  # Figure 9: select operators, materialised. C-0 and C-1 of the six plotted.
  SQL="COPY (SELECT DISTINCT column00 FROM lineorder) TO '/dev/null' (FORMAT CSV);"
  measure "$NFS_DB" nfs   fig9 duckdb_distinct "$SF" C-0 "$SQL"
  measure "$LOC_DB" local fig9 duckdb_distinct "$SF" C-0 "$SQL"
  SQL="COPY (SELECT * FROM lineorder WHERE column01 = 3) TO '/dev/null' (FORMAT CSV);"
  measure "$NFS_DB" nfs   fig9 duckdb_where "$SF" C-1 "$SQL"
  measure "$LOC_DB" local fig9 duckdb_where "$SF" C-1 "$SQL"
done

echo
echo "raw results -> $OUT"
