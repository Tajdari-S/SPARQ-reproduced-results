#!/bin/bash
set -euo pipefail

# --------------------------------------
# CONFIGURATION
# --------------------------------------
WORK_DIR="/p/pd/duckdb_work"
DB_FILE="${WORK_DIR}/ssb_sf100.duckdb"

VTUNE_DIR="${WORK_DIR}/vtune_results"
ADVISOR_DIR="${WORK_DIR}/advisor_results"

DUCKDB_CLI="../duckdb"   # Path to DuckDB CLI
QUERY="SELECT lo.*, p.* FROM lineorder lo JOIN part p ON lo.partkey = p.partkey;"
NUM_RUNS=1

# CSV paths
DATE_CSV="/p/pd/ssb-dbgen/sf100/date.tbl"
CUSTOMER_CSV="/p/pd/ssb-dbgen/sf100/customer.tbl"
LINEORDER_CSV="/p/pd/ssb-dbgen/sf100/lineorder.tbl"
PART_CSV="/p/pd/ssb-dbgen/sf100/part.tbl"
SUPPLIER_CSV="/p/pd/ssb-dbgen/sf100/supplier.tbl"

# --------------------------------------
# ENVIRONMENT
# --------------------------------------
source /opt/intel/oneapi/vtune/latest/env/vars.sh
source /opt/intel/oneapi/advisor/latest/env/vars.sh

mkdir -p "$WORK_DIR" "$VTUNE_DIR" "$ADVISOR_DIR"

# --------------------------------------
# STEP 1: Upload tables to persistent DB
# --------------------------------------
if [[ ! -f "$DB_FILE" ]]; then
    echo "[*] Creating persistent DuckDB database and uploading tables..."
    $DUCKDB_CLI $DB_FILE <<EOF
CREATE TABLE date AS SELECT * FROM read_csv_auto('$DATE_CSV');
CREATE TABLE customer AS SELECT * FROM read_csv_auto('$CUSTOMER_CSV');
CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('$LINEORDER_CSV');
CREATE TABLE part AS SELECT * FROM read_csv_auto('$PART_CSV');
CREATE TABLE supplier AS SELECT * FROM read_csv_auto('$SUPPLIER_CSV');

-- Adjust column renaming if needed (inspect schema first!)
-- Example assuming CSV auto-generated names like column3:
ALTER TABLE lineorder RENAME column03 TO partkey;
ALTER TABLE part RENAME column0 TO partkey;
EOF
    echo "[*] Tables uploaded to $DB_FILE"
else
    echo "[*] Using existing DuckDB database: $DB_FILE"
fi

# --------------------------------------
# STEP 2: Run profiling
# --------------------------------------
for i in $(seq 1 $NUM_RUNS); do
    VTUNE_RUN_DIR="${VTUNE_DIR}/run${i}"
    ADV_RUN_DIR="${ADVISOR_DIR}/run${i}"

    mkdir -p "$VTUNE_RUN_DIR" "$ADV_RUN_DIR"

    echo "[*] Advisor survey collection..."
    advisor --collect=survey --project-dir="$ADV_RUN_DIR" \
        -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

    echo "[*] Advisor tripcounts/FLOPs collection..."
    advisor --collect=tripcounts --flop --project-dir="$ADV_RUN_DIR" \
        -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

    echo "[*] Generating Advisor roofline report..."
    advisor --report=roofline --project-dir="$ADV_RUN_DIR" \
        --report-output="${ADV_RUN_DIR}/roofline.html"

    echo "[*] VTune memory-access collection..."
    vtune -collect memory-access -result-dir "$VTUNE_RUN_DIR/memory" \
        -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

    echo "[*] VTune uarch-exploration collection..."
    vtune -collect uarch-exploration -result-dir "$VTUNE_RUN_DIR/uarch" \
        -- "$DUCKDB_CLI" "$DB_FILE" -c "$QUERY"

    echo "[*] Profiling completed for run $i."
done

echo "[*] All runs completed. Results:"
echo "  - VTune:   $VTUNE_DIR"
echo "  - Advisor: $ADVISOR_DIR"
