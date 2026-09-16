#!/usr/bin/env bash
# Figures 1 and 11: the 13 SSB queries at SF100, reproducing DucDBSSBFullQUery.sh.
#
# That script invokes `../duckdb <<EOF` with NO database file, so the tables live
# in memory, and it does so THIRTEEN times - once per query. Each invocation
# loads all five tables from /p/pd/ssb-dbgen/sf100 and only then enables
# profiling, so the timed query runs against data already in RAM.
#
# Consequence: unlike Figures 7-10, these measurements are NOT affected by the
# database being on NFS. The network cost lands in the untimed setup load. There
# is therefore no NFS-vs-local column here - it would be measuring the same
# thing twice.
#
# Each query runs NUM_RUNS times inside its invocation. Run 1 is the cold value
# (first execution, nothing cached in the operators); the mean of the rest is the
# warm value. That is the cold/warm split Fig11.py plots.
#
# This is slow: thirteen invocations, each parsing the 68 GB SF100 lineorder.
# Expect hours. Launch under screen.
set -uo pipefail

DUCKDB="${DUCKDB:-/p/pd/newduckdb/duckdb}"
PROFDIR="${PROFDIR:-/tmp/f11prof}"
VTAG="${VTAG:-v1.1.3}"
DATA="${DATA:-/p/pd/ssb-dbgen/sf100}"
NUM_RUNS="${NUM_RUNS:-5}"
MODE="${MODE:?MODE=none|mem0|mem1|cpumem1}"
case "$MODE" in
  none)    PIN="" ;;
  mem0)    PIN="numactl --membind=0" ;;
  mem1)    PIN="numactl --membind=1" ;;
  cpumem1) PIN="numactl --cpunodebind=1 --membind=1" ;;
esac
OUT="${OUTDIR:?}/fig11_${VTAG}_${MODE}_${QUERIES// /_}.csv"
PROFDIR="${OUTDIR}/prof_${MODE}_${QUERIES// /_}"
mkdir -p "$OUTDIR" "$PROFDIR"
echo "query,run,seconds,cpu_time,join_share,peak_note" > "$OUT"

SETUP="
CREATE TABLE date AS SELECT * FROM read_csv_auto('${DATA}/date.tbl');
CREATE TABLE customer AS SELECT * FROM read_csv_auto('${DATA}/customer.tbl');
CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('${DATA}/lineorder.tbl');
CREATE TABLE part AS SELECT * FROM read_csv_auto('${DATA}/part.tbl');
CREATE TABLE supplier AS SELECT * FROM read_csv_auto('${DATA}/supplier.tbl');
ALTER TABLE customer RENAME column0 TO custkey; ALTER TABLE customer RENAME column1 TO name; ALTER TABLE customer RENAME column2 TO address; ALTER TABLE customer RENAME column3 TO city; ALTER TABLE customer RENAME column4 TO nation; ALTER TABLE customer RENAME column5 TO region; ALTER TABLE customer RENAME column6 TO phone; ALTER TABLE customer RENAME column7 TO mktsegment;
ALTER TABLE lineorder RENAME column00 TO orderkey; ALTER TABLE lineorder RENAME column01 TO linenumber; ALTER TABLE lineorder RENAME column02 TO custkey; ALTER TABLE lineorder RENAME column03 TO partkey; ALTER TABLE lineorder RENAME column04 TO suppkey; ALTER TABLE lineorder RENAME column05 TO orderdate; ALTER TABLE lineorder RENAME column06 TO orderpriority; ALTER TABLE lineorder RENAME column07 TO shippriority; ALTER TABLE lineorder RENAME column08 TO quantity; ALTER TABLE lineorder RENAME column09 TO extendedprice; ALTER TABLE lineorder RENAME column10 TO ordtotalprice; ALTER TABLE lineorder RENAME column11 TO discount; ALTER TABLE lineorder RENAME column12 TO revenue; ALTER TABLE lineorder RENAME column13 TO supplycost; ALTER TABLE lineorder RENAME column14 TO tax; ALTER TABLE lineorder RENAME column15 TO commitdate; ALTER TABLE lineorder RENAME column16 TO shipmode;
ALTER TABLE part RENAME column0 TO partkey; ALTER TABLE part RENAME column1 TO name; ALTER TABLE part RENAME column2 TO mfgr; ALTER TABLE part RENAME column3 TO category; ALTER TABLE part RENAME column4 TO brand1; ALTER TABLE part RENAME column5 TO color; ALTER TABLE part RENAME column6 TO type; ALTER TABLE part RENAME column7 TO size; ALTER TABLE part RENAME column8 TO container;
ALTER TABLE supplier RENAME column0 TO suppkey; ALTER TABLE supplier RENAME column1 TO name; ALTER TABLE supplier RENAME column2 TO address; ALTER TABLE supplier RENAME column3 TO city; ALTER TABLE supplier RENAME column4 TO nation; ALTER TABLE supplier RENAME column5 TO region; ALTER TABLE supplier RENAME column6 TO phone;
ALTER TABLE date RENAME column00 TO datekey; ALTER TABLE date RENAME column01 TO date; ALTER TABLE date RENAME column02 TO dayofweek; ALTER TABLE date RENAME column03 TO month; ALTER TABLE date RENAME column04 TO year; ALTER TABLE date RENAME column05 TO yearmonthnum; ALTER TABLE date RENAME column06 TO yearmonth; ALTER TABLE date RENAME column07 TO daynuminweek; ALTER TABLE date RENAME column08 TO daynuminyear; ALTER TABLE date RENAME column09 TO monthnuminyear; ALTER TABLE date RENAME column10 TO weeknuminyear; ALTER TABLE date RENAME column11 TO sellingseason; ALTER TABLE date RENAME column12 TO lastdayinweekfl; ALTER TABLE date RENAME column13 TO lastdayinmonthfl; ALTER TABLE date RENAME column14 TO holidayfl; ALTER TABLE date RENAME column15 TO weekdayfl;
"
# NOTE: this rename mapping is copied verbatim from DucDBSSBFullQUery.sh so the
# measurements stay comparable with the plotted ones. It is shifted by one from
# column08 onward - see NOTES.md #7 - which makes Q1.3 filter monthnuminyear
# while calling it weeknuminyear. Fixing it here would change Q1.3's value and
# break comparability, so it is left as-is and flagged instead.

