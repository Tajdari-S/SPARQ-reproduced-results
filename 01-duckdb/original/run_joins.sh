#!/bin/bash
set -euo pipefail

# Default number of runs per join query
NUM_RUNS="${NUM_RUNS:-5}"

DUCKDB_BIN="../duckdb"
DATA_DIR="/p/pd/ssb-dbgen/sf100"

# Check if DuckDB exists and is executable
if [[ ! -x "$DUCKDB_BIN" ]]; then
    echo "Error: $DUCKDB_BIN is not executable or does not exist"
    exit 1
fi

# Create timestamp for the profiling session
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="duckdb_profiles_cougar_joins_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

echo "Starting join profiling session at ${TIMESTAMP}"
echo "Output will be stored in ${OUTPUT_DIR}"

SETUP_SQL=$(cat <<'SQL'
-- Optional: use one thread for easier timing interpretation
-- SET threads = 111;

CREATE TABLE date AS
SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/date.tbl');

CREATE TABLE customer AS
SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/customer.tbl');

CREATE TABLE lineorder AS
SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/lineorder.tbl');

CREATE TABLE part AS
SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/part.tbl');

CREATE TABLE supplier AS
SELECT * FROM read_csv_auto('/p/pd/ssb-dbgen/sf100/supplier.tbl');

ALTER TABLE customer RENAME column0 TO custkey;
ALTER TABLE customer RENAME column1 TO name;
ALTER TABLE customer RENAME column2 TO address;
ALTER TABLE customer RENAME column3 TO city;
ALTER TABLE customer RENAME column4 TO nation;
ALTER TABLE customer RENAME column5 TO region;
ALTER TABLE customer RENAME column6 TO phone;
ALTER TABLE customer RENAME column7 TO mktsegment;

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

ALTER TABLE part RENAME column0 TO partkey;
ALTER TABLE part RENAME column1 TO name;
ALTER TABLE part RENAME column2 TO mfgr;
ALTER TABLE part RENAME column3 TO category;
ALTER TABLE part RENAME column4 TO brand1;
ALTER TABLE part RENAME column5 TO color;
ALTER TABLE part RENAME column6 TO type;
ALTER TABLE part RENAME column7 TO size;
ALTER TABLE part RENAME column8 TO container;

ALTER TABLE supplier RENAME column0 TO suppkey;
ALTER TABLE supplier RENAME column1 TO name;
ALTER TABLE supplier RENAME column2 TO address;
ALTER TABLE supplier RENAME column3 TO city;
ALTER TABLE supplier RENAME column4 TO nation;
ALTER TABLE supplier RENAME column5 TO region;
ALTER TABLE supplier RENAME column6 TO phone;

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
ALTER TABLE date RENAME column10 TO weeknuminyear;
ALTER TABLE date RENAME column11 TO sellingseason;
ALTER TABLE date RENAME column12 TO lastdayinweekfl;
ALTER TABLE date RENAME column13 TO lastdayinmonthfl;
ALTER TABLE date RENAME column14 TO holidayfl;
ALTER TABLE date RENAME column15 TO weekdayfl;

PRAGMA enable_profiling='json';
PRAGMA profiling_mode='detailed';
PRAGMA custom_profiling_settings='{
  "CPU_TIME": "true",
  "EXTRA_INFO": "true",
  "OPERATOR_CARDINALITY": "true",
  "OPERATOR_TIMING": "true",
  "BLOCKED_THREAD_TIME": "true",
  "LATENCY": "true",
  "OPERATOR_ROWS_SCANNED": "true",
  "RESULT_SET_SIZE": "true",
  "ROWS_RETURNED": "true"
}';
SQL
)

run_join_benchmark() {
    local label="$1"
    local join_sql="$2"

    echo "Running ${label} ..."

    "$DUCKDB_BIN" <<EOF
${SETUP_SQL}
$(for ((i=1; i<=NUM_RUNS; i++)); do
    printf "PRAGMA profiling_output = './%s/%s_run%02d.json';\n%s\n" \
        "$OUTPUT_DIR" "$label" "$i" "$join_sql"
done)
EOF
}

# Pairwise joins with lineorder + one full star join
JOIN_BENCHMARKS=(
"Join_lineorder_date|SELECT COUNT(*) AS matched_rows FROM lineorder JOIN date ON lineorder.orderdate = date.datekey;"
"Join_lineorder_customer|SELECT COUNT(*) AS matched_rows FROM lineorder JOIN customer ON lineorder.custkey = customer.custkey;"
"Join_lineorder_part|SELECT COUNT(*) AS matched_rows FROM lineorder JOIN part ON lineorder.partkey = part.partkey;"
"Join_lineorder_supplier|SELECT COUNT(*) AS matched_rows FROM lineorder JOIN supplier ON lineorder.suppkey = supplier.suppkey;"
"Join_lineorder_all|SELECT COUNT(*) AS matched_rows
 FROM lineorder
 JOIN date     ON lineorder.orderdate = date.datekey
 JOIN customer ON lineorder.custkey   = customer.custkey
 JOIN part     ON lineorder.partkey   = part.partkey
 JOIN supplier ON lineorder.suppkey   = supplier.suppkey;"
)

for entry in "${JOIN_BENCHMARKS[@]}"; do
    IFS='|' read -r label sql <<< "$entry"
    run_join_benchmark "$label" "$sql"
done

echo "Join profiling session completed!"
echo "All output files are in ${OUTPUT_DIR}"