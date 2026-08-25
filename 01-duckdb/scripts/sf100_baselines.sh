#!/usr/bin/env bash
# SF100 half of the NFS-vs-local baseline correction.
#
# Split out from corrected_baselines.sh because SF100 differs in three ways:
#   * the database is 16.3 GB, so the local copy has to be made deliberately
#     rather than on the fly;
#   * its lineorder has column03 renamed to `partkey`, so the part join differs;
#   * Figure 8 uses v0.8.0, which cannot open the v1.x SF100 database, so its
#     local measurement uses the separate v0.8.0 database in /tmp.
#
# Usage: bash sf100_baselines.sh
set -uo pipefail

V113="${V113:-/p/pd/newduckdb/duckdb}"
V080="${V080:-/p/pd/newgem5/gem5/duckdb}"
NFS_DB="${NFS_DB:-/p/pd/duckdb_work/ssb_sf100.duckdb}"
LOC_DB="${LOC_DB:-/tmp/sf100_local.duckdb}"
V080_LOC="${V080_LOC:-/tmp/old_sf100.duckdb}"
NUMA_NODE="${NUMA_NODE:-0}"
REPS="${REPS:-2}"
PIN="numactl --cpunodebind=${NUMA_NODE} --membind=${NUMA_NODE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/results/corrected_baselines.csv"

parse_time() { grep -oE 'real[[:space:]]+[0-9.]+' | head -1 | awk '{print $2}'; }

measure() {  # measure <bin> <db> <storage> <figure> <series> <name> <sql>
  local BIN="$1" DB="$2" ST="$3" FIG="$4" SER="$5" NAME="$6" SQL="$7" shown=""
  for r in $(seq 1 "$REPS"); do
    local raw sec
    raw=$($PIN "$BIN" "$DB" 2>&1 <<EOSQL
.timer on
${SQL}
EOSQL
)
    sec=$(echo "$raw" | parse_time)
    if echo "$raw" | grep -qE '^Error:|Conversion Error|Binder Error|Catalog Error'; then sec=""; fi
    echo "${FIG},${SER},100,${NAME},${ST},${r},${sec:-}" >> "$OUT"
    shown="$shown ${sec:-ERR}"
  done
  printf "  %-8s %-22s %s\n" "$ST" "$NAME" "$shown"
}

[ -f "$OUT" ] || echo "figure,series,sf,name,storage,rep,seconds" > "$OUT"
[ -f "$LOC_DB" ] || { echo "missing $LOC_DB - copy it first:"; \
                      echo "  cp $NFS_DB $LOC_DB"; exit 1; }

echo "=============================================================="
echo "  SF100   reps=${REPS}   socket=${NUMA_NODE}"
echo "=============================================================="

# Figures 7 and 10: star joins, output materialised. Note `partkey`.
for j in customer part supplier; do
  case $j in
    customer) k="l.column02 = d.column0" ;;
    part)     k="l.partkey  = d.partkey" ;;
    supplier) k="l.column04 = d.column0" ;;
  esac
  SQL="COPY (SELECT * FROM lineorder l JOIN ${j} d ON ${k}) TO '/dev/null' (FORMAT CSV);"
  measure "$V113" "$NFS_DB" nfs   fig7_10 duckdb_latencies "$j" "$SQL"
  measure "$V113" "$LOC_DB" local fig7_10 duckdb_latencies "$j" "$SQL"
done

# Figure 9: select operators.
SQL="COPY (SELECT DISTINCT column00 FROM lineorder) TO '/dev/null' (FORMAT CSV);"
measure "$V113" "$NFS_DB" nfs   fig9 duckdb_distinct C-0 "$SQL"
measure "$V113" "$LOC_DB" local fig9 duckdb_distinct C-0 "$SQL"
SQL="COPY (SELECT * FROM lineorder WHERE column01 = 3) TO '/dev/null' (FORMAT CSV);"
measure "$V113" "$NFS_DB" nfs   fig9 duckdb_where C-1 "$SQL"
measure "$V113" "$LOC_DB" local fig9 duckdb_where C-1 "$SQL"

# Figure 8: self-join, COUNT(*), on v0.8.0 - the binary that figure used.
# v0.8.0 cannot open the v1.x database, so the local measurement uses the
# separate v0.8.0 database. There is no v0.8.0-readable copy on NFS, so the NFS
# column is measured with v1.1.3 instead and is marked accordingly.
SQL="SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column00 = l2.column00;"
measure "$V113" "$NFS_DB"  nfs        fig8 duckdb_ms selfjoin_orderkey_v113 "$SQL"
measure "$V113" "$LOC_DB"  local      fig8 duckdb_ms selfjoin_orderkey_v113 "$SQL"
measure "$V080" "$V080_LOC" local     fig8 duckdb_ms selfjoin_orderkey      "$SQL"

echo
echo "appended to $OUT"
