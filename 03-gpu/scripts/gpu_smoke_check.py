#!/usr/bin/env python3
"""
SPARQ artifact - GPU smoke check (Figure 10).

Verifies that the GPU environment works and that join latency lands in the same
range as the reported Figure 10 values, using **plain cudf only** - no Dask.
The full harness (BestGPUReport.py / BestGPU.py) additionally needs dask_cudf,
dask_cuda and distributed; this script exists so the environment can be checked
without them.

Because it skips Dask, it measures a single-GPU merge with no cluster or
partitioning overhead, so expect it to be at or below the reported values rather
than equal to them. It is an order-of-magnitude check, not a reproduction.

Usage:
    python gpu_smoke_check.py [SF1_DIR]

Default SF1_DIR is /p/pd/pim/sf1. Needs lineorder.tbl plus the dimension tables.
"""
import sys
import time

import cudf

SCHEMA = {
    "lineorder": ["lo_orderkey", "lo_linenumber", "lo_custkey", "lo_partkey",
                  "lo_suppkey", "lo_orderdate", "lo_orderpriority",
                  "lo_shippriority", "lo_quantity", "lo_extendedprice",
                  "lo_ordtotalprice", "lo_discount", "lo_revenue",
                  "lo_supplycost", "lo_tax", "lo_commitdate", "lo_shipmode"],
    "customer": ["c_custkey", "c_name", "c_address", "c_city"],
    "part":     ["p_partkey", "p_name", "p_mfgr", "p_category"],
    "supplier": ["s_suppkey", "s_name", "s_address", "s_city"],
    "date":     ["d_datekey", "d_date", "d_dayofweek", "d_month", "d_year"],
}

# (dimension table, left key, right key) - the four joins in Figure 10
JOINS = [
    ("customer", "lo_custkey", "c_custkey"),
    ("part",     "lo_partkey", "p_partkey"),
    ("supplier", "lo_suppkey", "s_suppkey"),
    ("date",     "lo_orderdate", "d_datekey"),
]

# Reported Figure 10 GPU values at SF1, in nanoseconds
REPORTED_SF1_NS = {
    "customer": 169_400_000,
    "part":     190_100_000,
    "supplier":  73_800_000,
    "date":      75_400_000,
}


def load(base, table):
    # Same call shape as the Dask harness: sep, names, dtype only.
    return cudf.read_csv(
        f"{base}/{table}.tbl",
        sep="|",
        names=SCHEMA[table],
        dtype="int32",
    )


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "/p/pd/pim/sf1"
    print(f"cudf {cudf.__version__}")
    print(f"data {base}\n")

    lineorder = load(base, "lineorder")
    print(f"lineorder rows: {len(lineorder):,}\n")

    print(f"{'join':<10} {'measured (ns)':>16} {'reported (ns)':>16} {'ratio':>8}")
    for dim, lkey, rkey in JOINS:
        try:
            right = load(base, dim)
        except Exception as exc:                      # missing table, keep going
            print(f"{dim:<10} skipped: {type(exc).__name__}")
            continue

        joined = lineorder.merge(right, left_on=lkey, right_on=rkey, how="inner")
        n = len(joined)                               # force materialisation
        del joined

        start = time.perf_counter()
        joined = lineorder.merge(right, left_on=lkey, right_on=rkey, how="inner")
        n = len(joined)
        elapsed_ns = (time.perf_counter() - start) * 1e9
        del joined, right

        rep = REPORTED_SF1_NS[dim]
        print(f"{dim:<10} {elapsed_ns:>16,.0f} {rep:>16,} {elapsed_ns/rep:>7.2f}x"
              f"   ({n:,} rows)")

    print("\nA ratio below 1 is expected: this path has no Dask cluster,"
          "\npartitioning or spilling. Reproducing Figure 10 requires the full"
          "\nharness - see README.md in this directory.")


if __name__ == "__main__":
    main()
