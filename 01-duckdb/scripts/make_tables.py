#!/usr/bin/env python3
"""Emit RESULTS_TABLES.md: every re-measured figure, both DuckDB versions.

Two questions are answered separately, because they are different questions:

  1. How different are the results from what the paper plots?
     -> reproduced / plotted, using the binary each figure was plotted with.
  2. How much of the difference is the DuckDB version?
     -> v0.8.0 against v1.1.3, both on local disk, same data, same query form.

All measurements are on LOCAL disk. The plotted values for Figures 8 and 9 were
measured with the database on NFS, which inflates cold queries - see NOTES.md #0.

Usage:  python3 make_tables.py > RESULTS_TABLES.md
"""
import csv
import glob
import os
import statistics as st
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "results")
ALIAS = {"distinct_orderkey": "C-0", "where_linenumber_3": "C-1"}
SFS = ["1", "10", "100"]

PLOT = {
    ("fig7", "customer"): [328, 4726, 46291],
    ("fig7", "part"): [436, 5473, 55760],
    ("fig7", "supplier"): [302, 4274, 51596],
    ("fig8", "selfjoin_orderkey"): [249, 2071, 20929],
    ("fig10", "date"): [425, 4174, 50596],
}
PLOT9 = {
    "distinct": {"1": [196, 149, 130, 265, 119, 122],
                 "10": [1243, 951, 2014, 2053, 972, 957],
                 "100": [12272, 11489, 23139, 23665, 19699, 11496]},
    "where": {"1": [249, 1495, 1138, 732, 1368, 1354],
              "10": [102, 12394, 3540, 4055, 12132, 12183],
              "100": [290, 137218, 24931, 35775, 71243, 137134]},
}
QN = ["Q1.1", "Q1.2", "Q1.3", "Q2.1", "Q2.2", "Q2.3",
      "Q3.1", "Q3.2", "Q3.3", "Q3.4", "Q4.1", "Q4.2", "Q4.3"]
P11C = [661.98, 351.19, 348.94, 850.51, 880.64, 565.24,
        1051.09, 1147.87, 719.44, 509.20, 1241.29, 1271.79, 1062.80]
P11W = [147.67, 94.88, 103.54, 213.65, 183.16, 169.01,
        422.38, 275.77, 305.14, 190.15, 422.44, 369.70, 243.04]


def load():
    d = {"v0.8.0": defaultdict(list), "v1.1.3": defaultdict(list)}
    for f in glob.glob(os.path.join(RES, "figure_series_*.csv")):
        for r in csv.DictReader(open(f)):
            if r["seconds"] and r["version"] in d:
                # Figure 9 keys include the series, since distinct and where
                # share the same column names.
                fig = r["figure"]
                if fig == "fig9":
                    fig = "fig9_" + r["series"].replace("duckdb_", "")
                d[r["version"]][(fig, r["sf"], ALIAS.get(r["name"], r["name"]))].append(r["seconds"])
    p = os.path.join(RES, "corrected_baselines.csv")
    if os.path.exists(p):
        for r in csv.DictReader(open(p)):
            if r["seconds"] and r["storage"] == "local":
                nm = r["name"]
                v = "v0.8.0" if nm == "selfjoin_orderkey" else "v1.1.3"
                d[v][(r["figure"], r["sf"], nm.replace("_v113", ""))].append(r["seconds"])
    p = os.path.join(RES, "fig9_all_columns.csv")
    if os.path.exists(p):
        for r in csv.DictReader(open(p)):
            if r["seconds"] and r["storage"] == "local":
                d["v1.1.3"][("fig9_" + r["series"], r["sf"], r["column"])].append(r["seconds"])
    p = os.path.join(RES, "fig10_date.csv")
    if os.path.exists(p):
        for r in csv.DictReader(open(p)):
            if r["seconds"] and r["storage"] == "local":
                d["v1.1.3"][("fig7_10", r["sf"], "date")].append(r["seconds"])
    p = os.path.join(RES, "v080_complete.csv")
    if os.path.exists(p):
        for r in csv.DictReader(open(p)):
            if r["seconds"]:
                key = ("fig9_" + r["series"].replace("duckdb_", ""), r["sf"], r["name"]) \
                      if r["figure"] == "fig9" else (r["figure"], r["sf"], r["name"])
                d["v0.8.0"][key].append(r["seconds"])
    return d


def med(d, v, *k):
    x = d[v].get(tuple(k))
    return st.median([float(i) for i in x]) * 1000 if x else None


def f11(tag):
    p = os.path.join(RES, f"fig1_11_profiled_{tag}.csv")
    out = {}
    if os.path.exists(p):
        for r in csv.DictReader(open(p)):
            if r["seconds"]:
                out.setdefault(r["query"], {})[int(r["run"])] = float(r["seconds"]) * 1000
    return out


def cell(v):
    return "pending" if v is None else f"{v:,.0f}"


def verdict(a, b):
    if a is None or b is None:
        return "incomplete"
    r = a / b
    if r > 1.05:
        return f"v1.1.3 {r:.2f}x faster"
    if r < 0.95:
        return f"v0.8.0 {1/r:.2f}x faster"
    return "equivalent"


