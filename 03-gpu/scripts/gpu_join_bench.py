#!/usr/bin/env python3
"""GPU join baseline for Figure 10, with data loading outside the timed region.

Why this replaces BestGPU.py
----------------------------
BestGPU.py builds a dask-cudf graph and starts its timer immediately before
`client.persist(joined); wait(joined)`. `persist()` on the *input* tables is
asynchronous, so nothing guarantees the CSV read and parse have finished when
the timer starts -- the measured "GPU compute" time therefore included reading
and parsing 6.2-68 GB. The DuckDB bars in the same figure preload outside their
timing, so the two baselines were not measuring the same thing.

This harness loads every table first, synchronises the device, and only then
times the join -- matching the DuckDB protocol.

It also drops dask-cudf for plain cudf: the dask-cuda workers fail to start on
this host ("Nanny failed to start worker process", a UCX/CUDA-context
interaction). A single A100 holds SF1 and SF10 comfortably, so the distributed
layer bought nothing here.

Usage:  python3 gpu_join_bench.py [SF ...]        # default: 1 10
"""
import sys, time, json, statistics as st
import os
import cudf, cupy as cp

DATA_ROOT = os.environ.get('DATA_ROOT', '/p/pd/pim')

LO = ['orderkey','linenumber','custkey','partkey','suppkey','orderdate','orderpriority',
      'shippriority','quantity','extendedprice','ordtotalprice','discount','revenue',
      'supplycost','tax','commitdate','shipmode']
DIMS = {
 'customer': (['custkey','name','address','city','nation','region','phone','mktsegment'], 'custkey'),
 'part':     (['partkey','name','mfgr','category','brand1','color','type','size','container'], 'partkey'),
 'supplier': (['suppkey','name','address','city','nation','region','phone'], 'suppkey'),
 'date':     (['datekey','date','dayofweek','month','year','yearmonthnum','yearmonth',
               'daynuminweek','daynuminmonth','daynuminyear','monthnuminyear','weeknuminyear',
               'sellingseason','lastdayinweekfl','lastdayinmonthfl','holidayfl','weekdayfl'], 'datekey'),
}
LOKEY = {'customer':'custkey','part':'partkey','supplier':'suppkey','date':'orderdate'}
REPS = 3
# INCLUDE_LOAD=1 reproduces the ORIGINAL methodology: the CSV read and parse
# happen inside the timed region, as they effectively did in BestGPU.py, where
# the timer started before the asynchronous persist() on the input tables had
# completed. Default (0) is the corrected protocol: load, synchronise, then time.
INCLUDE_LOAD = os.environ.get("INCLUDE_LOAD", "0") == "1"

def load(path, names, sep):
    return cudf.read_csv(path, sep=sep, names=names, usecols=list(range(len(names))))

def main():
    sfs = sys.argv[1:] or ['1','10']
    out = []
    for sf in sfs:
        d = f'{DATA_ROOT}/sf{sf}'
        sep = '|'
        mode = "LOAD INSIDE TIMING (original)" if INCLUDE_LOAD else "load outside timing (corrected)"
        print(f"\n=== SF{sf} ({d}) -- {mode} ===")
        t0 = time.time()
        lo = load(f'{d}/lineorder.tbl', LO, sep)
        cp.cuda.runtime.deviceSynchronize()
        print(f"  lineorder {len(lo):,} rows loaded in {time.time()-t0:.1f}s (UNTIMED)")
        for tbl,(names,key) in DIMS.items():
            try:
                t1 = time.time()
                dim = load(f'{d}/{tbl}.tbl', names, sep)
                cp.cuda.runtime.deviceSynchronize()
                lk = LOKEY[tbl]
                print(f"  {tbl} {len(dim):,} rows loaded in {time.time()-t1:.1f}s (UNTIMED)")
                times = []
                for r in range(REPS):
                    cp.cuda.runtime.deviceSynchronize()
                    t = time.time()
                    if INCLUDE_LOAD:
                        # original behaviour: the read lands inside the timing
                        _lo = load(f'{d}/lineorder.tbl', LO, sep)
                        _dim = load(f'{d}/{tbl}.tbl', names, sep)
                        j = _lo.merge(_dim, left_on=lk, right_on=key, how='inner')
                        n = len(j)
                        cp.cuda.runtime.deviceSynchronize()
                        times.append((time.time()-t)*1000)
                        del j, _lo, _dim
                    else:
                        j = lo.merge(dim, left_on=lk, right_on=key, how='inner')
                        n = len(j)
                        cp.cuda.runtime.deviceSynchronize()
                        times.append((time.time()-t)*1000)
                        del j
                m = st.median(times)
                print(f"    JOIN {tbl}: median {m:.1f} ms  ({n:,} rows)  runs={[f'{x:.1f}' for x in times]}")
                out.append({'sf':sf,'table':tbl,'ms':round(m,1),'rows':n})
                del dim
            except Exception as e:
                print(f"    JOIN {tbl}: FAILED {type(e).__name__}: {str(e)[:150]}")
                out.append({'sf':sf,'table':tbl,'ms':None,'error':str(e)[:150]})
        del lo
    tag = "_withload" if INCLUDE_LOAD else ""
    with open(f'gpu_join_results{tag}.json','w') as f:
        json.dump(out, f, indent=1)
    print(f"\nwrote gpu_join_results.json ({len([o for o in out if o.get('ms')])} successful)")

if __name__ == '__main__':
    main()
