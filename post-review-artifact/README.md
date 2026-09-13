# Post-review artifact

Follow-up to the artifact evaluation. The evaluator reproduced the simulator, the
DuckDB join ordering and the two-socket effect, and raised two points; this
directory answers both, with the scripts, data and logs behind each answer.

| reviewer point | directory | finding |
|---|---|---|
| Figure 7: SPARQ bars come out 0.82x, 0.91x and 0.55x of the plotted SF1 values | [`sparq/`](sparq/) | The bars were simulated with a DDR4 **x8** geometry; `02-sparq/` ships **x16**. Both reproduce exactly. The x8 setup here regenerates all 8 SF1/SF10 bars cycle-for-cycle. |
| Figure 10: the GPU timer included the CSV read, and an H100 takes ~99 ms with it outside (12x, not 220x) | [`gpu/`](gpu/) | The timer could include loading. Fixed, and re-measured with one run type at every scale factor: 0.68-1.65x the plotted values, SPARQ still 118-223x faster at SF1/SF10. The reviewer's 99 ms is an in-memory join (SPARQ 12-84x faster), which cannot run SF100. |

## SPARQ (Figures 7 and 10)

- The simulation is deterministic. The difference is configuration, not noise.
- The paper's Section 5.1 states tCCD ≈ 2.5 ns, i.e. 4 cycles: the x8 configuration.
  The figures already show x8 data and need no change; the artifact shipped x16.
- Plotted bars: 8 Gb x8 chips, 32 GiB channel, `BL` 4, `tCCD_S`/`tCCD_L` 0/4, traces
  from the x8 generator.
- `02-sparq/`: 8 Gb x16 chips, 16 GiB channel, `BL` 2, `tCCD_S`/`tCCD_L` 1/2, traces
  from the x16 generator.
- The x8 config left on the simulation host had since changed to a 16 GiB channel
  (2 ranks instead of 4), so it no longer reproduced the bars either. The config here
  is the one that does, recovered from the original run's statistics.

```bash
export DRAMSIM3_SRC=/path/to/JSPIM/SPARQ/sparq-sim/DRAMsim3
bash sparq/scripts/reproduce.sh x8 1       # plotted bars, ~1 min
bash sparq/scripts/reproduce.sh x16 1      # what the reviewer measured
```

## GPU baseline (Figure 10)

- The original harness persisted input tables without waiting, so loading could land
  in the first join's timer: 4.8 s, 55 s and 301 s instead of 0.15 s, 1.3 s and 76 s.
- Of the 16 GPU script versions, `BestGPU.py` is closest to the paper but changes
  partition size per scale factor, and the one version that does not
  (`FinalJoin.py`) runs out of memory at SF100. The corrected baseline uses SF100's
  settings at every scale factor and waits for loading before timing.
- An in-memory cuDF join is faster when data fits in GPU memory. The camera-ready
  should state that the baseline is out-of-core at every scale factor and report the
  in-memory numbers alongside.

```bash
RAPIDS_PYTHON=$(which python) bash gpu/scripts/run.sh    # 3 repetitions, ~14 min each
```

Requires `NUMBA_CUDA_USE_NVIDIA_BINDING=1` on current NVIDIA drivers (set by
`run.sh`); see [`gpu/README.md`](gpu/README.md#environment-notes).

## Proposed camera-ready changes

1. **Figure 7 and 10 SPARQ bars:** no change. They are the x8 configuration the
   paper describes (Section 5.1, tCCD ≈ 2.5 ns), and `sparq/` reproduces them exactly.
2. **Figure 10 GPU bars:** re-plot from
   [`gpu/results/gpu_uniform_results.csv`](gpu/results/gpu_uniform_results.csv).
3. **Section 5.2.3:** state that the GPU baseline uses dask-cuDF with 256 MiB
   partitions at every scale factor because SF100 exceeds device memory; that
   loading, parsing and result transfer are outside the timed region; and that an
   in-memory cuDF join is faster at SF1/SF10 (45-50 ms and 186-451 ms on the A100).
4. **Headline GPU speedup:** re-derive from the new bars. At SF10 it is 126-223x
   against the x8 SPARQ bars; see
   [`gpu/README.md`](gpu/README.md#sparq-speedup-over-the-gpu).
