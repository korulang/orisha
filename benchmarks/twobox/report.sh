#!/usr/bin/env bash
# Turn raw lines into a table. Median of rounds, not best — a best-of hides the
# variance that says whether the number means anything.
set -euo pipefail
OUT="$1"
echo "# Two-box benchmark — $(basename "$OUT")"
echo; echo '```'; cat "$OUT/provenance.txt"; echo '```'; echo
echo "## Throughput (median of rounds, requests/sec)"; echo
python3 - "$OUT/raw.txt" <<'PY'
import sys,collections,statistics as st
rows=collections.defaultdict(list); steal=collections.defaultdict(list); verify={}
for line in open(sys.argv[1]):
    p=line.strip().split('|')
    if p[0]=='RESULT':
        _,c,path,conns,rps,p50,p99,non2=p[:8]
        rows[(path,conns,c)].append((float(rps),p50,p99,non2))
    elif p[0]=='STEAL':
        steal[p[1]].append(int(p[3]))
    elif p[0]=='VERIFY':
        verify[p[1]]=(int(p[2]),int(p[3]),int(p[4]))
works=sorted({(k[0],k[1]) for k in rows})
cs=sorted({k[2] for k in rows})
for path,conns in works:
    print(f"\n**`{path}` at {conns} connections**\n")
    print("| server | req/s | p50 | p99 | non-2xx |"); print("|---|---|---|---|---|")
    got=[(c,rows[(path,conns,c)]) for c in cs if (path,conns,c) in rows]
    for c,v in sorted(got,key=lambda x:-st.median([r[0] for r in x[1]])):
        med=st.median([r[0] for r in v])
        print(f"| {c} | {med:,.0f} | {v[0][1]} | {v[0][2]} | {v[0][3]} |")
print("\n## Correctness — checked before anything was timed\n")
print("| server | identical | wrong | of |"); print("|---|---|---|---|")
for c,(ok,bad,tot) in sorted(verify.items()):
    print(f"| {c} | {ok} | {bad} | {tot} |")
print("\n## CPU steal on the server during runs\n")
print("Non-zero steal means the machine lost cycles to a neighbour and the run")
print("is suspect, however good the number looks.\n")
print("| server | steal ticks (per round) |"); print("|---|---|")
for c in sorted(steal): print(f"| {c} | {', '.join(map(str,steal[c]))} |")
PY
