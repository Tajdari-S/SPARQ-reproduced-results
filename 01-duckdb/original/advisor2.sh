#!/bin/bash
set -euo pipefail

# --------------------------------------
# CONFIGURATION
# --------------------------------------
WORK_DIR="/p/pd/duckdb_work"
DB_FILE="${WORK_DIR}/ssb_sf100.duckdb"

ADVISOR_DIR="${WORK_DIR}/advisor_results1"
DUCKDB_CLI="/p/pd/duckdb_src/build_debug/duckdb"   # Path to rebuilt DuckDB

QUERY="SELECT lo.*, p.* FROM lineorder lo JOIN part p ON lo.partkey = p.partkey;"

# CSV paths
DATE_CSV="/p/pd/ssb-dbgen/sf100/date.tbl"
CUSTOMER_CSV="/p/pd/ssb-dbgen/sf100/customer.tbl"
LINEORDER_CSV="/p/pd/ssb-dbgen/sf100/lineorder.tbl"
PART_CSV="/p/pd/ssb-dbgen/sf100/part.tbl"
SUPPLIER_CSV="/p/pd/ssb-dbgen/sf100/supplier.tbl"

# --------------------------------------
# ENVIRONMENT
# --------------------------------------
source /opt/intel/oneapi/advisor/latest/env/vars.sh

mkdir -p "$WORK_DIR" "$ADVISOR_DIR"

# --------------------------------------
# STEP 1: Create DB if not exists
# --------------------------------------
if [[ ! -f "$DB_FILE" ]]; then
    echo "[*] Creating persistent DuckDB database and uploading tables..."
    $DUCKDB_CLI $DB_FILE <<EOF
CREATE TABLE date AS SELECT * FROM read_csv_auto('$DATE_CSV');
CREATE TABLE customer AS SELECT * FROM read_csv_auto('$CUSTOMER_CSV');
CREATE TABLE lineorder AS 
  SELECT column0 AS orderkey,
         column1 AS linenumber,
         column2 AS custkey,
         column3 AS partkey,
         *
  FROM read_csv_auto('$LINEORDER_CSV');
CREATE TABLE part AS
  SELECT column0 AS partkey,
         *
  FROM read_csv_auto('$PART_CSV');
CREATE TABLE supplier AS SELECT * FROM read_csv_auto('$SUPPLIER_CSV');
EOF
    echo "[*] Tables uploaded to $DB_FILE"
else
    echo "[*] Using existing DuckDB database: $DB_FILE"
fi

# --------------------------------------
# STEP 2: Run Advisor Survey + Tripcounts
# --------------------------------------
RUN_DIR="${ADVISOR_DIR}/run1"
mkdir -p "$RUN_DIR"

echo "[*] Advisor survey collection..."
advisor --collect=survey --project-dir="$RUN_DIR" \
    -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

echo "[*] Advisor tripcounts/FLOPs (with integer ops) collection..."
advisor --collect=tripcounts --flop --project-dir="$RUN_DIR" \
    -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

# --------------------------------------
# STEP 3: Generate Roofline Reports
# --------------------------------------
echo "[*] Generating Advisor roofline reports..."
advisor --report=roofline --project-dir="$RUN_DIR" \
    --report-output="$RUN_DIR/roofline.html"

advisor --report=roofline --project-dir="$RUN_DIR" \
    --report-output="$RUN_DIR/roofline.png"

echo "[*] Done! Roofline results in $RUN_DIR"
