# GPU baseline (Figure 10), post-review

## Reviewer comment

> The paper claims that CPU-GPU transfer was not included in the GPU baseline but
> your notes and README contradict. Also, my own testing shows that if you move the
> CSV read outside the timer the H100 takes about 99 ms. SPARQ still beats this, but
> only by about 12x instead of the claimed 220x.

## Summary

1. **The reviewer is right about the harness.** `BestGPU.py` persists the input
   tables asynchronously and never waits for them, so loading can fall inside the
   first join's timer at each scale factor. How much depends on how long loading
   takes: the first join measured 4.8 s (SF1) and 55 s (SF10) with the files read
   cold from NFS, and 301 s (SF100) with the file page-cached, where parsing 68 GB
   alone is enough. Loaded before the timer, the same joins take 0.15 s, 1.3 s and 76 s.
2. **Fixing it does not change the plotted bars much.** With loading moved outside
   the timer, the GPU latencies are 0.68-1.65x the plotted values (median of three
   runs), and SPARQ's speedup over the GPU stays 118-223x at SF1 and SF10.
3. **The reviewer's 99 ms is a different run type**: an in-memory cuDF join. It is
   faster when the data fits in GPU memory (45-50 ms at SF1, 186-451 ms at SF10 on
   our A100; SPARQ is 15-66x faster than it against the paper's x8 bars), but it
   cannot run SF100. The paper's GPU
   baseline uses one out-of-core configuration at every scale factor, and the
   camera-ready should say so and report the in-memory numbers alongside.

## Which script, and why

`/p/pd/NVIDIARapids` holds 16 versions of the GPU join that cover SF1-SF100. We ran
all of them at SF1 and SF10 against the paper
([`results/version_sweep.txt`](results/version_sweep.txt), logs in
[`results/logs/version_sweep/`](results/logs/version_sweep/)):

| script | geo-mean vs paper | verdict |
|---|---:|---|
| `BestGPU.py` | 0.90x | closest, but changes block size per SF (1024/512/256 MiB) |
| `BestGPUReport.py` | 0.85x | same family, same per-SF block sizes |
| `FinalJoin.py` | 1.21x | one block size (1024 MiB), but **out of memory at SF100** on 40 GB ([log](results/logs/FinalJoin_1024MiB_sf100_oom.log)) |
| `NewFinalJoin.py` | 0.03x | timer stops before the lazy join executes |
| `join_VF.py`, `test13.py` | 7-22x | load inside the timer on every join |
| `test2`-`test10.py` (plain cuDF) | 0.10-0.98x | in-memory; cannot hold SF100 |
| `test1.py` | - | needs `cleaned_lineorder.tbl`, which no longer exists |

One run type must hold SF100, so we use **`BestGPU.py` with its SF100 settings at
every scale factor** (256 MiB partitions, no result transfer) and add a wait for
the tables to finish loading. The complete change against the original
([`original/BestGPU.py`](original/BestGPU.py)):

```diff
+SF1_DIR / SF10_DIR / SF100_DIR  environment overrides (defaults: the paper's paths)
+detect_sep(): '|' or ',' per file (the original hard-codes '|' below SF100, ',' at SF100)
-        protocol="ucx",
+        protocol="tcp",
-        ('1', '/p/pd/pim/sf1/', True, "1024 MiB"),
-        ('10', '/p/pd/pim/sf10/', True, "512 MiB"),
+        ('1', SF1_DIR, False, "256 MiB"),
+        ('10', SF10_DIR, False, "256 MiB"),
         ('100', SF100_DIR, False, "256 MiB")
+        # persist() is asynchronous: block until every table is loaded
+        dask.distributed.wait([t for t in tables.values() if t is not None])
```

`protocol="tcp"`: UCX crashes inside `libucs` on our host. With one GPU there is a
single worker, so no data crosses the wire and the timing is unaffected.

## Results

A100-PCIE-40GB, RAPIDS 24.12, median of three repetitions
([`results/gpu_uniform_results.csv`](results/gpu_uniform_results.csv)). "As
written" is the uniform script without the load fix, run once (SF1 and SF10 files
not in the page cache, SF100 cached).

