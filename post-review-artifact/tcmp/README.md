# Comparator-delay sensitivity (Section 5.3.4), post-review

## Reviewer comment

> The paper reports join latency increasing by 11% at tCMP = 1 and 32% at
> tCMP = 4. A reviewer run of `getting_started.sh` observed lower latency at
> tCMP = 2 and 4 than at tCMP = 0, and the script's check only tests that
> latencies differ from the baseline, not that they increase, so it still reports
> PASS. This needs an explanation or a fix.

## Summary

1. **Latency never decreases with tCMP when measured the way the paper measures
   latency.** Every SPARQ latency in the paper is the completion cycle (the cycle
   of the last READ) times 0.625 ns. Across 90 simulations (x8 at SF1/10/100, x16
   at SF1/10) no join is faster at tCMP > 0 than at tCMP = 0.
2. **The decrease came from the metric the old script used.** The
   `getting_started.sh` the reviewer ran compared DRAMsim3's
   `average_read_latency`, a per-request mean that shifts when added delay
   reorders requests. Under that metric part SF100 is 6.7% *faster* at tCMP = 2
   (table below). The script now compares completion cycles and fails unless
   tCMP > 0 is slower (JSPIM commit `cf41672`); `scripts/analyze_tcmp.py` applies
   the same check to the full sweep.
3. **The published numbers do not reproduce, and are corrected.** They came from
   an earlier sweep on the x16 configuration, not the x8 configuration of
   Figures 7 and 10. That sweep's customer SF1 result (+61%) matches the paper,
   but its averages do not, under either metric. The table below reports the
   sweep re-run on the paper's x8 configuration at all three scale factors.

## Corrected results (x8, the configuration of Figures 7 and 10)

Join latency increase over tCMP = 0, completion cycle
([`results/tcmp_sweep.csv`](results/tcmp_sweep.csv)):

| join | tCMP=1 | tCMP=2 | tCMP=3 | tCMP=4 |
|---|---:|---:|---:|---:|
| customer SF1 | 0.8% | 0.9% | 49.3% | 53.9% |
| part SF1 | 1.0% | 1.5% | 33.8% | 37.2% |
| supplier SF1 | 21.9% | 22.0% | 44.0% | 45.2% |
| date SF1 | 12.5% | 12.5% | 45.9% | 49.7% |
| customer SF10 | 0.8% | 1.2% | 33.8% | 37.9% |
| part SF10 | 0.1% | 0.0% | 18.3% | 21.5% |
| supplier SF10 | 1.4% | 1.2% | 50.3% | 50.9% |
| date SF10 | 12.5% | 12.5% | 46.0% | 49.7% |
| customer SF100 | 0.8% | 0.6% | 49.1% | 53.7% |
| part SF100 | 0.8% | 1.0% | 40.5% | 43.2% |
| supplier SF100 | 0.8% | 1.1% | 40.4% | 43.1% |
| date SF100 | 12.6% | 12.5% | 46.0% | 49.7% |
| **average** | **5.5%** | **5.6%** | **41.4%** | **44.6%** |

Maximum at tCMP = 4: 53.9% (customer, SF1). Most of the increase arrives in one
step, between tCMP = 2 and 3. That is consistent with the scheduling effect
Section 5.3.4 describes (the compare delay becoming the binding constraint), but we
have not isolated the cause.

SPARQ's join speedup over DuckDB goes from **405x-1001x** at tCMP = 0 to
**295x-651x** at tCMP = 4 (paper: 400x-1000x to 324x-916x). These use the CPU
values of the GPU/CPU speedup figure; with the customer SF100 CPU value that
Figures 7 and 10 plot (46,291 ms instead of 74,739 ms), the range is 405x-662x to
295x-442x. See [`../figures/README.md`](../figures/README.md).

## The published sweep (x16, July 2025)

The earlier sweep raised `tCCD_S`/`tCCD_L` by 1 to 4 cycles on the x16
configuration ([`results/july2025_x16_tccd_sweep/`](results/july2025_x16_tccd_sweep/),
including the original script). The simulator implements tCMP exactly that way
(`tCCD += tCMP`), and re-simulating with `tCMP` reproduces all 30 of its values.

| x16, SF1-SF100, 9 joins | tCMP=1 | tCMP=4 | max at tCMP=4 |
|---|---:|---:|---:|
| paper | 11% | 32% | 61% (customer SF1) |
| completion cycle | 28.6% | 53.7% | 139.4% (supplier SF1); customer SF1 is 61.3% |
| `average_read_latency` | 4.6% | 14.4% | 80.6% (supplier SF1); 5 of 9 joins get faster at tCMP = 1-2 |

Neither metric gives the published averages, so we replace them with the x8 results
above rather than try to reconstruct how they were computed.

## Running it

```bash
export DRAMSIM3_SRC=/path/to/JSPIM/SPARQ/sparq-sim/DRAMsim3
bash scripts/sweep_tcmp.sh x8 1 10          # ~5 min, traces ship in ../sparq/traces
X8_SF100_DIR=/path/to/x8/sf100/traces bash scripts/sweep_tcmp.sh x8 100   # ~40 min, 20 jobs
bash scripts/sweep_tcmp.sh x16 1 10
python3 scripts/analyze_tcmp.py             # tables above; exits 1 if any latency decreases
```

The sweep writes the command trace into a FIFO and keeps only its last READ
line, so an SF100 run needs no disk for the trace (about 11 GB otherwise). The
result is identical to reading the file (checked on SF1 customer). The x8 SF100
traces are 1.1 GB each and are not shipped.

## Files

| | |
|---|---|
| `scripts/sweep_tcmp.sh` | the sweep, either geometry, any scale factor |
| `scripts/analyze_tcmp.py` | tables, speedup range, direction check |
| `results/tcmp_sweep.csv` | 90 re-simulated points |
| `results/tcmp_summary.csv`, `results/tcmp_summary.txt` | per-join increases and the full printout |
| `results/july2025_x16_tccd_sweep/` | the original sweep: reports, per-trace statistics, script |
