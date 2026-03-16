import re

lf = 0
lh = 0
with open('d:/UNBURDEN/ventigo_app/coverage/lcov.info') as f:
    for line in f:
        line = line.strip()
        if line.startswith('LF:'):
            lf += int(line[3:])
        elif line.startswith('LH:'):
            lh += int(line[3:])

print(f'{lh}/{lf} = {lh/lf*100:.1f}%')
