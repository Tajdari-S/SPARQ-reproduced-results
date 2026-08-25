# 01 — DuckDB CPU baseline

Reproduces the DuckDB bars of Figures 7–11. This is the component most sensitive
to how you run it, so read the conditions below before measuring.

```bash
bash ./scripts/corrected_baselines.sh 1 10     # SF1 + SF10, ~1 h
bash ./scripts/sf100_baselines.sh              # SF100, ~4 h
python3 ./scripts/make_tables.py > RESULTS.md
```

## What to expect

Repeat runs agree within roughly **5%** at SF1 and SF10. Absolute latency is
dominated by three settings, and a run differing in any of them will differ by far
more than that:

* **Storage class** — the identical database file on a network mount versus local
  disk changes a cold query by **2–22x**, growing with scale factor. Warm runs are
  identical. Measure on local disk.
* **DuckDB version** — v0.8.0 and v1.1.3 differ by up to **2.4x** on the same
  query and reverse order on multi-way joins. Figures 8 and 11 used v0.8.0;
  Figures 7, 9 and 10 used v1.1.3.
* **Query form** — materialising the output costs about **30x** a `COUNT(*)`.

With all three matched, our values land within about 20% of the published ones
for Figures 7 and 11. Figures 8 and 9 were originally measured with the database
on a network mount, so measuring them on local disk gives correspondingly faster
numbers — the storage effect above, not a disagreement about the query.

Medians on local disk, in ms:

| | SF1 | SF10 | SF100 |
|---|---:|---:|---:|
| customer join | 405 | 3,212 | 28,156 |
| part join | 549 | 3,592 | 32,204 |
| supplier join | 348 | 2,921 | 29,406 |
| self-join (v0.8.0) | 150 | 1,026 | 14,810 |

Raw runs in [`results/`](results/); full tables via `scripts/make_tables.py`.

## Step by step

### 1. Get the DuckDB binaries

Three versions are used and they are **not** interchangeable:

| version | used for | why |
|---|---|---|
| v0.8.0 | Figure 8, Figure 11 | oldest release in our setup; reads `.tbl` directly |
| v1.1.3 | Figures 7, 9, 10 | the release the rest of the paper uses |
| v1.4.0-dev, instrumented | Figure 3 | emits per-phase join timers |

```bash
wget https://github.com/duckdb/duckdb/releases/download/v0.8.0/duckdb_cli-linux-amd64.zip
unzip duckdb_cli-linux-amd64.zip -d duckdb-v0.8.0
wget https://github.com/duckdb/duckdb/releases/download/v1.1.3/duckdb_cli-linux-amd64.zip
unzip duckdb_cli-linux-amd64.zip -d duckdb-v1.1.3
```

Between these two we measured differences up to **2.4x on the same query**, and
direction reversals on multi-way joins — v1.1.3 wins the two-table Q1 queries and
loses every four-table Q2/Q3/Q4 query. v0.8.0 cannot open a database written by
v1.x; build a separate one per version.

### 2. Load the data — outside the timing

```bash
bash ./scripts/load_ssb.sh /path/to/ssb/sf1 /tmp/ssb_sf1.duckdb
```

This declares every column type explicitly instead of letting `read_csv_auto`
infer them. That matters twice over: inferred types differ between data copies
and change materialisation cost, and on some copies `lineorder.orderdate` infers
as `DATE` while `date.datekey` infers as `BIGINT`, so the date join fails with
`Unimplemented type for cast (BIGINT -> DATE)`.

The script prints a sanity check — the date join must return the full `lineorder`
row count.

**Never read the CSV inside a timed query.** At SF100 that changes a measurement
from 20.9 s to 719 s; the parse dominates.

### 3. Put the database on local disk

```bash
cp /net/share/ssb_sf10.duckdb /tmp/ssb_sf10.duckdb
```

The identical file on NFS runs a cold query **2–22x slower**, and the gap grows
with scale factor:

| SF10 `WHERE`, cold | |
|---|---:|
| on NFS | 12.6 s |
| same file on local disk | 1.05 s |

Warm runs are identical (0.49 s vs 0.44 s), so this only reaches measurements
that start from a fresh process — which every figure does.

### 4. Pin to one socket, and set the thread count

```bash
numactl --cpunodebind=0 --membind=0 duckdb /tmp/ssb_sf10.duckdb
```

`numactl` alone does **not** reduce DuckDB's thread count — it still starts 112
threads and packs them onto 56 cores. Measured on the SF10 `WHERE`:

| | median |
|---|---:|
| unpinned, both sockets | 0.83 s |
| `numactl` only | 1.21 s |
| `numactl` + `SET threads=56` | 0.51 s |

The oversubscribed middle case is the slowest of the three. If you mean "one
socket", set `threads` too.

### 5. Measure

```bash
bash ./scripts/corrected_baselines.sh 1 10
```

Fresh process per cold measurement, `COPY (...) TO '/dev/null'` to force
materialisation without writing files, three repetitions, median reported. It
measures the database in both locations and reports both columns.

**Query form matters as much as anything above.** The same join measured as
`COUNT(*)` runs ~30x faster than materialising its output. Figures 7, 9 and 10
plot the materialised form; Figure 8 plots `COUNT(*)`.

### 6. Build the tables

```bash
python3 ./scripts/make_tables.py > RESULTS.md
```

## Other conditions that fail silently

[`./NOTES.md`](./NOTES.md) has all ten
with evidence. The two most likely to catch you:

* **The SSB date table has seventeen columns**, not sixteen — `d_daynuminmonth`
  is easy to miss. Supply sixteen names with `ignore_errors = true` and the table
  loads **empty**, so every query returns no rows in milliseconds and looks fast.
* **A failed statement still prints a Run Time.** Check for `Error:` explicitly;
  a fast number is not evidence the query ran.

## Original measurement scripts

`original/` holds the scripts used for the published measurements, unchanged:

| | |
|---|---|
| `DucDBSSBFullQUery.sh` | the 13 SSB queries, Figures 1 and 11 |
| `run_joins.sh`, `perf_join_bench.sh` | star joins, Figures 7 and 10 |
| `run_benchmark_cols.sh` | self-join, DISTINCT and WHERE per column, Figures 8 and 9 |
| `advisor.sh`, `advisor2.sh` | Intel Advisor drivers, Figure 2 |

`scripts/` holds the harnesses used for the re-measurement here. They run the
same queries; the differences are that the database is on local disk, each cold
measurement uses a fresh process, and every run is recorded rather than only the
summary.
