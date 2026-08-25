# Reproducibility notes for the DuckDB measurements

Things that changed our measured numbers by more than the effect being measured,
each with the evidence that established it. If you are re-running any DuckDB
series in this paper, read this first — several of these fail *silently*, giving
a plausible-looking fast number rather than an error.

Ordered by how much damage they do. Item 0 is the one to read if you read only one.

---

## 0. The database is on NFS, and cold reads pay for it — up to 11x

This is the largest effect we found and the one that matters most for artifact
evaluation.

`/p/pd` is a network mount (`corezfs02:/p/pd`); `/tmp` is the machine's local
disk. The figures were measured against databases under `/p/pd`. Copying the
**same file** to local disk and re-running the same query with the same binary
and the same pinning:

| SF10, `column01 = 3`, cold | median |
|---|---:|
| `/p/pd/ssb_sf10.duckdb` (NFS) | 12.6 s |
| the identical file copied to `/tmp` | 1.05 s |
| *plotted in Figure 9* | *12.4 s* |

Nothing was rebuilt — it is one file in two places.

**It only hits cold measurements.** Run the query three times in one session:

| | run 1 | run 2 | run 3 |
|---|---:|---:|---:|
| NFS | 12.61 s | 0.49 s | 0.45 s |
| local | 1.16 s | 0.44 s | 0.41 s |

Once DuckDB's buffer pool is warm the two are identical. The whole penalty is in
the first read, so it reaches exactly those measurements that start from a fresh
process — which is the cold protocol every figure uses. Loading tables into a
`.duckdb` file first does not avoid it: that writes to disk, it does not pin
anything in memory, and a new process starts with an empty buffer pool.

Measured inflation per series, SF10, cold, same file in both locations:

| Series | Figure | NFS | local | inflation |
|---|---|---:|---:|---:|
| `WHERE column01 = 3` | 9(b) | 12.50 s | 1.14 s | **10.9x** |
| customer star join | 7, 10 | 12.82 s | 3.26 s | **3.9x** |
| `DISTINCT column00` | 9(a) | 1.23 s | 0.35 s | **3.5x** |
| self-join `COUNT(*)` | 8 | 1.68 s | 0.90 s | **1.9x** |

SF100 confirms it, and the inflation grows with scale. Figure 9's plotted
values match NFS to within 0.1%:

| Figure 9 SF100 | plotted | NFS | local | inflation |
|---|---:|---:|---:|---:|
| `WHERE` (C-1) | 137,218 ms | 137,358 ms | 6,157 ms | **22x** |
| `DISTINCT` (C-0) | 12,272 ms | 12,510 ms | 2,119 ms | **5.9x** |

The `WHERE` inflation by scale factor is 9.4x, 10.7x, **22x** at SF1, SF10,
SF100 — it gets worse as the data grows, because less of it fits in the client
cache.

**Affected:** Figures 7, 8, 9 and 10. **Not affected:** Figures 1 and 11 (see
below), and every SPARQ bar — those come from DRAMsim3 and never touch a
filesystem.

### Figures 1 and 11 are NOT affected

`DucDBSSBFullQUery.sh` invokes `../duckdb <<EOF` with **no database file**, so
the tables live in memory, and it does so thirteen times — once per query. Each
invocation loads all five tables from CSV and only then enables profiling, so the
timed query runs against data already in RAM. The network cost lands entirely in
the untimed setup load.

So Figures 1 and 11 need no storage correction. An earlier version of this file
listed their cold series as affected; that was wrong.

That asymmetry is the problem. The DuckDB side is inflated by storage while the
SPARQ side is not, so the reported speedups are too large by roughly the factors
above.

**Fix:** copy the database to local disk before measuring.

```bash
cp /p/pd/ssb_sf10.duckdb /tmp/ssb_sf10.duckdb
duckdb /tmp/ssb_sf10.duckdb      # measure here
```

`corrected_baselines.sh` does this and reports both columns;
`results/corrected_baselines.csv` holds the runs.

