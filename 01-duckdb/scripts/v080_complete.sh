#!/usr/bin/env bash
# Fill the v0.8.0 gaps so every affected figure can be plotted under both
# binaries.
#
# Already held (local disk, from the version-comparison runs):
#   Fig 7/10 star joins  SF1, SF10
#   Fig 8 self-join      SF1, SF10, SF100
#   Fig 9 C-0 and C-1    SF1, SF10
#
# Missing, and filled here:
#   Fig 7/10 star joins + date   SF100
#   Fig 9 all six columns        SF100
#   Fig 9 columns C-2..C-5       SF1, SF10
#
# v0.8.0 cannot open a v1.x database, so this uses v0.8.0-format databases:
#   SF100  /tmp/all_sf100.duckdb   (5 tables, built earlier in this session)
#   SF1/10 rebuilt here from ssb-dbgen, since the earlier ones were deleted to
#          reclaim disk. Disk is tight - SF10 is skipped if space is short.
set -uo pipefail

V080="${V080:-/p/pd/newgem5/gem5/duckdb}"
NUMA_NODE="${NUMA_NODE:-0}"
REPS="${REPS:-2}"
PIN="numactl --cpunodebind=${NUMA_NODE} --membind=${NUMA_NODE}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${HERE}/results/v080_complete.csv"
mkdir -p "$(dirname "$OUT")"
echo "figure,series,sf,name,version,storage,rep,seconds" > "$OUT"
parse_time() { grep -oE 'real[[:space:]]+[0-9.]+' | head -1 | awk '{print $2}'; }

measure() {  # measure <db> <figure> <series> <sf> <name> <sql>
  local DB="$1" FIG="$2" SER="$3" SF="$4" NAME="$5" SQL="$6" shown=""
  for r in $(seq 1 "$REPS"); do
    local raw sec
    raw=$($PIN "$V080" "$DB" 2>&1 <<EOSQL
.timer on
${SQL}
EOSQL
)
    sec=$(echo "$raw" | parse_time)
    echo "$raw" | grep -qE '^Error:|Binder Error|Conversion Error|Catalog Error' && sec=""
    echo "${FIG},${SER},${SF},${NAME},v0.8.0,local,${r},${sec:-}" >> "$OUT"
    shown="$shown ${sec:-ERR}"
  done
  printf "  SF%-4s %-10s %-18s %s\n" "$SF" "$FIG" "$NAME" "$shown"
}

# ---------------------------------------------------------------- SF100 ------
DB100=/tmp/all_sf100.duckdb
if [ -f "$DB100" ]; then
  echo "### SF100 (v0.8.0, $DB100)"
  # discover the key spellings rather than assume
  PK=$($V080 "$DB100" -noheader -list -c "select column_name from information_schema.columns where table_name='part' order by ordinal_position limit 1;" 2>/dev/null)
  LP=$($V080 "$DB100" -noheader -list -c "select column_name from information_schema.columns where table_name='lineorder' order by ordinal_position limit 4;" 2>/dev/null | tail -1)
  echo "  part key='${PK}'  lineorder 4th col='${LP}'"
  for spec in "customer:column02:column0" "part:${LP}:${PK}" "supplier:column04:column0"; do
    t=${spec%%:*}; rest=${spec#*:}; lk=${rest%%:*}; rk=${rest##*:}
    measure "$DB100" fig7_10 duckdb_latencies 100 "$t" \
      "COPY (SELECT * FROM lineorder l JOIN ${t} d ON l.${lk} = d.${rk}) TO '/dev/null' (FORMAT CSV);"
  done
  # date join: try the plausible spellings
  for key in "l.column05 = d.column00" "l.column05 = d.datekey"; do
    if $V080 "$DB100" -c "SELECT COUNT(*) FROM lineorder l JOIN date d ON ${key};" >/dev/null 2>&1; then
      measure "$DB100" fig7_10 duckdb_latencies 100 date \
        "COPY (SELECT * FROM lineorder l JOIN date d ON ${key}) TO '/dev/null' (FORMAT CSV);"
      break
    fi
  done
  # Figure 9, all six columns
  preds=("column00 = 50000000" "column01 = 3" "column02 = 1000000" "column03 = 500000" "column04 = 100000" "column05 = 19960102")
  for i in 0 1 2 3 4 5; do
    c="column0${i}"; p="${preds[$i]}"
    measure "$DB100" fig9 duckdb_distinct 100 "C-${i}" "COPY (SELECT DISTINCT ${c} FROM lineorder) TO '/dev/null' (FORMAT CSV);"
    measure "$DB100" fig9 duckdb_where    100 "C-${i}" "COPY (SELECT * FROM lineorder WHERE ${p}) TO '/dev/null' (FORMAT CSV);"
  done
else
  echo "### SF100 skipped - $DB100 missing"
fi

# ------------------------------------------------------------ SF1 / SF10 -----
RENAME_NONE=""
for SF in 1 10; do
  DATA=/p/pd/ssb-dbgen/sf${SF}
  DB=/tmp/v080_sf${SF}.duckdb
  NEED=$([ "$SF" = 1 ] && echo 300000 || echo 2500000)   # KB headroom needed
  AVAIL=$(df -k /tmp | tail -1 | awk '{print $4}')
  if [ "$AVAIL" -lt "$NEED" ]; then
    echo "### SF${SF} skipped - only $((AVAIL/1024)) MB free, need $((NEED/1024)) MB"
    continue
  fi
  echo "### SF${SF} (v0.8.0) building $DB"
  rm -f "$DB"
  $PIN "$V080" "$DB" >/dev/null 2>&1 <<SQL
CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('${DATA}/lineorder.tbl', delim=',', header=false, ignore_errors=true);
CREATE TABLE customer  AS SELECT * FROM read_csv_auto('${DATA}/customer.tbl',  delim=',', header=false, ignore_errors=true);
CREATE TABLE part      AS SELECT * FROM read_csv_auto('${DATA}/part.tbl',      delim=',', header=false, ignore_errors=true, quote='');
CREATE TABLE supplier  AS SELECT * FROM read_csv_auto('${DATA}/supplier.tbl',  delim=',', header=false, ignore_errors=true);
CREATE TABLE date      AS SELECT * FROM read_csv_auto('${DATA}/date.tbl',      delim=',', header=false, ignore_errors=true);
SQL
  if [ "$SF" = 1 ]; then
    preds=("column00 = 1000000" "column01 = 3" "column02 = 10000" "column03 = 100000" "column04 = 500" "column05 = DATE '1995-02-18'")
  else
    preds=("column00 = 5000000" "column01 = 3" "column02 = 100000" "column03 = 300000" "column04 = 10000" "column05 = DATE '1995-02-18'")
  fi
  for i in 2 3 4 5; do    # C-0 and C-1 already measured
    c="column0${i}"; p="${preds[$i]}"
    measure "$DB" fig9 duckdb_distinct "$SF" "C-${i}" "COPY (SELECT DISTINCT ${c} FROM lineorder) TO '/dev/null' (FORMAT CSV);"
    measure "$DB" fig9 duckdb_where    "$SF" "C-${i}" "COPY (SELECT * FROM lineorder WHERE ${p}) TO '/dev/null' (FORMAT CSV);"
  done
  rm -f "$DB"     # reclaim immediately; disk is tight
done

echo
echo "results -> $OUT"
