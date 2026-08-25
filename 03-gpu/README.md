# 03 — GPU baseline

Reproduces the GPU bars of Figure 10 with RAPIDS/cuDF.

```bash
bash ./scripts/run.sh              # SF1 + SF10, ~5 min after loading
RAPIDS_PYTHON=$(conda run -n rapids which python) \
DATA_ROOT=/path/to/ssb bash ./scripts/run.sh
```

## What to expect

Repeat runs agree within **1%**. Medians on an A100-PCIE-40GB, cuDF 24.12:

| SF | customer | part | supplier | date |
|---|---:|---:|---:|---:|
| 1 | 47.3 ms | 46.6 ms | 44.7 ms | 50.1 ms |
| 10 | 186.1 ms | 191.4 ms | 389.5 ms | 450.5 ms |

Raw: [`results/gpu_join_bench.csv`](results/).

## Where the timer starts, and why it matters

**The original harness timed its own data loading.** `BestGPU.py` starts its
timer immediately before:

```python
start_compute = time.time()
joined = client.persist(joined)
dask.distributed.wait(joined)
end_compute = time.time()
```

`optimize_schema()` does call `persist()` on the input tables, but `persist()` is
**asynchronous** — it returns futures and nothing waits on them. So the CSV read
and parse were still in flight when the timer started, and the measured "GPU
compute" time included reading and parsing 6.2 GB at SF10. The DuckDB bars in the
same figure preload *outside* their timing, so the two baselines were not
measuring the same thing.

We measured both ways to confirm it:

| SF10 customer | |
|---|---:|
| load inside the timed region (original behaviour) | 2,543 ms |
| load outside (corrected) | 186 ms |
| plotted | 1,890 ms |

The plotted value sits near the load-inside figure, which is what you would
expect from a partially-completed async load.

## Step by step

### 1. Install RAPIDS

```bash
conda create -n rapids -c rapidsai -c conda-forge -c nvidia \
    cudf=24.12 python=3.12 cuda-version=11.8
conda activate rapids
```

Our exact stack is in `scripts/environment_observed.txt`.

### 2. Check the environment before a long run

```bash
python gpu_smoke_check.py
```

Should print the cuDF version and your device name.

### 3. Measure

```bash
DATA_ROOT=/path/to/ssb bash ./scripts/run.sh 1 10
```

The harness loads every table, calls `cudaDeviceSynchronize()`, and only then
starts the timer. That is the only methodological change from the original; the
join itself is the same `merge`.

To reproduce the *original* behaviour for comparison:

```bash
INCLUDE_LOAD=1 bash ./scripts/run.sh 1
```

## Two things that constrain this on our host

**dask-CUDA workers do not start here.**

```
distributed.comm.ucx - WARNING - A CUDA context for device 0 already exists ...
RuntimeError: Nanny failed to start worker process
```

This happens with `protocol="ucx"` (segfault in the UCX transport), with
`protocol="tcp"`, and with a bare `LocalCUDACluster()` carrying no options at
all — so it is an environment problem, not a configuration mistake in the
original script. A single A100 holds SF1 and SF10 comfortably, so the harness
uses plain cuDF and the distributed layer is not needed.

**SF100 does not fit on a 40 GB GPU.** Measured, not assumed:

```
SF100 LOAD FAILED: MemoryError std::bad_alloc: out_of_memory:
cudaErrorMemoryAllocation out of memory
```

600,037,902 rows x 17 int32 columns is about 41 GB against 40 GB of device
memory. Reproducing the SF100 GPU points needs a larger GPU, or a working
multi-GPU dask-CUDA setup with spilling. The plotted SF100 GPU values are
therefore left untouched in the figures.

## Original GPU harnesses

`original/` holds the published harnesses, unchanged:

| | |
|---|---|
| `BestGPU.py` | the harness behind Figure 10's GPU bars |
| `BestGPUReport.py` | reporting variant |
| `FinalJoin.py`, `NewFinalJoin.py`, `join_VF.py` | earlier iterations |

`scripts/gpu_join_bench.py` runs the same `merge`, differing only in where the
timer starts and in using plain cuDF rather than dask-cuDF. Set `INCLUDE_LOAD=1`
to reproduce the original timing behaviour and compare directly.
