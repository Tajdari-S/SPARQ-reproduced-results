
#!/bin/bash

# Script to run p1 and p3 for TPC-H tables
# Runs for sf1 to sf100, 4 times per table/command
# p1: customer (col 2), part (col 3), supplier (col 4)
# p3: customer (col 2), part (col 3), supplier (col 4) with lineorder (col 2)
# Output: Stored in results.txt

# Base directory for input files
BASE_DIR="/p/pd/ssb-dbgen"
# Output file
OUTPUT_FILE="results100.txt"
# Programs to run
P1_PROGRAM="./pr"
P3_PROGRAM="./p333"
# Working directory
WORK_DIR="/p/pd/pim/newarchitecture/test_with_communication_to_cpu/8channel/morebankchange"

# Check if programs exist
if [ ! -x "$P1_PROGRAM" ]; then
    echo "Error: $P1_PROGRAM not found or not executable" >&2
    exit 1
fi
if [ ! -x "$P3_PROGRAM" ]; then
    echo "Error: $P3_PROGRAM not found or not executable" >&2
    exit 1
fi

# Change to working directory
cd "$WORK_DIR" || { echo "Error: Cannot change to $WORK_DIR" >&2; exit 1; }

# Initialize output file
echo "Hash Join and Hash Table Results" > "$OUTPUT_FILE"
date >> "$OUTPUT_FILE"
echo "----------------" >> "$OUTPUT_FILE"

# Table configurations
# For p1: table join_col
# For p3: table1 join_col1 table2 join_col2
P1_TABLES=(
    "customer 0"
    "part 0"
    "supplier 0"
)
P3_TABLE_PAIRS=(
    "customer 0 lineorder 2"
    "part 0 lineorder 3"
    "supplier 0 lineorder 4"
)

# Loop through scale factors sf1 to sf100
for sf in {99..100}; do
    SF_DIR="$BASE_DIR/sf$sf"
    if [ ! -d "$SF_DIR" ]; then
        echo "Warning: $SF_DIR does not exist, skipping sf$sf" >> "$OUTPUT_FILE"
        continue
    fi

    # Run p1 for each table
    for table_entry in "${P1_TABLES[@]}"; do
        read -r table join_col <<< "$table_entry"
        TABLE_FILE="$SF_DIR/$table.tbl"

        if [ ! -f "$TABLE_FILE" ]; then
            echo "Warning: Missing file for sf$sf: $TABLE_FILE" >> "$OUTPUT_FILE"
            continue
        fi

        # for run in {1..4}; do
        #     CMD="$P1_PROGRAM $TABLE_FILE $join_col"
        #     echo "$CMD" >> "$OUTPUT_FILE"
        #     if ! $CMD >> "$OUTPUT_FILE" 2>&1; then
        #         echo "Error: Command failed with exit code $?" >> "$OUTPUT_FILE"
        #     fi
        #     echo "----------------" >> "$OUTPUT_FILE"
        # done
    done

    # Run p3 for each table pair
    for pair in "${P3_TABLE_PAIRS[@]}"; do
        read -r table1 join_col1 table2 join_col2 <<< "$pair"
        TABLE1_FILE="$SF_DIR/$table1.tbl"
        TABLE2_FILE="$SF_DIR/$table2.tbl"

        if [ ! -f "$TABLE1_FILE" ] || [ ! -f "$TABLE2_FILE" ]; then
            echo "Warning: Missing files for sf$sf: $TABLE1_FILE or $TABLE2_FILE" >> "$OUTPUT_FILE"
            continue
        fi

        for run in {1..4}; do
            CMD="$P3_PROGRAM $TABLE1_FILE $TABLE2_FILE $join_col1 $join_col2"
            echo "$CMD" >> "$OUTPUT_FILE"
            if ! $CMD >> "$OUTPUT_FILE" 2>&1; then
                echo "Error: Command failed with exit code $?" >> "$OUTPUT_FILE"
            fi
            echo "----------------" >> "$OUTPUT_FILE"
        done
    done
done

echo "Script completed" >> "$OUTPUT_FILE"
date >> "$OUTPUT_FILE"
