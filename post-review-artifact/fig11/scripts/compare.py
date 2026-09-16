#!/usr/bin/env python3
"""Figure 11 speedups: published vs. the post-review arrays.

  python3 compare.py [april-profile-dir]

published: the April 2025 unbound v1.1.3 session for both bars.
new:       DuckDB bars from results/unbound_full; SPARQ bars = bound DuckDB
           (results/bound_full) - bound DuckDB join + SPARQ join.
Writes ../results/speedups.csv.
"""
import csv, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_fig11_arrays as m

R = os.path.join(HERE, "..", "results")
pub = m.arrays(sys.argv[1] if len(sys.argv) > 1 else
               "/p/pd/newduckdb/scripts/duckdb_profiles_cougar_20250407_133702")
unb = m.arrays(os.path.join(R, "unbound_full", "profiles"))
bnd = m.arrays(os.path.join(R, "bound_full", "profiles"))
gm = lambda x: math.exp(sum(map(math.log, x)) / len(x))
rows = []
for i, q in enumerate(m.Q):
    rows.append({"query": "Q" + q,
                 "cold_published": pub["duckdb_cold"][i] / pub["jspim_cold"][i],
                 "cold_new": unb["duckdb_cold"][i] / bnd["jspim_cold"][i],
                 "warm_published": pub["duckdb_warm"][i] / pub["jspim_warm"][i],
                 "warm_new": unb["duckdb_warm"][i] / bnd["jspim_warm"][i]})
print(f"{'':6}{'cold pub':>10}{'cold new':>10}{'warm pub':>10}{'warm new':>10}")
for r in rows:
    print(f"{r['query']:6}" + "".join(f"{r[k]:>9.2f}x" for k in ("cold_published", "cold_new", "warm_published", "warm_new")))
for k in ("cold_published", "cold_new", "warm_published", "warm_new"):
    v = [r[k] for r in rows]
    print(f"{k:16} {min(v):.2f}-{max(v):.1f}x  geomean {gm(v):.2f}x")
with open(os.path.join(R, "speedups.csv"), "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
