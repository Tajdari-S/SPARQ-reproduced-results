#!/usr/bin/env python3
"""Match every plotted SPARQ bar against the two original simulation reports.

  results/original_reports/march2025_x8_report.txt   DDR4 x8,  run.sh in oldrankopt/
  results/original_reports/july2025_x16_report.txt   DDR4 x16, tCCD_S=1 tCCD_L=2 sweep point

Each report holds, per trace, the last READ line of the DRAMsim3 command trace;
its first field is the completion cycle. Latency (ns) = cycle x 0.625.

Writes results/geometry_comparison.csv and prints the table.
"""
import csv
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "results")
TCK_NS = 0.625
COL = {"customer": "C2", "part": "C3", "supplier": "C4", "date": "C5"}
# Figures 7 and 10, ns (identical SPARQ values in both figures)
PLOTTED = {
    "customer": [743997.5, 8472425, 74653817.5],
    "part": [1076788.75, 12407645, 101314633.125],
    "supplier": [968215, 9333137.5, 101365995],
    "date": [764128.125, 7642613.125, 76424375],
}
SFS = ["1", "10", "100"]


def cycles(report):
    """-> {(sf, col): completion cycle}"""
    txt = open(os.path.join(RES, "original_reports", report)).read()
    out = {}
    for m in re.finditer(r"ch1_sf(\d+)_(C\d)(?:_x16)?\.txt\n.*\n(\d+)\s+read", txt):
        out[(m.group(1), m.group(2))] = int(m.group(3))
    return out


x8 = cycles("march2025_x8_report.txt")
x16 = cycles("july2025_x16_report.txt")

rows = []
print(f"{'':9}{'SF':>4}{'plotted cyc':>14}{'x8 report':>14}{'x8=plot':>9}{'x16 report':>14}{'x16/plot':>10}")
for t in PLOTTED:
    for i, sf in enumerate(SFS):
        p = round(PLOTTED[t][i] / TCK_NS)
        a = x8.get((sf, COL[t]))
        b = x16.get((sf, COL[t]))
        rows.append({
            "table": t, "sf": sf, "col": COL[t],
            "plotted_ns": PLOTTED[t][i], "plotted_cycles": p,
            "x8_cycles": a if a is not None else "", "x8_matches_plotted": a == p,
            "x16_cycles": b if b is not None else "",
            "x16_ns": round(b * TCK_NS, 1) if b else "",
            "x16_over_plotted": round(b / p, 3) if b else "",
        })
        print(f"{t:9}{sf:>4}{p:>14,}{(f'{a:,}' if a else '-'):>14}{('YES' if a == p else 'no'):>9}"
              f"{(f'{b:,}' if b else '-'):>14}{(f'{b/p:.2f}x' if b else '-'):>10}")

with open(os.path.join(RES, "geometry_comparison.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0]))
    w.writeheader()
    w.writerows(rows)
n = sum(r["x8_matches_plotted"] for r in rows)
print(f"\n{n}/{len(rows)} plotted bars equal the x8 report cycle-for-cycle -> results/geometry_comparison.csv")
