# SPARQ — reproduced results

Reproduced measurements for **SPARQ: Skew-Aware PIM Accelerator for Relational
Join and Select Queries** (PACT 2026), with from-scratch instructions to
re-measure each one.

| | |
|---|---|
| Full artifact | https://github.com/Tajdari-S/JSPIM |
| Archived | https://doi.org/10.5281/zenodo.21875929 |

> **After artifact evaluation:** see [`post-review-artifact/`](post-review-artifact/).
> The SPARQ bars in Figures 7 and 10 were simulated with a DDR4 x8 geometry, while
> `02-sparq/` ships x16; both now reproduce exactly. The GPU baseline has been
> re-measured with loading outside the timer and one run type at every scale factor,
> the comparator-delay sweep re-run, and the SSB generator pinned and patched. That
> directory supersedes the GPU numbers in `03-gpu/` and `RESULTS.md`.

This repository is the *results* half: the three measured components, the
commands to reproduce each, and the values we obtained. The simulator source,
figure scripts and paper appendix live in the full artifact above.

**`02-sparq/` runs with nothing but a compiler** — the probe traces ship here.
`01-duckdb/` and `03-gpu/` additionally need the SSB dataset (Step 0.5) and, for
the GPU, a CUDA device.


Everything needed to reproduce the three measured components of SPARQ from a
clean machine, with the numbers we obtained doing exactly that.

| | component | what it produces | time | needs |
|---|---|---|---|---|
| [`01-duckdb/`](01-duckdb/) | CPU baseline | DuckDB bars, Figs 7–11 | ~1 h | SSB dataset |
| [`02-sparq/`](02-sparq/) | PIM simulation | SPARQ bars, Fig 7 | ~25 min | nothing |
| [`03-gpu/`](03-gpu/) | GPU baseline | GPU bars, Fig 10 | ~5 min | CUDA GPU + RAPIDS |

Each subdirectory has its own step-by-step README and the raw measurements we
recorded. [`RESULTS.md`](RESULTS.md) collects every number in one table.

**If you only do one thing**, do `02-sparq/` — it ships its own traces and needs
no dataset, no GPU and no network.

---

# Step 0 — prerequisites, from scratch

Assumes a clean x86-64 Linux machine. Ours: Ubuntu 22.04.4 LTS, kernel
5.15.0-113, 2x Intel Xeon Gold 6330 (112 threads), 251 GiB RAM, NVIDIA
A100-PCIE-40GB.

## 0.1 System packages

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake g++ git numactl python3 python3-pip zlib1g-dev
```

Versions we used: gcc 11.4.0, cmake 3.22.1, Python 3.10.12. Anything at or above
gcc 9.4 / cmake 3.10 / Python 3.8 should work.

## 0.2 Python packages

```bash
pip3 install -r tools/requirements.txt
```

That pins numpy 1.26.4, matplotlib 3.8.4, pandas 2.2.2, scipy 1.13.1.

## 0.3 Clone the artifact

```bash
git clone https://github.com/Tajdari-S/JSPIM && cd JSPIM
```

## 0.4 Confirm the toolchain before going further

```bash
bash 02-sparq/reproduce.sh
```

Twenty minutes. Builds the simulator, runs a bundled trace, regenerates all
figures, prints `PASS` or the first failing step. **If this fails, stop here** —
everything below depends on it.

## 0.5 The dataset (needed for 01-duckdb and 03-gpu only)

SSB is generated, not downloaded. Use **this fork** — others do not build on
Linux:

```bash
git clone https://github.com/vadimtk/ssb-dbgen && cd ssb-dbgen
git checkout 0741e06d4c3e811bcec233378a39db2fc0be5d79
make                       # MACHINE=LINUX is already the default in this fork
./dbgen -s 1 -T a          # SF1;  -s 10 and -s 100 for the larger scales
```

`bm_utils.c` calls `gets()`. glibc dropped the C11 declaration but still ships
the symbol, so you get a linker *warning*, not an error. Verified building
unpatched on Ubuntu 22.04.4 with gcc 11.4.0.

Sizes: SF1 664 MB, SF10 5.7 GB, SF100 64 GB.

## 0.6 Check the dataset before measuring against it

```bash
bash tools/validate_data.sh /path/to/ssb/sf1 1
```

Checks row counts, delimiter, date encoding and the join key. Worth the two
minutes — we found real damage in our own copies (one SF10 set short in every
table, one SF100 `lineorder` truncated at 14.9 GB of 68 GB), and both load
"successfully" with `ignore_errors` while giving wrong numbers.

---

# Two conditions that change results more than the effect being measured

Both were measured during this reproduction, and both fail silently.

**Storage class.** Put the database on **local disk**, not a network mount. The
identical file on NFS runs a cold query 2–22x slower, growing with scale factor.
Warm runs are identical, so it only bites measurements that start from a fresh
process — which is the protocol every figure uses.

```bash
cp /net/share/ssb_sf10.duckdb /tmp/ssb_sf10.duckdb    # measure the local copy
```

**DuckDB version.** v0.8.0 and v1.1.3 differ by up to 2.4x on the same query and
*reverse direction* on multi-way joins. Figure 8 was measured with v0.8.0,
Figures 7 and 9–11 with v1.1.3. Pin the version and say which.

Seven more, each with the evidence, in
[`01-duckdb/NOTES.md`](01-duckdb/NOTES.md).
