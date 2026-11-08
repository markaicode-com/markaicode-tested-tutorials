"""bridge_triage.py - rules-first bridge triage with an optional local Ollama narrator.

The deterministic rules decide the risk level. The LLM only explains the result.
Thresholds are starting heuristics, NOT empirically calibrated values: back-test them.
"""
from __future__ import annotations
import json, statistics
from dataclasses import dataclass, field
from collections import defaultdict
import requests

# ---------- 1. Data layer (real JSON-RPC helper; bridge-specific decoding is your adapter) ----------
def rpc(url: str, method: str, params: list, timeout: int = 20):
    r = requests.post(url, json={"jsonrpc": "2.0", "id": 1, "method": method, "params": params}, timeout=timeout)
    r.raise_for_status()
    body = r.json()
    if "error" in body:
        raise RuntimeError(body["error"])
    return body["result"]

def get_logs(url: str, address: str, from_block: int, to_block: int, topics: list | None = None):
    """Raw event logs for one bridge contract. Decode amounts with that bridge's ABI."""
    return rpc(url, "eth_getLogs", [{
        "address": address, "fromBlock": hex(from_block), "toBlock": hex(to_block),
        **({"topics": topics} if topics else {}),
    }])

def rpc_quorum(urls: list[str], method: str, params: list, min_agree: int = 2):
    """Ask several INDEPENDENT providers and accept only an answer that enough of them agree on.
    A single poisoned or lagging node then cannot silently feed your monitor wrong data."""
    answers: dict[str, int] = defaultdict(int)
    for u in urls:
        try:
            answers[json.dumps(rpc(u, method, params), sort_keys=True)] += 1
        except Exception:
            continue
    if answers:
        best, n = max(answers.items(), key=lambda kv: kv[1])
        if n >= min_agree:
            return json.loads(best)
    raise RuntimeError("no quorum: providers disagree or are unreachable")

# ---------- 2. Normalized event model ----------
@dataclass
class Event:
    ts: int                 # unix seconds
    kind: str               # "withdraw" | "deposit" | "mint" | "lock" | "release" | "burn" | "admin_change"
    usd: float = 0.0
    recipient: str = ""
    recipient_first_seen_ts: int | None = None

@dataclass
class Finding:
    rule: str
    points: int
    detail: str

@dataclass
class Report:
    score: int
    level: str
    findings: list[Finding] = field(default_factory=list)

# ---------- 3. The rubric: seven rules, each mapped to a documented incident pattern ----------
DEFAULTS = dict(
    spike_multiple=5.0,        # R1: window outflow vs trailing median of past windows
    drain_share=0.05,          # R2: one withdrawal >= 5% of bridge TVL
    fresh_share=0.60,          # R3: share of outflow going to addresses first seen in-window
    swarm_recipients=50,       # R4: distinct recipients inside swarm_window_s
    swarm_window_s=600,
    invariant_tolerance=0.001, # R5: minted-vs-locked mismatch tolerance (0.1%)
)

def level(score: int) -> str:
    return "Critical" if score >= 9 else "High" if score >= 6 else "Medium" if score >= 3 else "Low"

def triage(window: list[Event], history_window_outflows: list[float], tvl_usd: float,
           window_start_ts: int, cfg: dict | None = None) -> Report:
    c = {**DEFAULTS, **(cfg or {})}
    f: list[Finding] = []
    outs = [e for e in window if e.kind == "withdraw"]
    out_usd = sum(e.usd for e in outs)

    # R1 outflow spike
    if len(history_window_outflows) >= 5:
        base = statistics.median(history_window_outflows) or 1.0
        if out_usd >= c["spike_multiple"] * base:
            f.append(Finding("R1_outflow_spike", 3, f"outflow ${out_usd:,.0f} vs median ${base:,.0f}"))
    # R2 single-transaction drain
    if tvl_usd > 0 and outs:
        big = max(outs, key=lambda e: e.usd)
        if big.usd / tvl_usd >= c["drain_share"]:
            f.append(Finding("R2_single_tx_drain", 4, f"one withdrawal = {big.usd / tvl_usd:.1%} of TVL"))
    # R3 fresh-recipient concentration
    if out_usd > 0:
        fresh = sum(e.usd for e in outs if (e.recipient_first_seen_ts or 0) >= window_start_ts)
        if fresh / out_usd >= c["fresh_share"]:
            f.append(Finding("R3_fresh_recipients", 2, f"{fresh / out_usd:.0%} of outflow to first-seen addresses"))
    # R4 copycat swarm (many distinct recipients in a short span)
    ts_sorted = sorted(outs, key=lambda e: e.ts)
    lo = 0
    seen: dict[str, int] = defaultdict(int)
    for hi, e in enumerate(ts_sorted):
        seen[e.recipient] += 1
        while e.ts - ts_sorted[lo].ts > c["swarm_window_s"]:
            r = ts_sorted[lo].recipient
            seen[r] -= 1
            if seen[r] == 0:
                del seen[r]
            lo += 1
        if len(seen) >= c["swarm_recipients"]:
            f.append(Finding("R4_copycat_swarm", 3, f"{len(seen)} distinct recipients within {c['swarm_window_s']}s"))
            break
    # R5 supply invariant: destination mints must be backed by source locks
    minted = sum(e.usd for e in window if e.kind == "mint")
    locked = sum(e.usd for e in window if e.kind == "lock")
    if minted > locked * (1 + c["invariant_tolerance"]) and minted > 0:
        f.append(Finding("R5_unbacked_mint", 9, f"minted ${minted:,.0f} > locked ${locked:,.0f}"))
    # R6 signer / config change
    if any(e.kind == "admin_change" for e in window):
        f.append(Finding("R6_admin_change", 4, "validator set, threshold or upgrade event in window"))
    # R7 unmatched release: value released on one chain with no matching burn/lock on the other
    released = sum(e.usd for e in window if e.kind == "release")
    burned = sum(e.usd for e in window if e.kind == "burn")
    if released > burned * (1 + c["invariant_tolerance"]) and released > 0:
        f.append(Finding("R7_unmatched_release", 9, f"released ${released:,.0f} > burned ${burned:,.0f}"))
    score = sum(x.points for x in f)
    return Report(score, level(score), f)

# ---------- 4. Local narrator (Ollama REST API). It cannot change the score. ----------
def narrate(report: Report, bridge: str, model: str = "llama3.1:8b",
            host: str = "http://localhost:11434") -> str:
    facts = json.dumps({"bridge": bridge, "level": report.level, "score": report.score,
                        "findings": [vars(x) for x in report.findings]}, indent=2)
    prompt = ("You are a DeFi incident analyst. Using ONLY the JSON below, write at most 5 sentences: "
              "what triggered, why it matters, what to verify on-chain first. Do not add numbers, "
              "addresses or events that are not in the JSON. Do not change the risk level.\n" + facts)
    r = requests.post(f"{host}/api/chat", json={
        "model": model, "stream": False, "options": {"temperature": 0},
        "messages": [{"role": "user", "content": prompt}]}, timeout=180)
    r.raise_for_status()
    return r.json()["message"]["content"].strip()