def main():
    d = load()
    print("# Re-measured results, both DuckDB versions\n")
    print("Every latency below was measured with the database on **local disk**. "
          "The plotted values for Figures 8 and 9 were measured with it on NFS, "
          "which inflates a cold query - see [`NOTES.md`](NOTES.md) #0.\n")

    print("\n## 1. Version comparison — v0.8.0 against v1.1.3\n")
    print("| Figure | Parameter | v0.8.0 (ms) | v1.1.3 (ms) | Verdict |")
    print("|---|---|---:|---:|---|")
    rows = []
    for t in ("customer", "part", "supplier"):
        for sf in SFS:
            rows.append(("Fig 7", f"{t} SF{sf}", med(d, "v0.8.0", "fig7_10", sf, t),
                         med(d, "v1.1.3", "fig7_10", sf, t)))
    for sf in SFS:
        rows.append(("Fig 8", f"self-join SF{sf}",
                     med(d, "v0.8.0", "fig8", sf, "selfjoin_orderkey"),
                     med(d, "v1.1.3", "fig8", sf, "selfjoin_orderkey")))
    for s in ("distinct", "where"):
        for sf in SFS:
            a = [med(d, "v0.8.0", f"fig9_{s}", sf, f"C-{i}") for i in range(6)]
            b = [med(d, "v1.1.3", f"fig9_{s}", sf, f"C-{i}") for i in range(6)]
            rows.append(("Fig 9", f"{s} 6-col total SF{sf}",
                         sum(a) if all(x is not None for x in a) else None,
                         sum(b) if all(x is not None for x in b) else None))
    for sf in SFS:
        rows.append(("Fig 10", f"date SF{sf}", med(d, "v0.8.0", "fig7_10", sf, "date"),
                     med(d, "v1.1.3", "fig7_10", sf, "date")))
    a11, b11 = f11("v0.8.0"), f11("v1.1.3")
    for i, q in enumerate(QN):
        for kind in ("cold", "warm"):
            def g(src):
                r = src.get(q, {})
                if not r:
                    return None
                if kind == "cold":
                    return r.get(1)
                w = [x for k, x in r.items() if k >= 2]
                return st.mean(w) if w else None
            rows.append(("Fig 11", f"{q} {kind}", g(a11), g(b11)))
    for fig, par, a, b in rows:
        print(f"| {fig} | {par} | {cell(a)} | {cell(b)} | {verdict(a, b)} |")

    print("\n## 2. How different from the plotted values\n")
    print("Each figure is compared against the binary it was plotted with: "
          "v0.8.0 for Figure 8, v1.1.3 for the rest.\n")
    print("| Figure | Parameter | plotted (ms) | reproduced (ms) | reproduced/plotted |")
    print("|---|---|---:|---:|---:|")
    for t in ("customer", "part", "supplier"):
        for i, sf in enumerate(SFS):
            m = med(d, "v1.1.3", "fig7_10", sf, t)
            if m:
                p = PLOT[("fig7", t)][i]
                print(f"| Fig 7 | {t} SF{sf} | {p:,} | {m:,.0f} | {m/p:.2f}x |")
    for i, sf in enumerate(SFS):
        m = med(d, "v0.8.0", "fig8", sf, "selfjoin_orderkey")
        if m:
            p = PLOT[("fig8", "selfjoin_orderkey")][i]
            print(f"| Fig 8 | self-join SF{sf} | {p:,} | {m:,.0f} | {m/p:.2f}x |")
    for s in ("distinct", "where"):
        for sf in SFS:
            b = [med(d, "v1.1.3", f"fig9_{s}", sf, f"C-{i}") for i in range(6)]
            if all(x is not None for x in b):
                p = sum(PLOT9[s][sf])
                print(f"| Fig 9 | {s} 6-col SF{sf} | {p:,} | {sum(b):,.0f} | {sum(b)/p:.2f}x |")
    for i, sf in enumerate(SFS):
        m = med(d, "v1.1.3", "fig7_10", sf, "date")
        if m:
            p = PLOT[("fig10", "date")][i]
            print(f"| Fig 10 | date SF{sf} | {p:,} | {m:,.0f} | {m/p:.2f}x |")
    for i, q in enumerate(QN):
        r = b11.get(q, {})
        if not r:
            continue
        c = r.get(1)
        w = [x for k, x in r.items() if k >= 2]
        if c:
            print(f"| Fig 11 | {q} cold | {P11C[i]:,.0f} | {c:,.0f} | {c/P11C[i]:.2f}x |")
        if w:
            m = st.mean(w)
            print(f"| Fig 11 | {q} warm | {P11W[i]:,.0f} | {m:,.0f} | {m/P11W[i]:.2f}x |")

    print("\n## Not re-measured\n")
    print("* **Figure 2** needs Intel Advisor; **Figure 3** needs the instrumented "
          "v1.4.0-dev build. Neither is a plain latency measurement.\n")
    print("* **Figure 10's GPU series** needs RAPIDS and an A100. Note also that "
          "`BestGPU.py` materialises lazily inside its timed region, so it includes "
          "CSV parsing that the DuckDB bars exclude - see NOTES.md #7b.\n")
    print("* **Figure 1** shares Figure 11's data.\n")


if __name__ == "__main__":
    main()
