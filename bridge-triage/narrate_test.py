"""Run the article's narrate() on two synthetic reports with local models and check for invented numbers."""
import json, re, sys, time
import bridge_triage as bt

T0 = 1_700_000_000
hist = [100_000, 120_000, 90_000, 110_000, 105_000, 95_000]
cases = {
    "kelp-like release": bt.triage([bt.Event(T0, "release", 290_000_000)], hist, tvl_usd=50_000_000, window_start_ts=T0),
    "ronin-like drain": bt.triage([bt.Event(T0+10, "withdraw", 3_000_000, "0xnew", T0+5),
                                   bt.Event(T0+20, "withdraw", 2_500_000, "0xnew", T0+5)], hist, tvl_usd=50_000_000, window_start_ts=T0),
}
host = "http://127.0.0.1:11500"
def nums(s):
    return {n.replace(",", "") for n in re.findall(r"\d[\d,]*(?:\.\d+)?", s)}
for model in sys.argv[1:]:
    for name, rep in cases.items():
        facts = json.dumps({"bridge": "ExampleBridge", "level": rep.level, "score": rep.score, "findings": [vars(x) for x in rep.findings]})
        t0 = time.perf_counter()
        out = bt.narrate(rep, "ExampleBridge", model=model, host=host)
        extra = sorted(nums(out) - nums(facts) - {"1", "2", "3", "4", "5"})
        level_ok = rep.level.lower() in out.lower()
        print(json.dumps({"model": model, "case": name, "level": rep.level, "score": rep.score, "seconds": round(time.perf_counter() - t0, 1),
                          "mentions_level": level_ok, "numbers_not_in_json": extra, "text": out}), flush=True)
