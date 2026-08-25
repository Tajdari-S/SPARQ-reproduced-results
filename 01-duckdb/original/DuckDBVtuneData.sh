#!/bin/bash
# Create a writable directory in /p/pd
mkdir -p /p/pd/duckdb_work
chmod 777 /p/pd/duckdb_work   # or adjust ownership to your user

# Paths
DB_FILE="/p/pd/duckdb_work/ssb_sf100.duckdb"
VTUNE_RESULT_DIR="/p/pd/duckdb_work/vtune_join_results"
mkdir -p $VTUNE_RESULT_DIR
chmod 777 $VTUNE_RESULT_DIR

source /opt/intel/oneapi/vtune/latest/env/vars.sh

# --------------------------------------
# CONFIGURATION
# --------------------------------------
DUCKDB_CLI="../duckdb"                  # Path to DuckDB CLI
DB_FILE="ssb_sf100.duckdb"             # Persistent DuckDB file
VTUNE_RESULT_DIR="vtune_join_results"  # VTune output directory
QUERY="SELECT lo.*, p.* FROM lineorder lo JOIN part p ON lo.partkey = p.partkey;" # Example join
NUM_RUNS=1                              # Number of VTune runs

# CSV paths
DATE_CSV="/p/pd/ssb-dbgen/sf100/date.tbl"
CUSTOMER_CSV="/p/pd/ssb-dbgen/sf100/customer.tbl"
LINEORDER_CSV="/p/pd/ssb-dbgen/sf100/lineorder.tbl"
PART_CSV="/p/pd/ssb-dbgen/sf100/part.tbl"
SUPPLIER_CSV="/p/pd/ssb-dbgen/sf100/supplier.tbl"

# --------------------------------------
# STEP 1: Upload tables to persistent DB
# --------------------------------------
echo "[*] Creating persistent DuckDB database and uploading tables..."
$DUCKDB_CLI $DB_FILE <<EOF
-- Create tables from CSV
CREATE TABLE date AS SELECT * FROM read_csv_auto('$DATE_CSV');
CREATE TABLE customer AS SELECT * FROM read_csv_auto('$CUSTOMER_CSV');
CREATE TABLE lineorder AS SELECT * FROM read_csv_auto('$LINEORDER_CSV');
CREATE TABLE part AS SELECT * FROM read_csv_auto('$PART_CSV');
CREATE TABLE supplier AS SELECT * FROM read_csv_auto('$SUPPLIER_CSV');

-- Optional: Rename columns (if needed)
ALTER TABLE lineorder RENAME column03 TO partkey;
ALTER TABLE part RENAME column0 TO partkey;
EOF
echo "[*] Tables uploaded to $DB_FILE"

# --------------------------------------
# STEP 2: Run join query with VTune memory profiling
# --------------------------------------
mkdir -p $VTUNE_RESULT_DIR
echo "[*] Running join query under VTune memory-access profiling..."

for i in $(seq 1 $NUM_RUNS); do
    RUN_DIR="${VTUNE_RESULT_DIR}/run${i}"
    mkdir -p $RUN_DIR

    vtune -collect memory-access -result-dir $RUN_DIR \
    -- $DUCKDB_CLI $DB_FILE -c "$QUERY"
    
    echo "[*] VTune profiling completed for run $i. Results in $RUN_DIR"
done

echo "[*] All runs completed. Check $VTUNE_RESULT_DIR for VTune results."
