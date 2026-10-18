"""barlines.py NNN staff bar [bar...] : print the source lines of given bars with occurrence numbers"""
import convert, sys, collections
n = int(sys.argv[1]); staff = int(sys.argv[2]); want = set(int(x) for x in sys.argv[3:])
lines = convert.load(f'src/nwc/{n:03d}.nwc')
seen = collections.Counter(); si = 0; bar = 1
for l in lines:
    seen[l] += 1
    if l.startswith('|AddStaff'): si += 1; bar = 1; continue
    if si != staff: continue
    if l.startswith('|Bar'): bar += 1
    if bar in want and l.startswith(('|Chord', '|Note', '|Rest', '|RestChord', '|Bar')): print(bar, seen[l], l)
