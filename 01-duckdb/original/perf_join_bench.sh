#!/bin/bash
# perf_join_bench.sh — Full join latency breakdown for SF1 and SF10
# Runs DuckDB profiling + perf record + perf stat for each join type
set +e
module load perf/6.11 2>/dev/null

DUCKDB=/p/pd/newduckdb/duckdb
DATA_BASE=/p/pd/ssb-dbgen
OUTDIR=/p/pd/newduckdb/scripts/bench_results
mkdir -p "$OUTDIR"

# Table setup SQL (same schema as join_cost_analyzer.py)
setup_sql() {
    local d=$1
    cat <<EOSQL
CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('${d}/lineorder.tbl', null_padding=true, ignore_errors=true);
ALTER TABLE lineorder RENAME column00 TO orderkey;
ALTER TABLE lineorder RENAME column01 TO linenumber;
ALTER TABLE lineorder RENAME column02 TO custkey;
ALTER TABLE lineorder RENAME column03 TO partkey;
ALTER TABLE lineorder RENAME column04 TO suppkey;
ALTER TABLE lineorder RENAME column05 TO orderdate;
ALTER TABLE lineorder RENAME column06 TO orderpriority;
ALTER TABLE lineorder RENAME column07 TO shippriority;
ALTER TABLE lineorder RENAME column08 TO quantity;
ALTER TABLE lineorder RENAME column09 TO extendedprice;
ALTER TABLE lineorder RENAME column10 TO ordtotalprice;
ALTER TABLE lineorder RENAME column11 TO discount;
ALTER TABLE lineorder RENAME column12 TO revenue;
ALTER TABLE lineorder RENAME column13 TO supplycost;
ALTER TABLE lineorder RENAME column14 TO tax;
ALTER TABLE lineorder RENAME column15 TO commitdate;
ALTER TABLE lineorder RENAME column16 TO shipmode;

CREATE TABLE date AS SELECT * FROM read_csv_auto('${d}/date.tbl', null_padding=true, ignore_errors=true);
ALTER TABLE date RENAME column00 TO datekey;
ALTER TABLE date RENAME column01 TO date;
ALTER TABLE date RENAME column02 TO dayofweek;
ALTER TABLE date RENAME column03 TO month;
ALTER TABLE date RENAME column04 TO year;
ALTER TABLE date RENAME column05 TO yearmonthnum;
ALTER TABLE date RENAME column06 TO yearmonth;
ALTER TABLE date RENAME column07 TO daynuminweek;
ALTER TABLE date RENAME column08 TO daynuminyear;
ALTER TABLE date RENAME column09 TO monthnuminyear;
ALTER TABLE date RENAME column10 TO daynuminmonth;
ALTER TABLE date RENAME column11 TO weeknuminyear;
ALTER TABLE date RENAME column12 TO sellingseason;
ALTER TABLE date RENAME column13 TO lastdayinweekfl;
ALTER TABLE date RENAME column14 TO lastdayinmonthfl;
ALTER TABLE date RENAME column15 TO holidayfl;
ALTER TABLE date RENAME column16 TO weekdayfl;

CREATE TABLE customer AS SELECT * FROM read_csv_auto('${d}/customer.tbl', null_padding=true, ignore_errors=true);
ALTER TABLE customer RENAME column0 TO custkey;
ALTER TABLE customer RENAME column1 TO name;
ALTER TABLE customer RENAME column2 TO address;
ALTER TABLE customer RENAME column3 TO city;
ALTER TABLE customer RENAME column4 TO nation;
ALTER TABLE customer RENAME column5 TO region;
ALTER TABLE customer RENAME column6 TO phone;
ALTER TABLE customer RENAME column7 TO mktsegment;

CREATE TABLE part AS SELECT * FROM read_csv_auto('${d}/part.tbl', null_padding=true, ignore_errors=true);
ALTER TABLE part RENAME column0 TO partkey;
ALTER TABLE part RENAME column1 TO name;
ALTER TABLE part RENAME column2 TO mfgr;
ALTER TABLE part RENAME column3 TO category;
ALTER TABLE part RENAME column4 TO brand;
ALTER TABLE part RENAME column5 TO color;
ALTER TABLE part RENAME column6 TO type;
ALTER TABLE part RENAME column7 TO size;
ALTER TABLE part RENAME column8 TO container;

CREATE TABLE supplier AS SELECT * FROM read_csv_auto('${d}/supplier.tbl', null_padding=true, ignore_errors=true);
ALTER TABLE supplier RENAME column0 TO suppkey;
ALTER TABLE supplier RENAME column1 TO name;
ALTER TABLE supplier RENAME column2 TO address;
ALTER TABLE supplier RENAME column3 TO city;
ALTER TABLE supplier RENAME column4 TO nation;
ALTER TABLE supplier RENAME column5 TO region;
ALTER TABLE supplier RENAME column6 TO phone;
EOSQL
}

