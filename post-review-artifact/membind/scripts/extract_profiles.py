import json, sys, os
prof, rc = sys.argv[1], sys.argv[2]
Q = ["Q1.1","Q1.2","Q1.3","Q2.1","Q2.2","Q2.3","Q3.1","Q3.2","Q3.3","Q3.4","Q4.1","Q4.2","Q4.3"]
def walk(n, out):
    for c in n.get("children", []):
        name = (c.get("operator_type") or c.get("name") or "").strip()
        t = c.get("operator_timing", c.get("timing", 0)) or 0
        out.append((name, float(t))); walk(c, out)
    return out
for q in Q:
    for i in range(1, 6):
        f = os.path.join(prof, f"Query_{q}_run{i:02d}.json")
        try:
            d = json.load(open(f)); ops = walk(d, [])
            tot = sum(t for _, t in ops); j = sum(t for n, t in ops if "JOIN" in n)
            lat = d.get("latency", d.get("timing", d.get("result", "")))
            print(f"{q},{i},{lat},{d.get('cpu_time','')},{j/tot if tot else ''},{rc}")
        except Exception:
            print(f"{q},{i},,,,{rc}")
