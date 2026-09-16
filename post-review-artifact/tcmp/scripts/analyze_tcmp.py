#!/usr/bin/env python3
"""Summarise the tCMP sensitivity sweep (Section 5.3.4) and check its direction.

Reads
  ../results/tcmp_sweep.csv                    re-simulated here (sweep_tcmp.sh)
  ../results/july2025_x16_tccd_sweep/          the original July 2025 x16 sweep
and prints, per geometry, the join-latency increase over tCMP = 0 using the
completion cycle (the metric behind every SPARQ latency in the paper), then the
same sweep under DRAMsim3's average_read_latency for comparison.

Exits non-zero if any completion-cycle latency with tCMP > 0 is below tCMP = 0.
Writes ../results/tcmp_summary.csv.
"""
import csv
import os
import re
import statistics as st
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "results")
JULY = os.path.join(RES, "july2025_x16_tccd_sweep")
STEPS = ["tCCDS1_tCCDL2", "tCCDS2_tCCDL3", "tCCDS3_tCCDL4", "tCCDS4_tCCDL5", "tCCDS5_tCCDL6"]
NAME = {"C2": "customer", "C3": "part", "C4": "supplier", "C5": "date"}
JOINS = ("C2", "C3", "C4", "C5")

# Section 5.3.4 as published
PAPER = {"t1_avg": 11.0, "t4_avg": 32.0, "max": 61.0, "max_at": "customer SF1"}
# Speedup over DuckDB at tCMP = 0, as in the GPU/CPU speedup figure (PIM/CPU bars),
# which is where the paper's "400x-1000x" comes from. Customer SF100 uses the
# 74,739 ms CPU value from that script; Figures 7 and 10 use 46,291 ms.
PIM_NS = {"C2": [743997.5, 8472425, 74653817.5], "C3": [1076788.75, 12407645, 101314633.125],
          "C4": [968215, 9333137.5, 101365995], "C5": [764128.125, 7642613.125, 76424375]}
CPU_NS = {"C2": [377e6, 4726e6, 74739e6], "C3": [436e6, 5473e6, 55760e6],
          "C4": [455e6, 4274e6, 51596e6], "C5": [425e6, 4174e6, 50596e6]}
SFS = ["1", "10", "100"]


def load_sweep():
    """-> {(geometry, sf, col, tcmp): completion cycle}"""
    p = os.path.join(RES, "tcmp_sweep.csv")
    out = {}
    for r in csv.DictReader(open(p)):
        out[(r["geometry"], r["sf"], r["col"], int(r["tcmp"]))] = int(r["completion_cycle"])
    return out


def load_july():
    """-> completion cycles and average_read_latency from the July x16 sweep.
    That sweep raised tCCD_S/tCCD_L by 1..4 cycles, which is how the simulator
    implements tCMP (tCCD += tCMP), so step t equals tCMP = t."""
    cyc, arl = {}, {}
    for t, s in enumerate(STEPS):
        txt = open(os.path.join(JULY, f"Sensitivity_dramsim_report_x16_correct_{s}.txt")).read()
        for m in re.finditer(r"ch1_sf(\d+)_(C\d)_x16\.txt\n.*\n(\d+)\s+read", txt):
            cyc[("x16", m.group(1), m.group(2), t)] = int(m.group(3))
        for sf in SFS:
            for c in ("C2", "C3", "C4"):
                f = os.path.join(JULY, "per_trace_stats", f"{s}_sf{sf}_{c}_dramsim3.txt")
                v = re.search(r"average_read_latency\s*=\s*([\d.]+)", open(f).read())
                arl[("x16", sf, c, t)] = float(v.group(1))
    return cyc, arl


