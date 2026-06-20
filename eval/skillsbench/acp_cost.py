#!/usr/bin/env python3
"""Sum true token usage + cost from a Claude Code session transcript .jsonl.

Works even for killed/timed-out runs: Claude Code writes per-turn `usage`
incrementally, unlike benchflow's end-of-session flush (which logs 0 on a kill).
Dedupes by message id so streamed partials/retries aren't double-counted.

Sonnet 4.6 pricing per 1M: in $3, out $15, cache-read $0.30, cache-write $3.75.

Usage:
  acp_cost.py <transcript.jsonl>          # human-readable
  acp_cost.py <transcript.jsonl> --csv    # cost,in,out,cacheR,cacheW (for run_sp_batch.sh)
"""
import json, sys

def summarize(path):
    ti=to=cr=cw=0; seen=set()
    for ln in open(path):
        try: j=json.loads(ln)
        except Exception: continue
        msg=j.get("message") or {}
        u=msg.get("usage") or j.get("usage")
        if not isinstance(u,dict): continue
        mid=msg.get("id") or j.get("uuid")
        if mid and mid in seen: continue
        if mid: seen.add(mid)
        ti+=u.get("input_tokens",0) or 0
        to+=u.get("output_tokens",0) or 0
        cr+=u.get("cache_read_input_tokens",0) or 0
        cw+=u.get("cache_creation_input_tokens",0) or 0
    cost=ti/1e6*3 + to/1e6*15 + cr/1e6*0.30 + cw/1e6*3.75
    return cost,ti,to,cr,cw,len(seen)

if __name__=="__main__":
    path=sys.argv[1]
    cost,ti,to,cr,cw,n=summarize(path)
    if "--csv" in sys.argv:
        print(f"{cost:.4f},{ti},{to},{cr},{cw}")
    else:
        print(f"in={ti} out={to} cacheR={cr} cacheW={cw}")
        print(f"assistant_turns={n}")
        print(f"COST=${cost:.4f}")
