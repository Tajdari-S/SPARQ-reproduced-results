import re, sys, os, json
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "results", "logs")
PHASE = "version_sweep"
PLOT = {'customer':{'1':169.4,'10':1890.0,'100':65034.5}, 'part':{'1':190.1,'10':1830.2,'100':53258.7},
        'supplier':{'1':73.8,'10':1823.2,'100':53202.0}, 'date':{'1':75.4,'10':1947.7,'100':56112.3}}
ORDER = ['customer','date','supplier','part','customer']   # every script's join list, in order
TABLES = ['customer','date','supplier','part']
def ms(v, unit, script):
    v = float(v)
    if unit == 'ns': return v/1e6
    if script == 'join_VF': return v            # cupy get_elapsed_time is ms; the script labels it "s"
    return v*1000
def parse(script):
    out = {}   # (sf, table) -> [ms, ...] in encounter order
    sf = None; cur = None; k = 0
    for line in open(os.path.join(R, PHASE, script + '.log'), errors='replace'):
        m = re.search(r'Processing (?:SF|scale factor )(\d+)\b', line)
        if m: sf, cur, k = m.group(1), None, 0; continue
        if sf is None or line.startswith(('Results for', 'lineorder_')): continue   # skip summary duplicates
        m = re.search(r'Joining lineorder (?:⋈|with) (\w+)', line)
        if m: cur = m.group(1); continue
        m = re.search(r'Join \(lineorder\d+ x (\w+?)\d+\) completed in ([\d.]+) seconds', line)
        if m: out.setdefault((sf, m.group(1)), []).append(ms(m.group(2), 's', script)); continue
        if re.search(r'lineorder_\w+ join:', line): continue
        m = re.search(r'Join (?:computed|completed)(?::? [\d,]+ rows)? in ([\d.]+) ?(ns|s|seconds)\b', line)
        if m and 'transferred' not in line.split(' in ')[0]:
            # test7-10 and test13 print each join twice ("Join completed: N rows in" then "Join completed in"); count once
            if script in ('test7','test8','test9','test10','test13') and 'rows' not in line: continue
            t = cur or (ORDER[k] if k < len(ORDER) else None); k += 1; cur = None
            if t: out.setdefault((sf, t), []).append(ms(m.group(1), m.group(2), script))
    return out
scripts = [l.split()[0][:-3] for l in open(os.path.join(R, PHASE, 'PROGRESS')) if ' rc=' in l]
res = {}
for s in scripts:
    try: res[s] = parse(s)
    except FileNotFoundError: pass
json.dump({s: {f"{k[0]}|{k[1]}": v for k, v in d.items()} for s, d in res.items()}, open(os.path.join(R, '..', 'version_sweep_parsed.json'), 'w'), indent=1)
sfs = sorted({k[0] for d in res.values() for k in d}, key=int)
print(f"{'script':14}" + ''.join(f"{'SF'+sf+' '+t[:4]:>11}" for sf in sfs for t in TABLES) + f"{'geo-mean ratio':>16}{'|log err|':>10}")
print(f"{'PAPER':14}" + ''.join(f"{PLOT[t][sf]:>11.1f}" for sf in sfs for t in TABLES))
import math
for s, d in res.items():
    cells, logs = [], []
    for sf in sfs:
        for t in TABLES:
            v = d.get((sf, t))
            if v: cells.append(f"{v[0]:>11.1f}"); logs.append(math.log(v[0]/PLOT[t][sf]))
            else: cells.append(f"{'-':>11}")
    g = f"{math.exp(sum(logs)/len(logs)):>15.2f}x" if logs else f"{'-':>16}"
    e = f"{sum(abs(x) for x in logs)/len(logs):>10.2f}" if logs else f"{'-':>10}"
    print(f"{s:14}" + ''.join(cells) + g + e)