**One unexplained inconsistency.** Figure 9's plotted 12,394 ms matches NFS-cold
almost exactly, but Figure 7's plotted SF10 customer of 4,726 ms sits between
local-cold (3.26 s) and NFS-cold (12.82 s). The figures do not share a single
storage/cache state, and we have not established what Figure 7's was.

## 1. Which copy of the data you load — about 1.1x, and a broken date join

An earlier version of this file claimed the choice between `/p/pd/pim` and
`/p/pd/ssb-dbgen` was worth 10x. **That was wrong** — it compared a pim-derived
database on local disk against the figures' database on NFS, so it measured the
filesystem, not the data. With both databases on the same local disk the
difference is small:

| SF10 `WHERE`, v1.1.3, both on `/tmp` | median |
|---|---:|
| built from `/p/pd/pim/sf10` | 1.216 s |
| built from `/p/pd/ssb-dbgen/sf10` | 1.096 s |

About 1.1x. The two copies do still differ in ways that matter for correctness
rather than speed:

| | delimiter | dates written as | strings |
|---|---|---|---|
| `/p/pd/pim/sf*` | `\|` | integer `19960130` | unquoted |
| `/p/pd/ssb-dbgen/sf*` | `,` | ISO `"1996-01-30"` | quoted |

`read_csv_auto` infers types from a sample, so on the ssb-dbgen copy
`lineorder.orderdate` becomes `DATE` while `date.datekey` stays `BIGINT`, and the
date join then fails outright (see #5). The row counts also differ —
`pim/sf10` has 59,986,217 `lineorder` rows against ssb-dbgen's 51,564,054 — so
the two are not interchangeable even though their speed is similar.

**Fix:** load with `load_ssb.sh`, which declares every column type explicitly and
normalises both copies to the same integer `YYYYMMDD` date form.

## 2. `numactl` does not limit DuckDB's thread count — 1.5x, and not what you think

`numactl --cpunodebind=0` restricts *where* threads run, but DuckDB sizes its
thread pool from the machine's total core count at startup. On our dual-socket
host it still reports **112 threads** under `--cpunodebind=0`, so the process is
running 112 threads packed onto 56 cores — oversubscribed, not single-socket.

Measured, SF10 `WHERE linenumber = 3`, v1.1.3:

| configuration | median |
|---|---:|
| unpinned, both sockets | 0.83 s |
| `numactl --cpunodebind=0 --membind=0` | 1.21 s |
| `numactl ... ` **plus** `SET threads=56` | 0.51 s |

The oversubscribed configuration is the slowest of the three — slower than both
using the whole machine and using one socket properly. If you intend "one
socket", set `threads` as well as pinning.

## 3. Query form — about 30x

The same join measured three ways at SF1 on `customer`: `COUNT(*)` 11 ms,
`COPY (...) TO '/dev/null'` 347 ms, bare `SELECT` with the client rendering rows
80,064 ms. Figures 7, 9, 10 plot the `COPY` form; Figure 8 plots `COUNT(*)`.
Always state which.

## 4. The date table has SEVENTEEN columns, and getting it wrong loads nothing

`d_daynuminmonth` sits between `d_daynuminweek` and `d_daynuminyear` and is easy
to miss. Declaring sixteen columns makes every row fail to parse — and with
`ignore_errors = true` the table loads **empty** instead of raising. Every SSB
query then returns no rows in a couple of milliseconds and looks merely fast.

We hit exactly this while writing `load_ssb.sql`: `date` came back with 0 rows
and the queries "ran" in 2 ms.

**Check:** after loading, `SELECT count(*) FROM lineorder l JOIN date d ON
l.orderdate = d.datekey` must equal the `lineorder` row count. `load_ssb.sql`
prints this automatically.

## 5. The date join fails on the ssb-dbgen copy — at SF1 and SF10 only

**Scope correction:** this affects SF1 and SF10, not SF100. The three scale
factors are not written the same way:

| | lineorder orderdate |
|---|---|
| `ssb-dbgen/sf1`, `sf10` | ISO string `"1995-02-18"` |
| `ssb-dbgen/sf100` | integer-like `"19960102"` |

At SF100 the column infers as an integer and joins `date.datekey` cleanly, which
is why `DucDBSSBFullQUery.sh` runs there. At SF1 and SF10 it infers as `DATE`
while `date.datekey` stays `BIGINT`:

```
Conversion Error: Unimplemented type for cast (BIGINT -> DATE)
```

This breaks the `date` join and all 13 SSB queries on that copy.
`results/figure_series_ssb-dbgen.csv` therefore carries
`ERROR_BIGINT_TO_DATE` for those 324 measurements rather than timings, and the
valid ssb-dbgen series are Figures 7 (customer/part/supplier), 8 and 9. The
`date` join and the SSB queries come from the `pim` copy, where the keys join.
`load_ssb.sh` removes the problem for future runs.

## 6. A failed statement still prints a Run Time

DuckDB prints `Run Time (s): real ...` even when the statement errored, so a
naive harness records the failure as a very fast measurement. That is how the
324 rows above were nearly published as data. `run_figure_data.sh` now greps the
output for `Error:` / `Conversion Error` / `Binder Error` / `Catalog Error` and
drops the timing when it matches.

**If you write your own harness, check for errors explicitly. A fast number is
not evidence that the query ran.**

## 7. The column rename mapping is shifted from `column08` onward

`DucDBSSBFullQUery.sh` renames `column00`–`column15`, sixteen names for a
seventeen-column table, so everything from the ninth field on is off by one:

| column | renamed to | actually is |
|---|---|---|
| `column08` | `daynuminyear` | `daynuminmonth` |
| `column09` | `monthnuminyear` | `daynuminyear` |
| `column10` | `weeknuminyear` | `monthnuminyear` |
| `column11` | `sellingseason` | `weeknuminyear` |
| `column12` | `lastdayinweekfl` | `sellingseason` |

`column00`–`column07` are correct, so `year`, `yearmonthnum` and `yearmonth` —
which most SSB queries filter on — are unaffected. **Q1.3 is affected**: it
filters `weeknuminyear = 6`, which under this mapping reads `monthnuminyear`, so
it selects June rather than week 6. The query still returns rows and still takes
a plausible time, which is why it went unnoticed.

Our `run_figure_data.sh` reproduces the same mapping deliberately, so its
measurements are comparable with the plotted ones. Fix the mapping and Q1.3's
value will change.

## 7b. The GPU baseline times its own data loading

`SPARQ/baselines/gpu/BestGPU.py` reads from `/p/pd/pim/sf1`, `/p/pd/pim/sf10` and
`/p/pd/ssb-dbgen/sf100` — all on NFS — using `dask_cudf.read_csv`, which is
**lazy**. Nothing is materialised until:

```python
start_compute = time.time()
joined = client.persist(joined)
dask.distributed.wait(joined)
end_compute = time.time()
```

So the timed region includes reading the raw `.tbl` files over the network and
parsing CSV on the GPU — 6.2 GB per join at SF10, 68 GB at SF100. The DuckDB
bars in the same figure deliberately exclude parsing, having preloaded into a
database. The two baselines in Figure 10 are therefore not measuring the same
thing, and the GPU side carries I/O the CPU side does not.

`transmit_to_cpu` is also `True` at SF1 and SF10 but `False` at SF100, so the
SF100 bar additionally omits the device-to-host transfer the smaller ones
include.

The fix is to `client.persist` and `wait` on each table before the timer starts.
This is a reading of the code, not a measurement — the GPU harness needs the
RAPIDS environment and an A100, neither confirmed available here.

## 8. v0.8.0 cannot open a database written by v1.x

Its storage format predates them. Build a separate database per version; do not
try to share one. This is why the comparison harness loads twice.

## 9. Load outside the timing

Reading the 64 GB SF100 CSV inside the timed query rather than loading first
changes the measurement from 20.9 s to 719 s — the parse dominates. Preload into
a database, then time the query.

---

## Dataset

The data is too large to keep in git (SF1 664 MB, SF10 5.7 GB, SF100 64 GB), so
it is generated locally. See [`dataset/MANIFEST.md`](dataset/MANIFEST.md) for the
exact sizes and row counts to check yours against, and `load_ssb.sh` for a load
that is deterministic across both copies.