def table(title, data, geom, sfs, cols):
    """Print increases over t=0; return per-cell increases."""
    print(f"\n{title}")
    print(f"  {'':16}" + "".join(f"{'tCMP=' + str(t):>10}" for t in range(1, 5)))
    cells = {}
    for sf in sfs:
        for c in cols:
            if (geom, sf, c, 0) not in data:
                continue
            b = data[(geom, sf, c, 0)]
            inc = [100.0 * (data[(geom, sf, c, t)] - b) / b for t in range(1, 5)]
            cells[(sf, c)] = inc
            print(f"  {NAME[c] + ' SF' + sf:16}" + "".join(f"{v:>9.1f}%" for v in inc))
    if cells:
        avg = [st.mean(v[t] for v in cells.values()) for t in range(4)]
        print(f"  {'average':16}" + "".join(f"{v:>9.1f}%" for v in avg) + f"   ({len(cells)} joins)")
        (sf, c), inc = max(cells.items(), key=lambda kv: kv[1][3])
        print(f"  max at tCMP=4: {inc[3]:.1f}% ({NAME[c]} SF{sf})")
    return cells


def main():
    sweep = load_sweep()
    july_cyc, july_arl = load_july()
    ok = True
    rows = []

    # the re-simulation of x16 must equal the July sweep cycle for cycle
    same = [k for k in sweep if k[0] == "x16" and k in july_cyc]
    diff = [k for k in same if sweep[k] != july_cyc[k]]
    print(f"x16 re-simulation vs July 2025 sweep: {len(same) - len(diff)}/{len(same)} identical")
    ok &= not diff

    print(f"\nPaper, Sec. 5.3.4: +{PAPER['t1_avg']:.0f}% at tCMP=1, +{PAPER['t4_avg']:.0f}% average "
          f"at tCMP=4, max +{PAPER['max']:.0f}% ({PAPER['max_at']})")

    x8 = table("x8 (the configuration of Figures 7 and 10), completion cycle",
               sweep, "x8", SFS, JOINS)
    x16 = table("x16 (the July 2025 sweep), completion cycle", july_cyc, "x16", SFS, ("C2", "C3", "C4"))
    table("x16, average_read_latency (the metric the old getting_started.sh used)",
          july_arl, "x16", SFS, ("C2", "C3", "C4"))

    for geom, cells in (("x8", x8), ("x16", x16)):
        for (sf, c), inc in cells.items():
            rows.append({"geometry": geom, "sf": sf, "table": NAME[c],
                         **{f"increase_tcmp{t}_pct": round(inc[t - 1], 2) for t in range(1, 5)}})
            if min(inc) < 0:
                ok = False
                print(f"  DIRECTION ERROR: {geom} {NAME[c]} SF{sf} falls below tCMP=0")

    # speedup over DuckDB before and after tCMP = 4, x8 bars
    if len(x8) == 12:
        before = [CPU_NS[c][i] / PIM_NS[c][i] for c in JOINS for i in range(3)]
        after = [CPU_NS[c][i] / (PIM_NS[c][i] * (1 + x8[(SFS[i], c)][3] / 100)) for c in JOINS for i in range(3)]
        print(f"\nSPARQ speedup over DuckDB (x8): {min(before):.0f}x-{max(before):.0f}x at tCMP=0, "
              f"{min(after):.0f}x-{max(after):.0f}x at tCMP=4 (paper: 400x-1000x -> 324x-916x)")
        c46 = dict(CPU_NS, C2=[CPU_NS['C2'][0], CPU_NS['C2'][1], 46291e6])
        b2 = [c46[c][i] / PIM_NS[c][i] for c in JOINS for i in range(3)]
        a2 = [c46[c][i] / (PIM_NS[c][i] * (1 + x8[(SFS[i], c)][3] / 100)) for c in JOINS for i in range(3)]
        print(f"  with customer SF100 CPU = 46,291 ms (Figs. 7/10): {min(b2):.0f}x-{max(b2):.0f}x -> "
              f"{min(a2):.0f}x-{max(a2):.0f}x")

    with open(os.path.join(RES, "tcmp_summary.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print("\n-> results/tcmp_summary.csv")
    print("direction check:", "PASS (latency never falls below tCMP=0)" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
