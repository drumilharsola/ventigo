import os

lcov = open(os.path.join("d:", os.sep, "UNBURDEN", "ventigo_app", "coverage", "lcov.info")).read()

records = lcov.strip().split("end_of_record")
data = []
for rec in records:
    lines_rec = rec.strip().split("\n")
    sf = ""
    lf = lh = 0
    for l in lines_rec:
        l = l.strip()
        if l.startswith("SF:"):
            sf = l[3:]
        elif l.startswith("LF:"):
            lf = int(l[3:])
        elif l.startswith("LH:"):
            lh = int(l[3:])
    if sf and lf > 0:
        miss = lf - lh
        pct = round(lh / lf * 100, 1) if lf else 0
        # Shorten path
        short = sf.replace("lib/", "")
        data.append((miss, lf, lh, pct, short))

# Sort by most uncovered lines
data.sort(key=lambda x: -x[0])
print(f"{'File':<50} {'Lines':>5} {'Hit':>5} {'Miss':>5} {'Cov%':>5}")
print("-" * 75)
for miss, lf, lh, pct, sf in data:
    print(f"{sf:<50} {lf:>5} {lh:>5} {miss:>5} {pct:>5}%")
print("-" * 75)
total_lf = sum(d[1] for d in data)
total_lh = sum(d[2] for d in data)
print(f"{'TOTAL':<50} {total_lf:>5} {total_lh:>5} {total_lf-total_lh:>5} {round(total_lh/total_lf*100,1):>5}%")
