from bridge_triage import *
T0 = 1_700_000_000
hist = [100_000, 120_000, 90_000, 110_000, 105_000, 95_000]
def w(evts): return triage(evts, hist, tvl_usd=50_000_000, window_start_ts=T0)

# normal
r = w([Event(T0+i*60, "withdraw", 10_000, f"0x{i}", T0-999999) for i in range(10)]); print("normal", r.level, r.score); assert r.level=="Low"
# Ronin-like: two huge withdrawals to a fresh address (synthetic)
r = w([Event(T0+10,"withdraw",3_000_000,"0xnew",T0+5), Event(T0+20,"withdraw",2_500_000,"0xnew",T0+5)])
print("drain", r.level, r.score, [x.rule for x in r.findings]); assert r.level in("High","Critical")
# Nomad-like swarm: 80 recipients within 5 min
r = w([Event(T0+i*3,"withdraw",20_000,f"0xa{i}",T0-1) for i in range(80)])
print("swarm", r.level, r.score, [x.rule for x in r.findings]); assert any(x.rule=="R4_copycat_swarm" for x in r.findings)
# unbacked mint
r = w([Event(T0,"mint",1_000_000), Event(T0,"lock",100_000)]); print("mint", r.level, r.score); assert r.level=="Critical"
# admin change alone
r = w([Event(T0,"admin_change")]); print("admin", r.level, r.score); assert r.level=="Medium"
# Kelp-like: release with no matching burn (synthetic)
r = w([Event(T0,"release",290_000_000)]); print("release", r.level, r.score, [x.rule for x in r.findings]); assert any(x.rule=="R7_unmatched_release" for x in r.findings) and r.level=="Critical"
# matched release is fine
r = w([Event(T0,"release",1_000_000), Event(T0,"burn",1_000_000)]); assert not any(x.rule=="R7_unmatched_release" for x in r.findings)
# quorum: 2 of 3 agree; 3-way disagreement fails
import bridge_triage as bt
seq = iter(["0x1","0x1","0x9"]); bt.rpc = lambda u,m,p,timeout=20: next(seq)
assert bt.rpc_quorum(["a","b","c"],"eth_blockNumber",[]) == "0x1"
seq = iter(["0x1","0x2","0x3"])
try: bt.rpc_quorum(["a","b","c"],"eth_blockNumber",[]); raise SystemExit("should fail")
except RuntimeError: pass
print("ALL OK")
