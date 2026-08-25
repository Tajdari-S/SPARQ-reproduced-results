# Reproduced results

All three measured components of SPARQ were re-measured on the paper's hardware.
This page states what to expect when you run them, and which settings move the
numbers.

Host used: 2x Intel Xeon Gold 6330 (112 threads), 251 GiB, NVIDIA
A100-PCIE-40GB, Ubuntu 22.04.4.

## What to expect

**SPARQ simulation (Figure 7).** Deterministic — repeated runs of the same trace
through the same configuration give **identical** cycle counts, so run-to-run
variance is zero. Reproduced join latencies at SF1 are 0.61, 0.98 and 0.53 µs for
customer, part and supplier, in the same order and the same magnitude as
published. Absolute values depend on the simulator configuration; the `.ini` that
produced these ships in `02-sparq/config/`, and changing `tCCD_S`/`tCCD_L`, the
rank count or `tCMP` moves them.

**DuckDB baselines (Figures 7–11).** Repeat runs agree within about 5% at SF1 and
SF10. Absolute latency, however, is dominated by three settings, and a run that
differs from ours in any of them will differ by much more than run-to-run noise:

* **Storage class.** The identical database file on a network mount versus local
  disk changes a cold query by **2–22x**, growing with scale factor. Warm runs
  are identical. Measure on local disk.
* **DuckDB version.** v0.8.0 and v1.1.3 differ by up to **2.4x** on the same
  query, and reverse order on multi-way joins — v1.1.3 is faster on two-table
  joins, v0.8.0 on four-table joins. Figure 8 and Figure 11 were measured with
  v0.8.0, Figures 7, 9 and 10 with v1.1.3.
* **Query form.** Materialising the join output costs roughly **30x** a
  `COUNT(*)`. Figures 7, 9 and 10 plot the materialised form; Figure 8 plots
  `COUNT(*)`.

With all three matched, our re-measurements land within about 20% of the
published values for Figure 7 and Figure 11. Figures 8 and 9 were originally
measured with the database on a network mount; measured on local disk they are
correspondingly faster, which is the storage effect above rather than a
disagreement about the join itself.

**GPU baseline (Figure 10).** Repeat runs agree within **1%**. The published
values were taken with the CSV read inside the timed region, because
`persist()` on the input tables is asynchronous and nothing waited on it; the
DuckDB bars in the same figure preload outside their timing. Measured both ways
on the same host: 2,543 ms with the load inside, 186 ms with it outside, for the
SF10 customer join. `03-gpu/` measures with the load outside, matching the
DuckDB protocol; set `INCLUDE_LOAD=1` to reproduce the original behaviour.

## Supporting results

| | outcome |
|---|---|
| `tCMP` sweep (Sec. 5.3.4) | completion cycle rises monotonically: +6.0%, +11.0%, +14.9% at tCMP 1, 2, 4 |
| Duplication-list micro-benchmark (Sec. 5.1) | 0.80 / 45.3 / 8.2 ns per operation, against 1.3 / 58.8 / 11.6 published on slower silicon; same ordering |
| All 8 figure scripts | 8 succeed, 0 fail |

## Measured values

Raw runs are in each component's `results/` directory. Medians, on local disk,
using the binary each figure was measured with:

**SPARQ, SF1** — customer 606,875 ns (971,000 cycles); part 984,099 ns
(1,574,558); supplier 530,698 ns (849,117). Latency is the last read cycle from
the DRAMsim3 command trace times 0.625 ns.

**DuckDB, SF1 / SF10 / SF100** — star joins: customer 405 / 3,212 / 28,156 ms,
part 549 / 3,592 / 32,204 ms, supplier 348 / 2,921 / 29,406 ms. Self-join
(v0.8.0): 150 / 1,026 / 14,810 ms. SSB queries warm, SF100, 13-query total:
3,395 ms on v0.8.0, 4,779 ms on v1.1.3.

**GPU, SF1 / SF10** — customer 47.3 / 186.1 ms, part 46.6 / 191.4 ms, supplier
44.7 / 389.5 ms, date 50.1 / 450.5 ms.

## Requires hardware we did not have

| | requirement |
|---|---|
| Figure 2 | Intel Advisor (free for non-commercial use) |
| Figure 3 | DuckDB built with the instrumentation patch, which ships here |
| Figure 10 GPU at SF100 | more than 40 GB of GPU memory; 600M rows x 17 int32 columns is ~41 GB |
| Area and power (Sec. 5.3.2–5.3.3) | Synopsys Design Compiler and a 14 nm PDK under NDA |
