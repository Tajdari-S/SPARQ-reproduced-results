# Camera-ready changes

One entry per item in the evaluation report, with the replacement text and the
evidence behind it. Section and reference numbers follow the submitted paper.

## 1. Figure 10 and Section 5.2.3: GPU timing

Evidence: [`gpu/`](gpu/), redrawn figures in [`figures/`](figures/).

- Replace the GPU arrays of Figure 10 with the medians in
  [`gpu/results/gpu_uniform_results.csv`](gpu/results/gpu_uniform_results.csv).
- Replace the Section 5.2.3 paragraph:

> We evaluate the same joins using Dask-cuDF (RAPIDS 24.12) [1, 69] with CUDA [63]
> on a 40 GB NVIDIA A100. SF100 exceeds device memory, so, like prior out-of-core
> GPU joins that partition inputs to fit the device [78], all scale factors use
> 256 MiB partitions, host spilling, and broadcast dimension joins. Inputs are
> loaded, parsed, and persisted before timing (Sec. 5.2.1). Latency includes join
> execution and spill-related transfers, but excludes initial loading and final
> result transfer; results stay on the device. We report the median of three runs,
> with at most 23% variation. Because SSB dimension keys are unique, the build-side
> and identical-key skew that degrades GPU hash joins [14, 78] does not arise. When
> data fits in device memory, in-memory cuDF takes 45–50 ms at SF1 and 186–451 ms
> at SF10, within an order of magnitude of a hand-tuned GPU-resident hash join on
> the same A100 [14]; SPARQ is 15–66× faster. Beyond device memory, GPU latency
> grows 37–59× from SF10 to SF100 for a 10× larger input, reflecting the host–device
> data movement that bounds out-of-core GPU joins [78].

SPARQ's speedup over this baseline: 118–221× at SF1, 126–223× at SF10,
581–1019× at SF100.

## 2. Section 5.3.4: comparator delay

Evidence: [`tcmp/`](tcmp/). The published averages came from an earlier sweep on a
different memory geometry and do not reproduce; these are re-simulated on the
configuration of Figure 7. Replace from "However, to assess its impact" to "1.1x–27x.":

> However, to assess its impact, we model a fixed per-read delay tCMP in DRAMSim3,
> sweeping it from 0 to 4 cycles on the configuration of Figure 7 while measuring
> join latency across SSB scale factors. Latency never decreases as tCMP grows.
> Increasing tCMP from 0 to 1 cycle increases the SSB join operator average latency
> by 5.5% (SF1–100). Once the subarray delay exceeds the burst cycle, it becomes a
> dominant constraint [35] in the controller's scheduling decisions, altering the
> order of requests and the timing of activate/precharge commands: average join
> latency rises by 41% at tCMP = 3 and 45% at tCMP = 4, with a maximum of 54% for
> the customer–lineorder join at SF1. This reduces SPARQ's join speedup over DuckDB
> from 405×–1001× to 295×–651×. When integrated with DuckDB to run full SSB SF100
> queries, the speedup range changes from 1.1×–28× to 1.1×–27×.

The speedup range depends on item 7 below. With the customer SF100 CPU value that
Figures 7 and 10 plot, it reads "405×–662× to 295×–442×".

## 3. Figures 1 and 11: modeled end-to-end results

Section 5.2.5 already describes the method; the abstract, introduction and
captions should say so too.

- Abstract: "…and 5.7× end-to-end query speedup over CPU-only DuckDB" →
  "…and a modeled 5.7× end-to-end query speedup over CPU-only DuckDB".
- Section 1: "On individual SSB SQL queries, running on DuckDB integrated with
  SPARQ" → "On individual SSB SQL queries, modeling DuckDB integrated with SPARQ".
- Figure 1 caption, B: "…DuckDB with SPARQ (modeled; Sec. 5.2.5)."
- Figure 11 caption: "SSB query latency: SPARQ-integrated DuckDB (modeled by
  replacing DuckDB's measured join time with SPARQ's simulated join latency) vs.
  CPU-only DuckDB. Hatched bars indicate join latency."

## 4. Figure 7 and Section 5.2.2

- **SPARQ bars: no change.** They are the x8 configuration the paper describes
  (Section 5.1: tCCD ≈ 2.5 ns = 4 cycles), and [`sparq/`](sparq/) reproduces them
  exactly. The evaluator measured the x16 configuration the artifact shipped by
  mistake.
