#!/bin/bash
# Benchmark: self-join, SELECT DISTINCT, SELECT WHERE for lineorder cols 0-5
# 1 cold run + 5 warm runs per query; tables pre-loaded via warmup scan.
# Self-joins skipped if estimated output > 5B matches (col01 always, others annotated).
set -euo pipefail

DDB=/p/pd/newduckdb/duckdb
IDHB=/p/pd/duckdb_src/build_debug/duckdb
OUT=/p/pd/join_results_natural/benchmark
mkdir -p "$OUT"
CSV="$OUT/results.csv"
echo "sf,col,test_type,cold_ms,avg_warm_ms,note" > "$CSV"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Run a query N_WARM+1 times with .timer on; first result = cold, rest = warm.
# Prints "real X.XXX" seconds for each run; returns 0 on success, 1 on timeout/error.
run_timed() {
    local db=$1 warmup_sql=$2 query=$3 n_warm=${4:-5} timeout_s=${5:-120}
    {
        printf '.timer off\n%s;\n.timer on\n' "$warmup_sql"
        for i in $(seq 0 $n_warm); do printf '%s;\n' "$query"; done
    } | timeout "$timeout_s" "$DDB" "$db" 2>&1
}

# Parse "Run Time (s): real X.XXX" from stdin into space-separated ms integers.
parse_ms() {
    grep -oP 'Run Time \(s\): real \K[0-9]+\.[0-9]+' | awk '{printf "%d ", int($1*1000 + 0.5)}'
}

record() {
    local sf=$1 col=$2 test_type=$3 db=$4 warmup=$5 query=$6 note=${7:-""}
    printf '  %-7s %-8s %-16s ... ' "$sf" "$col" "$test_type"

    local raw
    raw=$(run_timed "$db" "$warmup" "$query" 5 200) || true

    local times
    times=$(echo "$raw" | parse_ms)
    local arr=($times)

    if [[ ${#arr[@]} -lt 6 ]]; then
        local hint="FAILED(${#arr[@]}/6)"
        echo "$hint"
        echo "$sf,$col,$test_type,ERROR,ERROR,$note $hint" >> "$CSV"
        return
    fi

    local cold_ms=${arr[0]}
    local warm_sum=0
    for i in 1 2 3 4 5; do warm_sum=$((warm_sum + arr[$i])); done
    local avg_warm_ms=$((warm_sum / 5))

    printf 'cold=%5dms  avg_warm=%5dms\n' "$cold_ms" "$avg_warm_ms"
    echo "$sf,$col,$test_type,$cold_ms,$avg_warm_ms,$note" >> "$CSV"
}

skip() {
    local sf=$1 col=$2 test_type=$3 reason=$4
    printf '  %-7s %-8s %-16s SKIP: %s\n' "$sf" "$col" "$test_type" "$reason"
    echo "$sf,$col,$test_type,SKIP,SKIP,$reason" >> "$CSV"
}

# ─── SF1 ─────────────────────────────────────────────────────────────────────
log "=== SF1 (6M rows) ==="
DB=/p/pd/ssb_sf1.duckdb
WARM="SELECT COUNT(*) FROM lineorder"

# col00 (orderkey, 1.5M distinct) — self-join output ≈24M
record sf1 col00 self_join   $DB "$WARM" "SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column00 = l2.column00"
record sf1 col00 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column00) FROM lineorder"
record sf1 col00 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column00 = 1000000"

# col01 (linenumber 1-7) — self-join ~5T rows, skip
skip  sf1 col01 self_join  "7 distinct → ~5T output rows"
record sf1 col01 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column01) FROM lineorder"
record sf1 col01 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column01 = 3"

# col02 (custkey, 20K distinct) — self-join output ≈1.8B
record sf1 col02 self_join   $DB "$WARM" "SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column02 = l2.column02" "~1.8B matches"
record sf1 col02 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column02) FROM lineorder"
record sf1 col02 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column02 = 10000"

# col03 (partkey, 200K distinct) — self-join output ≈180M
record sf1 col03 self_join   $DB "$WARM" "SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column03 = l2.column03"
record sf1 col03 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column03) FROM lineorder"
record sf1 col03 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column03 = 100000"

