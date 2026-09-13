"""Build the GPU tables in README.md from the logs in ../results/logs.

Latency is the median over the uniform_loadfixed_rep*.log runs; spread is
max/min - 1 across them. SPARQ values: x8 = the plotted bars (Figures 7/10),
x16 = the geometry 02-sparq ships (see ../../sparq/README.md).
"""
import re, os, glob, statistics as st, math, csv
HERE = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(HERE, '..', 'results', 'logs')
OUTDIR = os.path.join(HERE, '..', 'results')
ORDER = ['customer', 'date', 'supplier', 'part', 'customer2']
T = ['customer', 'part', 'supplier', 'date']
SFS = ['1', '10', '100']
PAPER = {'customer': [169.4, 1890.0, 65034.5], 'part': [190.1, 1830.2, 53258.7],
         'supplier': [73.8, 1823.2, 53202.0], 'date': [75.4, 1947.7, 56112.3]}
SPARQ_X8 = {'customer': [0.7439975, 8.472425, 74.6538175], 'part': [1.07678875, 12.407645, 101.314633],
            'supplier': [0.968215, 9.3331375, 101.365995], 'date': [0.764128125, 7.642613125, 76.424375]}
SPARQ_X16 = {'customer': [0.606875, 7.738110, 60.7226619], 'part': [0.9840988, 16.3618206, 88.4881244],
             'supplier': [0.5306981, 7.7169088, 88.7382494], 'date': [None, None, None]}
def parse(path):
    out, sf, k = {}, None, 0
    for line in open(path, errors='replace'):
        m = re.search(r'Processing SF(\d+)\b', line)
        if m: sf, k = m.group(1), 0; continue
        m = re.search(r'Join computed in ([\d.]+)ns', line)
        if m and sf:
            out[(sf, ORDER[k])] = float(m.group(1)) / 1e6; k += 1
        elif sf and 'Join failed' in line:
            k += 1
    return out
runs = {
  'as_is_sf_dependent': [parse(f'{LOGS}/original_BestGPU_sf_dependent.log')],
  'uniform_as_is':      [parse(f'{LOGS}/uniform_as_is.log')],
  'uniform_loadfixed':  [parse(p) for p in sorted(glob.glob(f'{LOGS}/uniform_loadfixed_rep*.log'))],
}
runs['uniform_loadfixed'] = [r for r in runs['uniform_loadfixed'] if len(r) == 15]
n = len(runs['uniform_loadfixed'])
def med(name, sf, t): 
    v = [r[(sf, t)] for r in runs[name] if (sf, t) in r]; return st.median(v) if v else None
def spread(name, sf, t):
    v = [r[(sf, t)] for r in runs[name] if (sf, t) in r]; return (max(v)/min(v) - 1) * 100 if len(v) > 1 else None
rows = []
print(f"uniform_loadfixed repetitions: {n}\n")
print(f"{'':15}{'paper ms':>10}{'orig (SF-dep)':>15}{'uniform as-is':>15}{'uniform fixed':>15}{'fixed/paper':>12}{'spread':>8}")
for sf_i, sf in enumerate(SFS):
    for t in T:
        p = PAPER[t][sf_i]; a = med('as_is_sf_dependent', sf, t); u = med('uniform_as_is', sf, t); f = med('uniform_loadfixed', sf, t); s = spread('uniform_loadfixed', sf, t)
        print(f"SF{sf:<4}{t:10}{p:>10.1f}{a:>15.1f}{u:>15.1f}{f:>15.1f}{f/p:>11.2f}x{(f'{s:.0f}%' if s is not None else '-'):>8}")
        rows.append(dict(sf=sf, table=t, paper_ms=p, orig_sf_dependent_ms=round(a,1), uniform_as_is_ms=round(u,1),
                         uniform_loadfixed_median_ms=round(f,1), loadfixed_over_paper=round(f/p,3),
                         loadfixed_spread_pct=(round(s,1) if s is not None else ''), reps=n))
print("\nSpeedup of SPARQ over the GPU baseline (GPU ms / SPARQ ms)")
print(f"{'':15}{'paper (x8)':>12}{'fixed vs x8':>13}{'fixed vs x16':>14}")
for sf_i, sf in enumerate(SFS):
    for t in T:
        p = PAPER[t][sf_i]; f = med('uniform_loadfixed', sf, t)
        x8 = SPARQ_X8[t][sf_i]; x16 = SPARQ_X16[t][sf_i]
        print(f"SF{sf:<4}{t:10}{p/x8:>11.0f}x{f/x8:>12.0f}x{(f'{f/x16:.0f}x' if x16 else '-'):>14}")
        rows[sf_i*4 + T.index(t)].update(speedup_paper_x8=round(p/x8), speedup_fixed_x8=round(f/x8), speedup_fixed_x16=(round(f/x16) if x16 else ''))
with open(f'{OUTDIR}/gpu_uniform_results.csv', 'w', newline='') as fh:
    w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
print("\n-> results/gpu_uniform_results.csv")
