#!/usr/bin/env python3
"""Build Figure 11's arrays from a directory of DuckDB JSON profiles.

  python3 make_fig11_arrays.py <profile-dir>

Profiles are Query_<q>_run<NN>.json, as written by DucDBSSBFullQUery.sh
(one process per query, runs 01..05). Rules, recovered from Fig11.py and the
profiling session it was built from (duckdb_profiles_cougar_20250407_133702):

  duckdb_cold        latency of run 1
  duckdb_warm        mean latency of runs 2-5
  join share         operator time of HASH_JOIN (plus the lineorder TABLE_SCAN
                     for Q2.x-Q4.x) / total operator time, per run
  duckdb_cold_join   run-1 latency x run-1 join share
  duckdb_warm_join   mean warm latency x mean warm join share
  jspim_*            duckdb_* - duckdb_*_join + jspim_*_join   (Section 5.2.5)

jspim_*_join are SPARQ's simulated join latencies and do not change.
"""
import json
import os
import statistics as st
import sys

Q = ["1.1", "1.2", "1.3", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3"]
JSPIM_JOIN = [0.0015175297731125, 0.0000536332252614584, 0.0000521960648895834,
              0.0859208417344857, 0.0827987392046108, 0.0820058833645087,
              0.139958143301651, 0.0584083251703931, 0.125310021514597,
              0.00177243414969974, 0.114090822792311, 0.0385300965176815, 0.0205878913079511]


def operators(node, out):
    for c in node.get("children", []):
        ei = c.get("extra_info") or {}
        table = (ei.get("Table", "") or ei.get("Text", "")) if isinstance(ei, dict) else ""
        out.append((c.get("operator_type", ""), table, c.get("operator_timing", 0.0) or 0.0))
        operators(c, out)
    return out


def run(prof, q, r):
    d = json.load(open(os.path.join(prof, f"Query_{q}_run{r:02d}.json")))
    ops = operators(d, [])
    total = sum(t for *_, t in ops)
    join = sum(t for name, _, t in ops if "JOIN" in name)
    if not q.startswith("1."):
        join += sum(t for name, table, t in ops if name == "TABLE_SCAN" and table == "lineorder")
    return d["latency"], join / total


def arrays(prof):
    out = {k: [] for k in ("duckdb_cold", "duckdb_warm", "duckdb_cold_join", "duckdb_warm_join")}
    for q in Q:
        lat1, share1 = run(prof, q, 1)
        warm = [run(prof, q, r) for r in (2, 3, 4, 5)]
        wl = st.mean(l for l, _ in warm)
        out["duckdb_cold"].append(lat1)
        out["duckdb_warm"].append(wl)
        out["duckdb_cold_join"].append(lat1 * share1)
        out["duckdb_warm_join"].append(wl * st.mean(s for _, s in warm))
    out["jspim_cold"] = [d - dj + j for d, dj, j in zip(out["duckdb_cold"], out["duckdb_cold_join"], JSPIM_JOIN)]
    out["jspim_warm"] = [d - dj + j for d, dj, j in zip(out["duckdb_warm"], out["duckdb_warm_join"], JSPIM_JOIN)]
    return out


def fmt(name, vals):
    rows = [", ".join(repr(v) for v in vals[i:i + 3]) for i in range(0, len(vals), 3)]
    return f"{name} = np.array([\n    " + ",\n    ".join(rows) + "\n])"


if __name__ == "__main__":
    a = arrays(sys.argv[1])
    for k in ("duckdb_cold", "duckdb_warm", "jspim_cold", "jspim_warm", "duckdb_cold_join", "duckdb_warm_join"):
        print(fmt(k, a[k]))
        print()