# col04 (suppkey, 2K distinct) — self-join output ≈18B, skip
skip  sf1 col04 self_join  "2K distinct → ~18B output rows"
record sf1 col04 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column04) FROM lineorder"
record sf1 col04 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column04 = 500"

# col05 (DATE, 2406 distinct) — self-join output ≈15B, skip
skip  sf1 col05 self_join  "2406 distinct DATE → ~15B output rows"
record sf1 col05 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column05) FROM lineorder"
record sf1 col05 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column05 = DATE '1995-02-18'"

# ─── SF10 ────────────────────────────────────────────────────────────────────
log "=== SF10 (51.5M rows) ==="
DB=/p/pd/ssb_sf10.duckdb

# col00 (12.9M distinct) — self-join output ≈205M
record sf10 col00 self_join   $DB "$WARM" "SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column00 = l2.column00"
record sf10 col00 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column00) FROM lineorder"
record sf10 col00 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column00 = 5000000"

skip  sf10 col01 self_join  "7 distinct → ~380T output rows"
record sf10 col01 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column01) FROM lineorder"
record sf10 col01 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column01 = 3"

# col02 (200K distinct) — self-join output ≈13.3B, skip
skip  sf10 col02 self_join  "200K distinct → ~13B output rows"
record sf10 col02 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column02) FROM lineorder"
record sf10 col02 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column02 = 100000"

# col03 (600K distinct) — self-join output ≈4.4B, skip
skip  sf10 col03 self_join  "600K distinct → ~4.4B output rows"
record sf10 col03 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column03) FROM lineorder"
record sf10 col03 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column03 = 300000"

# col04 (20K distinct) — self-join output ≈133B, skip
skip  sf10 col04 self_join  "20K distinct → ~133B output rows"
record sf10 col04 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column04) FROM lineorder"
record sf10 col04 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column04 = 10000"

# col05 (DATE, 2406 distinct) — self-join output ≈1.1B, skip
skip  sf10 col05 self_join  "2406 distinct DATE → ~1.1B output rows"
record sf10 col05 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column05) FROM lineorder"
record sf10 col05 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column05 = DATE '1995-02-18'"

# ─── SF100 ───────────────────────────────────────────────────────────────────
log "=== SF100 (600M rows) ==="
DB=/p/pd/newduckdb/scripts/ssb_sf100.duckdb

# col00 (150M distinct) — self-join output ≈2.4B (slow but feasible)
record sf100 col00 self_join   $DB "$WARM" "SELECT COUNT(*) FROM lineorder l1 JOIN lineorder l2 ON l1.column00 = l2.column00" "~2.4B matches"
record sf100 col00 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column00) FROM lineorder"
record sf100 col00 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column00 = 50000000"

skip  sf100 col01 self_join  "7 distinct → ~51P output rows"
record sf100 col01 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column01) FROM lineorder"
record sf100 col01 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column01 = 3"

# col02 (2M distinct) — self-join output ≈180B, skip
skip  sf100 col02 self_join  "2M distinct → ~180B output rows"
record sf100 col02 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column02) FROM lineorder"
record sf100 col02 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column02 = 1000000"

# col03 = partkey in SF100
skip  sf100 col03 self_join  "SF100 partkey: ~600M distinct → ~360M matches, feasible but separate"
record sf100 col03 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT partkey) FROM lineorder"
record sf100 col03 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE partkey = 500000"

# col04 (200K distinct) — self-join output ≈1.8T, skip
skip  sf100 col04 self_join  "200K distinct → ~1.8T output rows"
record sf100 col04 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column04) FROM lineorder"
record sf100 col04 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column04 = 100000"

# col05 (BIGINT, 2406 distinct) — self-join output ≈150B, skip
skip  sf100 col05 self_join  "2406 distinct → ~150B output rows"
record sf100 col05 select_dist $DB "$WARM" "SELECT COUNT(DISTINCT column05) FROM lineorder"
record sf100 col05 select_where $DB "$WARM" "SELECT COUNT(*) FROM lineorder WHERE column05 = 19960102"

log "Done. Results in $CSV"
echo ""
echo "=== Summary table ==="
column -t -s, "$CSV"
