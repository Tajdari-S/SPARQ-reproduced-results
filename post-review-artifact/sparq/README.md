# SPARQ latencies (Figures 7 and 10), post-review

## Reviewer comment

> In Figure 7, I got different numbers for the SPARQ bars. The provided
> configuration produces 0.82x, 0.91x, and 0.55x of the plotted SF1 latencies, and
> this matches what your sparq_latency_reproduction.csv file records.

## Summary

The simulator is deterministic, so the difference is not run-to-run variation.
**The SPARQ bars in Figures 7 and 10 were simulated with a different memory
geometry from the one `02-sparq/` ships.** Both reproduce exactly:

| | plotted bars | `02-sparq/` |
|---|---|---|
| DRAM | DDR4-3200, 8 Gb **x8** chips | DDR4-3200, 8 Gb **x16** chips |
| channel | 32 GiB, 4 ranks | 16 GiB, 4 ranks |
| config | [`config/SPARQ_DDR4_8Gb_x8_3200.ini`](config/SPARQ_DDR4_8Gb_x8_3200.ini) | [`config/SPARQ_DDR4_8Gb_x16_3200.ini`](config/SPARQ_DDR4_8Gb_x16_3200.ini) |
| probe traces | [`traces/*_x8.txt.gz`](traces/) | [`../../02-sparq/traces/*_x16.txt.gz`](../../02-sparq/traces/) |
| original run | March 2025 | July 2025, also the tCCD sensitivity sweep |
| SF1 result vs plotted | **1.00x** on all four joins | 0.82x, 0.91x, 0.55x (reviewer's numbers) |

`scripts/reproduce.sh x8` regenerates every SF1 and SF10 bar in the paper
cycle-for-cycle. `scripts/reproduce.sh x16` regenerates what the reviewer measured.

## Reproduced values

Latency = completion cycle x 0.625 ns. Every row below was re-simulated with
`scripts/reproduce.sh` for this directory (`results/sparq_<geometry>_sf<N>.csv`).

| join | SF | plotted (ns) | x8 (ns) | x8 / plotted | x16 (ns) | x16 / plotted |
|---|---:|---:|---:|---:|---:|---:|
| customer | 1 | 743,997.5 | 743,997.5 | 1.00 | 606,875.0 | 0.82 |
| part | 1 | 1,076,788.8 | 1,076,788.8 | 1.00 | 984,098.8 | 0.91 |
| supplier | 1 | 968,215.0 | 968,215.0 | 1.00 | 530,698.1 | 0.55 |
| date | 1 | 764,128.1 | 764,128.1 | 1.00 | no trace | - |
| customer | 10 | 8,472,425.0 | 8,472,425.0 | 1.00 | 7,738,110.0 | 0.91 |
| part | 10 | 12,407,645.0 | 12,407,645.0 | 1.00 | 16,361,820.6 | 1.32 |
| supplier | 10 | 9,333,137.5 | 9,333,137.5 | 1.00 | 7,716,908.8 | 0.83 |
| date | 10 | 7,642,613.1 | 7,642,613.1 | 1.00 | no trace | - |

SF100 was not re-simulated here: its traces are 1.1 GB each and not shipped. The
original reports ([`results/original_reports/`](results/original_reports/)) cover
it; `scripts/compare_reports.py` shows all 12 plotted bars, SF100 included, equal
the March x8 report ([`results/geometry_comparison.csv`](results/geometry_comparison.csv)):

| join | SF100 plotted (ns) | x8 report | x16 report | x16 / plotted |
|---|---:|---:|---:|---:|
| customer | 74,653,817.5 | equal | 60,722,661.9 | 0.81 |
| part | 101,314,633.1 | equal | 88,488,124.4 | 0.87 |
| supplier | 101,365,995.0 | equal | 88,738,249.4 | 0.88 |
| date | 76,424,375.0 | equal | no trace | - |

The x16 trace generator emits columns C0-C4 only, so there is no x16 date trace.

## What differs between the two geometries

Config, x8 against x16 (`diff` of the two files, power-model lines omitted):

| parameter | x8 | x16 | effect |
|---|---:|---:|---|
| `device_width` | 8 | 16 | chips per rank: 8 vs 4 |
| `channel_size` | 32768 | 16384 | both give 4 ranks |
| `bankgroups` | 4 | 2 | |
| `BL` (burst length) | 4 | 2 | |
| `tCCD_S` / `tCCD_L` | 0 / 4 | 1 / 2 | compare delay per read |
| `tRRD_S` / `tRRD_L` | 4 / 8 | 9 / 11 | |
| `tFAW` | 34 | 48 | |

The trace generators ([`original/`](original/)) change to match: 4 bank groups
and burst length 4 for x8; 2 and 2, plus one channel address bit, for x16.

Which parameter drives each join's difference has not been isolated. The halved
`tCCD_L` plausibly explains x16 being faster on most joins, and the halved bank
groups plausibly explain SF10 part being slower (more probes per group on a skewed
key), but neither has been tested one parameter at a time.

## A second trap: the x8 config on disk had changed

The x8 config in `/p/pd/pim/dramsimtest/DRAMsim3/configs/` no longer reproduces
the plotted bars. Re-simulating with it gives 1.11-1.18x the plotted values. The
file was last modified in June 2025, after the March run, and now sets
`channel_size = 16384` (with a trailing space, suggesting a hand edit). That gives
2 ranks instead of the 4 the x8 traces address.
Rank-2 and rank-3 addresses then alias onto ranks 0 and 1 and force constant row
switching.

The March value is not recorded anywhere, so we recovered it from the March run's
own statistics file, which covers the last trace it simulated (SF1 date):

| counter | March 2025 run | `channel_size = 16384` | `channel_size = 32768` |
|---|---:|---:|---:|
| completion cycle | 1,222,605 | 1,369,433 | **1,222,605** |
| ranks active | 4 | 2 | **4** |
| `num_act_cmds` | 3,950 | 149,707 | **3,950** |
| `num_read_cmds` | 591,297 | 587,079 | **591,297** |

A search over command-queue size, `BL` and `tCCD` (280 combinations) found no exact
match with 2 ranks; `channel_size = 32768` matches every counter. The config here
carries that value, with a comment explaining it.

## Running it

```bash
git clone https://github.com/Tajdari-S/JSPIM          # simulator source
export DRAMSIM3_SRC=$PWD/JSPIM/SPARQ/sparq-sim/DRAMsim3
bash scripts/reproduce.sh x8  1     # plotted bars, ~10 s per join
bash scripts/reproduce.sh x8  10    # ~2 min per join
bash scripts/reproduce.sh x16 1     # 02-sparq geometry
python3 scripts/compare_reports.py  # all 12 bars against both original reports
```

The script builds DRAMsim3 with `-DCMD_TRACE=ON` on first use and appends to
`results/sparq_<geometry>_sf<N>.csv`. `TABLES="customer date"` limits the joins.

It is faster than `02-sparq/reproduce.sh` because it sets the cycle cap per scale
factor (1e7, 5e7, 2.5e8) instead of 999,990,000. DRAMsim3 always runs to the cap,
while the result is the last READ cycle, identical for any cap above completion:
SF1 customer gives the same cycle at 1e7 as at 999,990,000, and 1,190,396 at 1e7
matches the March run, which used 2,999,990,000. The script fails loudly if
completion comes within 5% of the cap.

## Correction to earlier notes

The commit that added the SF10 x16 results (`0b7f230`) attributed the
difference from the plotted values to run-to-run spread. That was wrong: the
simulation is deterministic, and the difference is the geometry described above.

## Files

| | |
|---|---|
| `scripts/reproduce.sh` | re-simulate either geometry at SF1 or SF10 |
| `scripts/compare_reports.py` | match plotted bars against both original reports |
| `config/SPARQ_DDR4_8Gb_x8_3200.ini` | x8, as used for the plotted bars |
| `config/SPARQ_DDR4_8Gb_x16_3200.ini` | x16, identical to `02-sparq/config/` |
| `traces/lineorder_sf{1,10}_C{2,3,4,5}_x8.txt.gz` | x8 probe traces (C2 customer, C3 part, C4 supplier, C5 date) |
| `results/sparq_{x8,x16}_sf{1,10}.csv` | re-simulated values |
| `results/geometry_comparison.csv` | all 12 plotted bars against both reports |
| `results/original_reports/` | the March 2025 x8 and July 2025 x16 reports, unmodified |
| `original/` | both trace generators and the March run script, unmodified |