queries() {
  cat <<'EOQ'
Q1.1|select sum(extendedprice*discount) as revenue from lineorder, date where orderdate = datekey and year = 1993 and discount between 1 and 3 and quantity < 25;
Q1.2|select sum(extendedprice*discount) as revenue from lineorder, date where orderdate = datekey and yearmonthnum = 199401 and discount between 4 and 6 and quantity between 26 and 35;
Q1.3|select sum(extendedprice*discount) as revenue from lineorder, date where orderdate = datekey and weeknuminyear = 6 and year = 1994 and discount between 5 and 7 and quantity between 26 and 35;
Q2.1|select sum(lineorder.revenue), year, brand1 from lineorder, date, part, supplier where lineorder.orderdate = date.datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and part.category = 'MFGR#12' and supplier.region = 'AMERICA' group by year, brand1 order by year, brand1;
Q2.2|select sum(lineorder.revenue), year, brand1 from lineorder, date, part, supplier where lineorder.orderdate = date.datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and part.brand1 between 'MFGR#2221' and 'MFGR#2228' and supplier.region = 'ASIA' group by year, brand1 order by year, brand1;
Q2.3|select sum(lineorder.revenue), year, brand1 from lineorder, date, part, supplier where lineorder.orderdate = date.datekey and lineorder.partkey = part.partkey and lineorder.suppkey = supplier.suppkey and part.brand1 = 'MFGR#2239' and supplier.region = 'EUROPE' group by year, brand1 order by year, brand1;
Q3.1|select customer.nation, supplier.nation, year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and customer.region = 'ASIA' and supplier.region = 'ASIA' and year >= 1992 and year <= 1997 group by customer.nation, supplier.nation, year order by year asc, revenue desc;
Q3.2|select customer.city, supplier.city, year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and customer.nation = 'UNITED STATES' and supplier.nation = 'UNITED STATES' and year >= 1992 and year <= 1997 group by customer.city, supplier.city, year order by year asc, revenue desc;
Q3.3|select customer.city, supplier.city, year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and (customer.city='UNITED KI1' or customer.city='UNITED KI5') and (supplier.city='UNITED KI1' or supplier.city='UNITED KI5') and year >= 1992 and year <= 1997 group by customer.city, supplier.city, year order by year asc, revenue desc;
Q3.4|select customer.city, supplier.city, year, sum(lineorder.revenue) as revenue from customer, lineorder, supplier, date where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.orderdate = date.datekey and (customer.city='UNITED KI1' or customer.city='UNITED KI5') and (supplier.city='UNITED KI1' or supplier.city='UNITED KI5') and yearmonth = 'Dec1997' group by customer.city, supplier.city, year order by year asc, revenue desc;
Q4.1|select year, customer.nation, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and customer.region = 'AMERICA' and supplier.region = 'AMERICA' and (mfgr = 'MFGR#1' or mfgr = 'MFGR#2') group by year, customer.nation order by year, customer.nation;
Q4.2|select year, supplier.nation, category, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and customer.region = 'AMERICA' and supplier.region = 'AMERICA' and (year = 1997 or year = 1998) and (mfgr = 'MFGR#1' or mfgr = 'MFGR#2') group by year, supplier.nation, category order by year, supplier.nation, category;
Q4.3|select year, supplier.city, brand1, sum(lineorder.revenue - lineorder.supplycost) as profit from date, customer, supplier, part, lineorder where lineorder.custkey = customer.custkey and lineorder.suppkey = supplier.suppkey and lineorder.partkey = part.partkey and lineorder.orderdate = date.datekey and supplier.nation = 'UNITED STATES' and (year = 1997 or year = 1998) and category = 'MFGR#14' group by year, supplier.city, brand1 order by year, supplier.city, brand1;
EOQ
}

