#!/usr/bin/env bash
# Validate an SSB dataset before spending hours measuring against it.
#
# This exists because we found real damage in our own copies: the ssb-dbgen SF10
# set is short in every table, and one SF100 lineorder is truncated at 14.9 GB of
# 68 GB. Both load "successfully" with ignore_errors and give wrong numbers.
#
#   bash validate_data.sh <data-dir> [scale-factor]
set -uo pipefail
DIR="${1:?usage: validate_data.sh <data-dir> [SF]}"
SF="${2:-}"
FAIL=0; WARN=0

# nominal SSB row counts
declare -A EXP1=( [lineorder]=6001171 [customer]=30000 [part]=200000 [supplier]=2000 [date]=2556 )
declare -A EXP10=( [lineorder]=59986052 [customer]=300000 [part]=800000 [supplier]=20000 [date]=2556 )
declare -A EXP100=( [lineorder]=600037902 [customer]=3000000 [part]=2000000 [supplier]=200000 [date]=2556 )

echo "=============================================="
echo " SSB dataset validation: $DIR"
echo "=============================================="

for t in lineorder customer part supplier date; do
  f="$DIR/$t.tbl"
  if [ ! -f "$f" ]; then echo "  MISSING  $t.tbl"; FAIL=1; continue; fi
  sz=$(stat -c%s "$f")
  printf "  %-10s %14s bytes" "$t" "$(printf "%'d" $sz)"
  if [ -n "$SF" ]; then
    n=$(wc -l < "$f")
    eval "exp=\${EXP${SF}[$t]:-}"
    if [ -n "${exp:-}" ]; then
      d=$(( n > exp ? n-exp : exp-n ))
      pct=$(( exp>0 ? 100*d/exp : 0 ))
      if [ "$n" -eq "$exp" ]; then printf "  %'d rows  OK\n" "$n"
      elif [ "$pct" -le 1 ]; then printf "  %'d rows  WARN (expected %'d)\n" "$n" "$exp"; WARN=1
      else printf "  %'d rows  FAIL (expected %'d)\n" "$n" "$exp"; FAIL=1; fi
    else printf "  %'d rows\n" "$n"; fi
  else echo; fi
done

echo
echo "-- format checks (lineorder) --"
L="$DIR/lineorder.tbl"
if [ -f "$L" ]; then
  head1=$(head -1 "$L")
  pipes=$(tr -cd '|' <<<"$head1" | wc -c)
  if [ "$pipes" -gt 5 ]; then D='|'; else D=','; fi
  echo "  delimiter: '$D'"
  # orderdate is field 6; ISO strings break the date join against an integer datekey
  od=$(cut -d"$D" -f6 <<<"$head1" | tr -d '"')
  if [[ "$od" =~ ^[0-9]{8}$ ]]; then
    echo "  orderdate: integer $od  OK (joins date.datekey directly)"
  elif [[ "$od" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "  orderdate: ISO '$od'  WARN"
    echo "             read_csv_auto infers DATE here while date.datekey infers BIGINT,"
    echo "             so the date join fails with 'Unimplemented type for cast"
    echo "             (BIGINT -> DATE)'. Load with duckdb_versions/load_ssb.sh,"
    echo "             which normalises both to integer YYYYMMDD."
    WARN=1
  else
    echo "  orderdate: unrecognised '$od'  FAIL"; FAIL=1
  fi
  # trailing delimiter creates a phantom empty column
  [[ "$head1" =~ [\|,]$ ]] && echo "  note: trailing delimiter -> one extra empty column on load"
  # truncated last line
  lastf=$(tail -1 "$L" | tr -cd "$D" | wc -c)
  firstf=$(tr -cd "$D" <<<"$head1" | wc -c)
  if [ "$lastf" -ne "$firstf" ]; then
    echo "  last line: $lastf delimiters vs $firstf on line 1  WARN (truncated final record)"
    WARN=1
  fi
fi

echo
echo "-- date table --"
DT="$DIR/date.tbl"
if [ -f "$DT" ]; then
  n=$(head -1 "$DT" | tr -cd ',|' | wc -c)
  echo "  fields on line 1: $((n+1))"
  [ "$((n+1))" -lt 17 ] && { echo "  FAIL: SSB date has 17 columns (d_daynuminmonth is easy to miss)."; FAIL=1; } \
                        || echo "  OK (17 expected)"
fi

echo
if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAIL - do not measure against this dataset"; exit 1
elif [ "$WARN" -ne 0 ]; then echo "RESULT: WARNINGS - usable with the stated workarounds"; exit 0
else echo "RESULT: PASS"; fi
