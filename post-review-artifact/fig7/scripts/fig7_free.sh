#!/bin/bash
# Figure 7's DuckDB series with no numactl: both sockets, DuckDB's default 112
# threads, one fresh process per run, database on local disk.
# Query and databases as in 01-duckdb/scripts/corrected_baselines.sh and
# sf100_baselines.sh: COPY (lineorder JOIN <dim>) TO '/dev/null', DuckDB v1.1.3,
# time = DuckDB's "Run Time (s): real".
#
#   bash fig7_free.sh                 # SF1, SF10, SF100
#   MODES="free mem1 pin1" bash fig7_free.sh 1 10
#
# modes: free (no numactl), mem1 (--membind=1), pin1 (--cpunodebind=1 --membind=1)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUCKDB="${DUCKDB:-/p/pd/newduckdb/duckdb}"
LOCAL_DIR="${LOCAL_DIR:-/tmp/figdb_local}"                  # ssb_sf1.duckdb, ssb_sf10.duckdb
SF100_DB="${SF100_DB:-/localtmp/$USER/ssb_sf100.duckdb}"    # local copy of /p/pd/duckdb_work/ssb_sf100.duckdb
MODES="${MODES:-free}"
OUT="${OUT:-$HERE/results/fig7_free.csv}"
SFS=("$@"); [ ${#SFS[@]} -eq 0 ] && SFS=(1 10 100)
declare -A PIN=([free]="" [mem1]="numactl --membind=1" [pin1]="numactl --cpunodebind=1 --membind=1")

echo "sf,name,mode,rep,seconds" > "$OUT"
for SF in "${SFS[@]}"; do
  case $SF in 100) DB=$SF100_DB; REPS=2;; *) DB=$LOCAL_DIR/ssb_sf$SF.duckdb; REPS=3;; esac
  [ -f "$DB" ] || { echo "missing $DB"; exit 1; }
  cat "$DB" > /dev/null   # page cache warm before the first run
  for j in customer part supplier; do
    case $j in
      customer) k="l.column02 = d.column0" ;;
      part)     k="l.column03 = d.column0"; [ "$SF" = 100 ] && k="l.partkey = d.partkey" ;;  # SF100 db renamed it
      supplier) k="l.column04 = d.column0" ;;
    esac
    SQL="COPY (SELECT * FROM lineorder l JOIN ${j} d ON ${k}) TO '/dev/null' (FORMAT CSV);"
    for r in $(seq 1 $REPS); do
      for m in $MODES; do
        raw=$(printf '.timer on\n%s\n' "$SQL" | ${PIN[$m]} "$DUCKDB" "$DB" 2>&1)
        sec=$(echo "$raw" | grep -oE 'real[[:space:]]+[0-9.]+' | head -1 | awk '{print $2}')
        echo "$raw" | grep -qE 'Error' && { echo "$raw" | grep Error >&2; sec=""; }
        echo "$SF,$j,$m,$r,${sec}" | tee -a "$OUT"
      done
    done
  done
done
