"""Ollama keep_alive tests against a temporary server. Prints one JSON line per check. Stdlib only.
Usage: python keepalive.py --port 11500 --part main|env"""
import argparse, json, re, subprocess, time, urllib.request
from datetime import datetime, timezone

P = 11500
def call(path, body=None, timeout=600):
    req = urllib.request.Request(f"http://127.0.0.1:{P}{path}", data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"{}")

def gen(model, prompt="Say hi in three words.", n=16, **kw):
    b = {"model": model, "prompt": prompt, "stream": False, "options": {"num_predict": n, "temperature": 0}}
    b.update(kw)
    t0 = time.perf_counter()
    d = call("/api/generate", b)
    return {"wall_s": round(time.perf_counter() - t0, 2), "load_s": round(d.get("load_duration", 0) / 1e9, 2),
            "done_reason": d.get("done_reason"), "response": (d.get("response") or "")[:40]}

def ps():
    out = []
    now = datetime.now(timezone.utc)
    for m in call("/api/ps").get("models", []):
        exp = m.get("expires_at", "")
        try:
            x = re.sub(r"(\.\d{6})\d+", r"\1", exp.replace("Z", "+00:00"))
            left = round((datetime.fromisoformat(x) - now).total_seconds())
        except Exception:
            left = None
        out.append({"name": m["name"], "size_mb": round(m.get("size", 0) / 2**20), "vram_mb": round(m.get("size_vram", 0) / 2**20),
                    "expires_at": exp, "seconds_left": left})
    return out

def gpu():
    try:
        return subprocess.run(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader"], capture_output=True, text=True).stdout.strip()
    except Exception as e:
        return str(e)

def log(step, **kw):
    print(json.dumps({"step": step, **kw, "ps": ps(), "gpu_used": gpu()}), flush=True)

def main():
    global P
    ap = argparse.ArgumentParser(); ap.add_argument("--port", type=int, default=11500); ap.add_argument("--part", default="main")
    a = ap.parse_args(); P = a.port
    if a.part == "env":
        log("env-default-request", r=gen("phi4-mini"))
        log("env-request-keep_alive-2m", r=gen("phi4-mini", keep_alive="2m"))
        call("/api/generate", {"model": "phi4-mini", "keep_alive": 0})
        return
    log("start")
    log("cold-load phi4-mini (default keep_alive)", r=gen("phi4-mini"))
    log("warm request phi4-mini", r=gen("phi4-mini"))
    call("/api/generate", {"model": "phi4-mini", "keep_alive": 0}); time.sleep(2)
    log("after keep_alive 0 (unload)")
    log("reload phi4-mini after unload", r=gen("phi4-mini"))
    log("keep_alive 30s", r=gen("phi4-mini", keep_alive="30s"))
    time.sleep(35)
    log("35 s later")
    log("keep_alive -1 (pin)", r=gen("phi4-mini", keep_alive=-1))
    t0 = time.perf_counter(); d = call("/api/generate", {"model": "gemma4:e4b", "keep_alive": "10m"})
    log("empty request preloads gemma4:e4b", r={"wall_s": round(time.perf_counter() - t0, 2), "done_reason": d.get("done_reason"),
                                                "load_s": round(d.get("load_duration", 0) / 1e9, 2), "response": d.get("response")})
    try:
        log("load gemma4:26b while phi4-mini is pinned", r=gen("gemma4:26b", n=8, keep_alive="5m"))
    except Exception as e:
        log("load gemma4:26b while phi4-mini is pinned", error=str(e)[:300])
    try:
        log("request pinned phi4-mini again", r=gen("phi4-mini"))
    except Exception as e:
        log("request pinned phi4-mini again", error=str(e)[:300])

if __name__ == "__main__":
    main()
