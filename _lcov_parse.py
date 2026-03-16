import os
f = open(os.path.join("d:", os.sep, "UNBURDEN", "ventigo_app", "coverage", "lcov.info"), "r")
lines = f.readlines()
f.close()
found = sum(int(l.strip()[3:]) for l in lines if l.strip().startswith("LF:"))
hit = sum(int(l.strip()[3:]) for l in lines if l.strip().startswith("LH:"))
print(f"Lines: {found}, Hit: {hit}, Coverage: {round(hit/found*100, 1)}%")