echo "SF100 SSB, in-memory, ${NUM_RUNS} runs per query, one process per query"
echo "binary: ${DUCKDB}   profiles -> ${PROFDIR}"
echo "measurement: PRAGMA enable_profiling='json' + profiling_output, as in DucDBSSBFullQUery.sh"
while IFS='|' read -r qn qs; do
  [ -z "$qn" ] && continue
  case " ${QUERIES:-} " in *" $qn "*) ;; *) [ -n "${QUERIES:-}" ] && continue ;; esac
  echo "--- ${qn} $(date '+%H:%M:%S') ---"
  RUNS=""
  for i in $(seq 1 "$NUM_RUNS"); do
    RUNS="${RUNS}PRAGMA profiling_output = '${PROFDIR}/Query_${qn}_run$(printf %02d $i).json'; ${qs}
"
  done
  $PIN "$DUCKDB" >/dev/null 2>"${OUTDIR}/err_${MODE}_${qn}.txt" <<SQL
${SETUP}
PRAGMA enable_profiling='json';
PRAGMA profiling_mode='detailed';
PRAGMA custom_profiling_settings='{"CPU_TIME": "true", "EXTRA_INFO": "true", "OPERATOR_CARDINALITY": "true", "OPERATOR_TIMING": "true", "BLOCKED_THREAD_TIME": "true", "LATENCY": "true", "OPERATOR_ROWS_SCANNED": "true", "RESULT_SET_SIZE": "true", "ROWS_RETURNED": "true"}';
${RUNS}
SQL
  RC=$?
  for i in $(seq 1 "$NUM_RUNS"); do
    f="${PROFDIR}/Query_${qn}_run$(printf %02d $i).json"
    row=$(python3 -c "
import json
def walk(n, out):
    for c in n.get('children', []):
        name = (c.get('operator_type') or c.get('name') or '').strip()
        t = c.get('operator_timing', c.get('timing', 0)) or 0
        out.append((name, float(t))); walk(c, out)
    return out
try:
    d = json.load(open('$f'))
    ops = walk(d, []); tot = sum(t for _, t in ops); j = sum(t for n, t in ops if 'JOIN' in n)
    lat = d.get('latency', d.get('timing', d.get('result', '')))
    print(f\"{lat},{d.get('cpu_time','')},{(j/tot if tot else '')}\")
except Exception: print(',,')
" 2>/dev/null)
    echo "${qn},${i},${row},${RC}" >> "$OUT"
  done
  echo "  rc=$RC  $(awk -F, -v q="$qn" '$1==q{printf "%s ",$3}' "$OUT")"
done < <(queries)

echo
echo "results -> $OUT"
echo "cold = run 1; warm = mean of runs 2..${NUM_RUNS}"