- **C++ baseline:** "We also include a single-threaded C++ hash join
  implementation" → "We also include a single-threaded C++ hash join
  implementation, compiled with `-O0`,". (The artifact appendix reports `-O2` is
  about 3× faster; we did not re-measure this.)
- **Table 2 description:** "where we partition the tables for multi-threading and
  build the relevant hash data set. For fair comparison, all PIM/CPU setup/build
  phases are implemented in optimized single-threaded C++" → "where we partition
  the tables into 112 partitions, as a 112-thread build would, and build the hash
  tables. For a fair comparison, all PIM/CPU setup/build phases run in a single
  thread, in optimized C++". The build programs in `SPARQ/setup/hash_build/`
  (`optpart.cpp`, `partmm.cpp`, `Largepmm.cpp`) use 112 partitions and create no
  threads.

## 5. Data generation

Evidence: [`dataset/`](dataset/). In the appendix, replace the ssb-dbgen
instructions with:

> Generate SSB with `vadimtk/ssb-dbgen` at commit `0741e06`, patched to build with
> GCC 14 and to fix an intermittent crash
> (`post-review-artifact/dataset/scripts/build_ssb_dbgen.sh`), then remove the
> dashes from `lineorder.tbl` so dates are `YYYYMMDD` integers.

## 6. CPU baseline configuration per figure

| Figure | DuckDB | database storage | evidence |
|---|---|---|---|
| 1, 11 | v0.8.0 | not recorded | re-measured totals are 1.08× the plotted values under v0.8.0 and 1.52× under v1.1.3; v0.8.0 is closer on 10 of 13 queries (the artifact previously said v1.1.3) |
| 2 | not recorded (`advisor.sh` runs `../duckdb`) | `/p/pd/duckdb_work` (NFS) | `advisor.sh` |
| 3 | instrumented v1.4.0-dev | not recorded | full-artifact README |
| 7, 10 | v1.1.3 | local disk | plotted values are within 24–40% of local-disk runs, and 2.3–5.2× below NFS-cold runs |
| 8 | v0.8.0 | NFS | plotted values within 4% of NFS-cold runs |
| 9 | v1.1.3 | NFS | plotted values within 0–2% of NFS-cold runs |

**Sockets.** None of the original measurement scripts pins DuckDB or limits its
threads below the machine's 112 (`run_joins.sh` sets 111). The published CPU
baselines therefore used both sockets. The appendix's instruction to pin one
socket does not describe how the figures were measured, and should be removed or
labelled as an optional experiment. Pinning with `numactl` alone also leaves
DuckDB at 112 threads on 56 cores, which is oversubscribed rather than a clean
single-socket run (full artifact, `duckdb_versions/NOTES.md`).

The storage column comes from matching plotted values against the same query run
from NFS and from local disk (full artifact, `figures_updated/README.md`).

## 7. Open: two CPU values disagree between figure scripts

- Customer SF100: 74,739 ms in the speedup figure, 46,291 ms in Figures 7 and 10.
  This decides whether the operator-level speedup tops out at 1001× or 662×.
- SF1 customer and supplier: 377 and 455 ms in Figure 10, 328 and 302 ms in
  Figure 7.

The measurement logs that would settle these were not found; the value that
matches a log should be used in all three figures.

## 8. Artifact availability

Deposit the final evaluated version (this repository, including
`post-review-artifact/`) on Zenodo and cite that DOI. The current DOI,
`10.5281/zenodo.21875929`, predates every post-review change.

## Smaller items from the report

| item | status |
|---|---|
| `import importlib.util` bug in `run_all_figures.sh` | fixed in the full artifact (`cf41672`, 2026-08-21) |
| `getting_started.sh` checks for a difference, not an increase | fixed in `cf41672`: it now compares completion cycles and fails unless tCMP > 0 is slower |
| "JSPIM" references and typo'd script names (`DucDBSSBFullQUery.sh`, `calassichashjoin.cpp`) | not renamed: the paper, appendix and evaluation logs cite these paths |
| reduced-scale path for CPU and GPU | `gpu/scripts/run.sh` and `01-duckdb/scripts/corrected_baselines.sh` take SF1/SF10 on their own; neither needs SF100 |
