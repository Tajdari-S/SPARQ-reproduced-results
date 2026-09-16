# Figure 11 with DuckDB's memory on one socket

## Question

Figure 11's SPARQ-integrated bars take everything except the join from a CPU-only
DuckDB run, and that run was not bound to any NUMA node. SPARQ itself uses the 8
DDR4 channels of one socket. What changes if DuckDB also uses only one socket's
memory (8 channels), with CPU threads left unrestricted?

## Answer

- **It fits.** Peak memory is 107 GB against about 125 GB per node, and with
  `numactl --membind=1` all of it stays on node 1 (unbound runs split it
  roughly 55/50 GB across the two nodes).
- **DuckDB is 8.6% slower** (geomean of warm latency over the 13 queries; total
  2.43 s to 2.66 s).
- **Figure 11's warm speedups barely move:** 1.09x-27.4x (geomean 2.87x)
  unbound, 1.09x-27.5x (geomean 2.95x) with memory on one socket. No query's
  speedup falls; the largest change is Q4.1, 3.01x to 3.40x. The extra cost lands
  on the DuckDB bar and on the non-join part of the SPARQ bar, but not on SPARQ's
  simulated join.

## Results

DuckDB v0.8.0 (Figure 11's binary), SF100, all tables in memory, 3 repetitions
per mode, interleaved. Warm = mean of runs 2-5; median over repetitions. Spread is
the largest max/min - 1 across repetitions in either mode
([`results/membind_summary.csv`](results/membind_summary.csv)).

| warm | unbound | memory on node 1 | change | spread |
|---|---:|---:|---:|---:|
| Q1.1 | 134 ms | 179 ms | +34% | 3% |
| Q1.2 | 131 ms | 153 ms | +17% | 2% |
| Q1.3 | 132 ms | 151 ms | +14% | 3% |
| Q2.1 | 161 ms | 166 ms | +3% | 3% |
| Q2.2 | 155 ms | 160 ms | +3% | 27% |
| Q2.3 | 113 ms | 113 ms | +0% | 11% |
| Q3.1 | 375 ms | 391 ms | +4% | 8% |
| Q3.2 | 162 ms | 165 ms | +2% | 19% |
| Q3.3 | 109 ms | 113 ms | +4% | 5% |
| Q3.4 | 110 ms | 111 ms | +1% | 5% |
| Q4.1 | 354 ms | 412 ms | +16% | 3% |
| Q4.2 | 305 ms | 342 ms | +12% | 6% |
| Q4.3 | 191 ms | 201 ms | +6% | 4% |
| **total** | **2.43 s** | **2.66 s** | **+9.2%** | |

The Q1.x, Q4.1 and Q4.2 changes are well outside run-to-run spread; the Q2.x and
Q3.x changes are within it.

## Method and limits

- **One process per mode.** The paper's script (`DucDBSSBFullQUery.sh`) starts a
  new DuckDB process for every query and reloads the 68 GB table each time (about
  11 minutes per query in our first attempt, before the file was page-cached). Here each mode loads once and runs all 13 queries × 5 in
  that process, about 2 minutes per mode. Only the first run of Q1.1 directly
  follows the load, so **cold runs are not compared**. The method also shifts
  absolute warm times: our unbound warm values are 0.36x-1.38x the plotted ones
  (0.77x in total), where one process per query gave 1.08x in total (full
  artifact, `artifact_submission/REPRODUCTION_STATUS.md`). **Compare the two modes
  with each other, not with the plotted values**; both modes use the same method.
- **Figure 11 estimate.** Section 5.2.5's formula, SPARQ bar = DuckDB − DuckDB
  join + SPARQ join, applied to `Fig11.py`'s warm arrays with each query's DuckDB
  time and DuckDB join time scaled by that query's measured ratio r. SPARQ's
  simulated join time is unchanged. This assumes DuckDB's join and non-join parts
  slow down by the same r. Both speedup ranges use the formula; as drawn, Q3.4's
  SPARQ warm bar is 0.16 ms above it, so the plotted maximum is 26.8x rather than
  27.4x.
- **CPU threads are not restricted** in either mode: DuckDB uses all 112 hardware
  threads.

## Running it

```bash
DATA=/path/to/sf100 bash scripts/run_membind.sh     # 3 reps x 2 modes, then the analysis
python3 scripts/analyze_membind.py                  # tables above from results/
```

Needs `numactl`, `numastat`, GNU `time`, DuckDB v0.8.0 (`DUCKDB=`) and about
110 GB free on the bound node.

## Files

| | |
|---|---|
| `scripts/fig11_membind.sh` | one mode, one repetition (`MODE=none` or `mem1`) |
| `scripts/run_membind.sh` | all repetitions, with per-node memory sampling |
| `scripts/extract_profiles.py` | latency and join share from DuckDB's JSON profiles |
| `scripts/analyze_membind.py` | tables and the Figure 11 estimate |
| `results/fig11_{none,mem1}_rep{1,2,3}.csv` | every run |
| `results/numastat.log` | per-node DuckDB memory, repetitions 2 and 3 |
| `results/time_{none,mem1}_rep3.txt` | `/usr/bin/time -v` output, including peak memory |
| `results/membind_summary.{csv,txt}` | the tables above |
