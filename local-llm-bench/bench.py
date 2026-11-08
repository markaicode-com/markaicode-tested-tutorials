"""Concurrency benchmark for an Ollama server: N simultaneous /api/generate requests, same prompt, fixed output length.
Prints one JSON line per run. Stdlib only. Usage: python bench.py --port 11500 --model phi4-mini --conc 1 2 4 8"""
import argparse, json, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

PROMPT = ("Write a numbered list of 30 practical tips for keeping a small vegetable garden healthy. "
          "One sentence per tip.")

def one(port, model, n):
    body = json.dumps({"model": model, "prompt": PROMPT, "stream": False,
                       "options": {"num_predict": n, "temperature": 0, "seed": 1}}).encode()
    req = urllib.request.Request(f"http://127.0.0.1:{port}/api/generate", data=body, headers={"Content-Type": "application/json"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.loads(r.read())
    t1 = time.perf_counter()
    return {"wall_s": t1 - t0, "eval_count": d.get("eval_count", 0), "eval_s": d.get("eval_duration", 0) / 1e9,
            "prompt_s": d.get("prompt_eval_duration", 0) / 1e9, "load_s": d.get("load_duration", 0) / 1e9}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=11500)
    ap.add_argument("--model", default="phi4-mini")
    ap.add_argument("--tokens", type=int, default=256)
    ap.add_argument("--conc", type=int, nargs="+", default=[1, 2, 4, 8])
    ap.add_argument("--label", default="")
    a = ap.parse_args()
    one(a.port, a.model, 16)  # warm-up: load the model
    for c in a.conc:
        t0 = time.perf_counter()
        with ThreadPoolExecutor(max_workers=c) as ex:
            res = list(ex.map(lambda _: one(a.port, a.model, a.tokens), range(c)))
        wall = time.perf_counter() - t0
        toks = sum(r["eval_count"] for r in res)
        per = [r["eval_count"] / r["eval_s"] for r in res if r["eval_s"]]
        out = {"label": a.label, "model": a.model, "concurrency": c, "tokens_total": toks, "wall_s": round(wall, 2),
               "aggregate_tok_s": round(toks / wall, 1),
               "per_request_gen_tok_s_avg": round(sum(per) / len(per), 1) if per else None,
               "slowest_request_s": round(max(r["wall_s"] for r in res), 2),
               "fastest_request_s": round(min(r["wall_s"] for r in res), 2)}
        print(json.dumps(out), flush=True)

if __name__ == "__main__":
    main()
