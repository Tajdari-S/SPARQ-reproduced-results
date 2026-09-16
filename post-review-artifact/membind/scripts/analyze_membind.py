#!/usr/bin/env python3
"""Compare DuckDB with and without its memory bound to one socket, and estimate
the effect on Figure 11's warm speedups.

Reads ../results/fig11_{none,mem1}_rep*.csv and ../results/numastat*.log.
Warm = mean of runs 2-5 per repetition; the tables use the median over
repetitions. Writes ../results/membind_summary.csv.
"""
import csv, glob, math, os, statistics as st

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "results")
Q = ["Q1.1", "Q1.2", "Q1.3", "Q2.1", "Q2.2", "Q2.3", "Q3.1", "Q3.2", "Q3.3", "Q3.4", "Q4.1", "Q4.2", "Q4.3"]

# Figure 11 as plotted (figures_generation/Fig11.py in the full artifact), seconds
PLOT_DUCKDB_WARM = [0.147667414, 0.09488183875, 0.1035408065, 0.21365058825, 0.18315722, 0.169013347, 0.4223779015, 0.275773053, 0.305143238, 0.19015059325, 0.4224444615, 0.36970307, 0.24304288575]
PLOT_SPARQ_WARM = [0.131676256443981, 0.0854609603226451, 0.0948416257786857, 0.0945870769466617, 0.087656818770166, 0.0841820583798497, 0.212444749790514, 0.0639915316298561, 0.128318381054703, 0.00709454572504574, 0.140006696662751, 0.0803504101109045, 0.0276646439095934]
PLOT_SPARQ_WARM_JOIN = [0.0015175297731125, 5.36332252614584e-05, 5.21960648895834e-05, 0.0859208417344857, 0.0827987392046108, 0.0820058833645087, 0.139958143301651, 0.0584083251703931, 0.125310021514597, 0.00177243414969974, 0.114090822792311, 0.0385300965176815, 0.0205878913079511]
PLOT_DUCKDB_WARM_JOIN = [0.0177190976766479, 0.00958355579094849, 0.00879027399655515, 0.204986315382846, 0.178283177769396, 0.166866927963085, 0.349890527024363, 0.270202121190566, 0.302117394481474, 0.184985621131857, 0.396231329930058, 0.327845941751651, 0.235984450087825]


def load(mode):
    reps = []
    for f in sorted(glob.glob(os.path.join(RES, f"fig11_{mode}_rep*.csv"))):
        rows = [r for r in csv.DictReader(open(f)) if r["seconds"]]
        if len(rows) < 65:
            continue
        reps.append({q: st.mean(float(r["seconds"]) for r in rows if r["query"] == q and r["run"] != "1")
                     for q in Q})
    return reps


def gm(x):
    return math.exp(sum(map(math.log, x)) / len(x))


def main():
    none, mem1 = load("none"), load("mem1")
    print(f"repetitions: unbound {len(none)}, memory bound to node 1 {len(mem1)}")
    peaks = {}
    for f in glob.glob(os.path.join(RES, "numastat*.log")):
        for line in open(f):
            tag, _, n0, n1, *_ = line.split()
            p = peaks.setdefault(tag.split("-")[1], [0.0, 0.0])
            p[0] = max(p[0], float(n0) / 1024)
            p[1] = max(p[1], float(n1) / 1024)
    for mode, (a, b) in sorted(peaks.items()):
        print(f"peak DuckDB memory, {mode}: node 0 {a:.1f} GB, node 1 {b:.1f} GB")

    print(f"\n{'warm':6}{'unbound':>10}{'bound':>10}{'change':>9}{'spread':>9}")
    rows, ratios = [], []
    for q in Q:
        a = st.median(r[q] for r in none)
        b = st.median(r[q] for r in mem1)
        spread = max(max(r[q] for r in rs) / min(r[q] for r in rs) - 1 for rs in (none, mem1))
        ratios.append(b / a)
        rows.append({"query": q, "warm_unbound_ms": round(a * 1e3, 1), "warm_membind_ms": round(b * 1e3, 1),
                     "change_pct": round(100 * (b / a - 1), 1), "max_rep_spread_pct": round(100 * spread, 1)})
        print(f"{q:6}{a*1e3:>8.0f}ms{b*1e3:>8.0f}ms{100*(b/a-1):>+8.0f}%{100*spread:>8.0f}%")
    ta = sum(st.median(r[q] for r in none) for q in Q)
    tb = sum(st.median(r[q] for r in mem1) for q in Q)
    print(f"geomean change {100*(gm(ratios)-1):+.1f}%, total {ta:.2f}s -> {tb:.2f}s ({100*(tb/ta-1):+.1f}%)")

    # Figure 11: SPARQ bar = DuckDB - DuckDB join + SPARQ join (Section 5.2.5).
    # Scale each query's plotted DuckDB time, join included, by the measured ratio;
    # SPARQ's join time is simulated and does not depend on where DuckDB's memory lives.
    s0, s1 = [], []
    for i, r in enumerate(ratios):
        d, s, dj, sj = (PLOT_DUCKDB_WARM[i], PLOT_SPARQ_WARM[i],
                        PLOT_DUCKDB_WARM_JOIN[i], PLOT_SPARQ_WARM_JOIN[i])
        s0.append(d / (d - dj + sj))            # r = 1: the formula on the plotted values
        s1.append(d * r / (d * r - dj * r + sj))
        rows[i].update(speedup_unbound=round(s0[-1], 2), speedup_membind=round(s1[-1], 2))
    print(f"\nFigure 11 warm speedup (formula): unbound {min(s0):.2f}-{max(s0):.1f}x (geomean {gm(s0):.2f}x), "
          f"memory on one socket {min(s1):.2f}-{max(s1):.1f}x (geomean {gm(s1):.2f}x)")
    with open(os.path.join(RES, "membind_summary.csv"), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print("-> results/membind_summary.csv")


if __name__ == "__main__":
    main()
