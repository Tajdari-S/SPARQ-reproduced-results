# Post-review artifact

Follow-up to the artifact evaluation. Each directory answers one point of the
evaluation report with the scripts, data and logs behind the answer;
[`PAPER_CHANGES.md`](PAPER_CHANGES.md) lists the resulting camera-ready edits.

**Where this directory and the rest of the repository disagree, this directory
is current.** In particular, `03-gpu/` and `RESULTS.md` describe an in-memory cuDF
join as the corrected GPU baseline; the baseline the paper uses is the one in
[`gpu/`](gpu/).

| report item | directory | finding |
|---|---|---|
| Fig. 7: SPARQ bars come out 0.82x, 0.91x, 0.55x of the plotted SF1 values | [`sparq/`](sparq/) | The figures and Section 5.1 use a DDR4 **x8** geometry; the artifact shipped **x16**. Both simulate deterministically; the x8 setup here regenerates all 8 SF1/SF10 bars cycle-for-cycle. The bars are correct as published. |
| Fig. 10 / Sec. 5.2.3: GPU timer includes the CSV read; ~99 ms on an H100, 12x not 220x | [`gpu/`](gpu/), [`figures/`](figures/) | The timer could include loading. Fixed and re-measured with one run type at every scale factor: 0.68-1.65x the plotted values, SPARQ 118-223x faster at SF1/SF10. 99 ms is an in-memory join, which cannot run SF100; SPARQ is 15-66x faster than it. |
| Sec. 5.3.4: latency lower at tCMP = 2, 4; check only tests for a difference | [`tcmp/`](tcmp/) | The decrease is an artefact of `average_read_latency`, which the old check used. With the paper's latency metric no join ever gets faster (90 simulations). The published averages do not reproduce; corrected values are +5.5% at tCMP = 1 and +45% at tCMP = 4. |
| Figs. 1, 11: results come from substitution | [`PAPER_CHANGES.md`](PAPER_CHANGES.md) §3 | Correct; wording for the abstract, introduction and captions. |
| Fig. 7 / Sec. 5.2.2: `-O0`; Table 2 wording | [`PAPER_CHANGES.md`](PAPER_CHANGES.md) §4 | Both fixed in the text. |
| ssb-dbgen pin does not exist; does not build | [`dataset/`](dataset/) | Correct on both counts, plus an intermittent crash. Fork, pin and a small patch (8 insertions, 2 deletions) that builds with GCC 14 and leaves the output byte-identical. |
| CPU configuration and DuckDB version per figure | [`PAPER_CHANGES.md`](PAPER_CHANGES.md) §6 | Per-figure table. The published CPU baselines were not pinned to one socket. |
| Zenodo DOI for the final version | [`PAPER_CHANGES.md`](PAPER_CHANGES.md) §8 | To be deposited once this directory is final. |

## Quick checks

```bash
export DRAMSIM3_SRC=/path/to/JSPIM/SPARQ/sparq-sim/DRAMsim3   # simulator source

bash sparq/scripts/reproduce.sh x8 1        # Fig. 7 SPARQ bars exactly, ~1 min
bash sparq/scripts/reproduce.sh x16 1       # what the evaluator measured
bash tcmp/scripts/sweep_tcmp.sh x8 1 10     # tCMP sweep, ~5 min
python3 tcmp/scripts/analyze_tcmp.py        # fails if any latency decreases

bash dataset/scripts/build_ssb_dbgen.sh     # SSB generator; tested with GCC 11.4 and 14.4

RAPIDS_PYTHON=$(which python) SF1_DIR=/path/to/sf1/ SF10_DIR=/nonexistent/ SF100_DIR=/nonexistent/ \
  bash gpu/scripts/run.sh                   # GPU baseline at SF1 only, ~1 min
```

`gpu/scripts/run.sh` sets `NUMBA_CUDA_USE_NVIDIA_BINDING=1`, which RAPIDS 24.12
needs on NVIDIA driver 580 or later; see [`gpu/README.md`](gpu/README.md#environment-notes).

## Directories

| | |
|---|---|
| [`sparq/`](sparq/) | x8 and x16 configurations, x8 traces, reproduction script, the original simulation reports |
| [`gpu/`](gpu/) | corrected GPU baseline, three runs with raw logs, comparison of all 16 earlier GPU scripts |
| [`figures/`](figures/) | Figure 10 and the GPU speedup figure redrawn with the corrected GPU values |
| [`tcmp/`](tcmp/) | comparator-delay sweep on both geometries, and the original July 2025 sweep |
| [`dataset/`](dataset/) | SSB generator build script and patch |
| [`PAPER_CHANGES.md`](PAPER_CHANGES.md) | replacement text for the camera-ready, item by item |