| | paper (ms) | as written | load outside timer | vs paper | spread |
|---|---:|---:|---:|---:|---:|
| SF1 customer | 169.4 | 4,848.5 | 153.5 | 0.91x | 23% |
| SF1 part | 190.1 | 223.5 | 238.3 | 1.25x | 7% |
| SF1 supplier | 73.8 | 116.9 | 114.7 | 1.55x | 14% |
| SF1 date | 75.4 | 119.2 | 124.5 | 1.65x | 16% |
| SF10 customer | 1,890.0 | 54,755.8 | 1,294.1 | 0.68x | 2% |
| SF10 part | 1,830.2 | 1,579.5 | 1,562.2 | 0.85x | 2% |
| SF10 supplier | 1,823.2 | 1,645.1 | 1,665.8 | 0.91x | 9% |
| SF10 date | 1,947.7 | 1,278.5 | 1,704.1 | 0.87x | 10% |
| SF100 customer | 65,034.5 | 301,130.5 | 76,102.6 | 1.17x | 12% |
| SF100 part | 53,258.7 | 63,692.4 | 58,814.9 | 1.10x | 21% |
| SF100 supplier | 53,202.0 | 73,754.0 | 61,521.1 | 1.16x | 11% |
| SF100 date | 56,112.3 | 66,284.4 | 72,252.1 | 1.29x | 11% |

Spread is max/min - 1 across the three repetitions. Only the first join at each
scale factor is inflated in the "as written" column, which is the load falling
inside its timer.

### SPARQ speedup over the GPU

GPU latency divided by SPARQ latency. "x8" is the SPARQ bars as plotted, which is the
configuration the paper describes; "x16" is the geometry `02-sparq/` shipped. See
[`../sparq/`](../sparq/).

| | paper | load outside timer, x8 | load outside timer, x16 | in-memory cuDF, x8 / x16 |
|---|---:|---:|---:|---:|
| SF1 | 76-228x | 118-221x | 216-253x | 43-66x / 47-84x |
| SF10 | 148-255x | 126-223x | 95-216x | 15-59x / 12-50x |
| SF100 | 525-871x | 581-1019x | 665-1253x | cannot run |

In-memory numbers are [`03-gpu/results/gpu_join_bench.csv`](../../03-gpu/results/gpu_join_bench.csv)
(plain cuDF, tables on the GPU before the timer).

## Running it

```bash
conda activate rapids            # RAPIDS 24.12, see 03-gpu/README.md
RAPIDS_PYTHON=$(which python) \
SF1_DIR=/data/ssb/sf1/ SF10_DIR=/data/ssb/sf10/ SF100_DIR=/data/ssb/sf100/ \
bash scripts/run.sh              # 3 repetitions, ~14 min each, then rebuilds the tables
```

The field separator is detected per file (`|` for classic dbgen output, `,` for
the CSV that [`../dataset/`](../dataset/) produces); `SSB_SEP` overrides it. Dates
must be `YYYYMMDD` integers, which that recipe produces. `REPS=1` runs once. `python3 scripts/make_tables.py`
rebuilds the tables from whatever logs are in `results/logs/`.

To repeat the version sweep: `SRC=/path/to/gpu/scripts bash scripts/sweep_versions.sh`
then `python3 scripts/parse_version_sweep.py`.

### Environment notes

These three each stopped the original scripts from running on our host:

- **`NUMBA_CUDA_USE_NVIDIA_BINDING=1`** is required with NVIDIA driver 580 / CUDA 13.
  Without it, numba-cuda 0.0.17 (RAPIDS 24.12) segfaults on the first cuDF column
  access, about seven seconds into every dask-cuDF script. `run.sh` sets it.
- **UCX** crashes in `libucs`; use `protocol="tcp"` (single worker, no effect on timing).
- **An `if __name__ == "__main__":` guard** is needed by any script that starts a
  `LocalCUDACluster`, since workers are spawned by re-importing the main module.
  All scripts here have one; its absence was the cause of the earlier
  `Nanny failed to start worker process`.

## Files

| | |
|---|---|
| `scripts/BestGPU_uniform_loadfixed.py` | the corrected baseline |
| `scripts/BestGPU_uniform.py` | same run type without the load fix, to show the leak |
| `scripts/run.sh`, `scripts/make_tables.py` | run repetitions; build tables and CSV |
| `scripts/sweep_versions.sh`, `scripts/parse_version_sweep.py` | the 16-version comparison |
| `original/BestGPU.py`, `original/FinalJoin.py` | the two originals, unmodified |
| `results/gpu_uniform_results.csv`, `results/tables.txt` | final numbers |
| `results/version_sweep.txt` | the 16-version comparison |
| `results/logs/` | every raw log behind the tables |