PROFILING_PREAMBLE="PRAGMA enable_profiling='json';
PRAGMA profiling_mode='detailed';
PRAGMA custom_profiling_settings='{
  \"CPU_TIME\": \"true\",
  \"EXTRA_INFO\": \"true\",
  \"OPERATOR_CARDINALITY\": \"true\",
  \"OPERATOR_TIMING\": \"true\",
  \"BLOCKED_THREAD_TIME\": \"true\",
  \"LATENCY\": \"true\",
  \"OPERATOR_ROWS_SCANNED\": \"true\",
  \"RESULT_SET_SIZE\": \"true\",
  \"ROWS_RETURNED\": \"true\"
}';"

# Joins to benchmark
declare -A QUERIES
QUERIES[date]="SELECT COUNT(*) FROM lineorder JOIN date ON lineorder.orderdate = date.datekey;"
QUERIES[customer]="SELECT COUNT(*) FROM lineorder JOIN customer ON lineorder.custkey = customer.custkey;"
QUERIES[part]="SELECT COUNT(*) FROM lineorder JOIN part ON lineorder.partkey = part.partkey;"
QUERIES[supplier]="SELECT COUNT(*) FROM lineorder JOIN supplier ON lineorder.suppkey = supplier.suppkey;"
QUERIES[selfjoin]="SELECT COUNT(*) FROM lineorder a JOIN lineorder b ON a.orderkey = b.orderkey;"
QUERIES[all4]="SELECT COUNT(*) FROM lineorder JOIN date ON lineorder.orderdate = date.datekey JOIN customer ON lineorder.custkey = customer.custkey JOIN part ON lineorder.partkey = part.partkey JOIN supplier ON lineorder.suppkey = supplier.suppkey;"

PERF_EVENTS="cycles,instructions,cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses,LLC-loads,LLC-load-misses"

for SF in 1 10; do
    DATA="${DATA_BASE}/sf${SF}"
    DBFILE="${OUTDIR}/sf${SF}.duckdb"
    echo "========================================"
    echo "  SF${SF}: Creating database from ${DATA}"
    echo "========================================"

    rm -f "$DBFILE" "${DBFILE}.wal"
    setup_sql "$DATA" | $DUCKDB "$DBFILE"

    # Verify
    echo "Tables in SF${SF}:"
    echo "SELECT table_name, estimated_size FROM duckdb_tables();" | $DUCKDB --readonly "$DBFILE"

    for JOIN in date customer part supplier selfjoin all4; do
        QUERY="${QUERIES[$JOIN]}"
        echo ""
        echo "--- SF${SF} / ${JOIN} ---"
        echo "Query: ${QUERY}"

        # 1) DuckDB profiling (3 runs, keep last)
        PROFILE_OUT="${OUTDIR}/sf${SF}_${JOIN}_profile.json"
        for run in 1 2 3; do
            PROFILE_SQL="${PROFILING_PREAMBLE}
PRAGMA profiling_output='${PROFILE_OUT}';
${QUERY}"
            echo "$PROFILE_SQL" | $DUCKDB --readonly "$DBFILE" > /dev/null 2>&1
        done
        echo "  Profile saved: ${PROFILE_OUT}"

        # 2) perf record (function-level sampling)
        PERF_DATA="${OUTDIR}/sf${SF}_${JOIN}_perf.data"
        perf record -g -o "$PERF_DATA" -- $DUCKDB --readonly "$DBFILE" "$QUERY" > /dev/null 2>&1
        echo "  perf record done: $(perf report -i "$PERF_DATA" --stdio --no-children --percent-limit 0.5 2>&1 | grep -c '%' ) functions > 0.5%"

        # 3) perf stat (hardware counters, 3 runs averaged)
        PERF_STAT="${OUTDIR}/sf${SF}_${JOIN}_perfstat.txt"
        perf stat -r 3 -e "$PERF_EVENTS" -- $DUCKDB --readonly "$DBFILE" "$QUERY" > /dev/null 2>"$PERF_STAT"
        echo "  perf stat saved: ${PERF_STAT}"

        # 4) Flat perf report
        PERF_REPORT="${OUTDIR}/sf${SF}_${JOIN}_perfreport.txt"
        perf report -i "$PERF_DATA" --stdio --no-children --percent-limit 0.5 2>&1 > "$PERF_REPORT"
        echo "  perf report saved: ${PERF_REPORT}"
    done

    rm -f "$DBFILE" "${DBFILE}.wal"
    echo ""
    echo "SF${SF} complete, DB removed."
done

echo ""
echo "All benchmarks complete. Results in ${OUTDIR}/"
ls -la "${OUTDIR}/"
