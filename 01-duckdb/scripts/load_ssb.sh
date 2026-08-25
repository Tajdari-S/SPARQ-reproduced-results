#!/usr/bin/env bash
# Load SSB into DuckDB with explicit column types.
#
#   bash load_ssb.sh <data-dir> <out.duckdb> [duckdb-binary]
#
# The delimiter is detected from the data. Types are declared rather than
# inferred, because read_csv_auto infers them differently between our two copies
# of the data, which changes measured latency by up to 10x and silently breaks
# the date join. See NOTES.md.
set -euo pipefail
DIR="${1:?usage: load_ssb.sh <data-dir> <out.duckdb> [duckdb]}"
OUT="${2:?usage: load_ssb.sh <data-dir> <out.duckdb> [duckdb]}"
BIN="${3:-duckdb}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(head -1 "$DIR/lineorder.tbl" | tr -cd '|' | wc -c)" -gt 5 ]; then SEP='|'; else SEP=','; fi
echo "loading $DIR (delimiter '$SEP') -> $OUT"
rm -f "$OUT"
sed -e "s#__DIR__#${DIR}#g" -e "s#__SEP__#${SEP}#g" "$HERE/load_ssb.sql" | "$BIN" "$OUT"
