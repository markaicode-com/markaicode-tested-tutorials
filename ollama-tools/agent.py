"""Minimal Ollama tool-calling agent: Python standard library only (no pip install).
Usage: python agent.py <model> "<question>" [--log results.jsonl]
The agent can only touch files inside ./workspace next to this script."""
import json, sys, time, urllib.request
from pathlib import Path

OLLAMA = "http://localhost:11434/api/chat"
WORKSPACE = (Path(__file__).parent / "workspace").resolve()
WORKSPACE.mkdir(exist_ok=True)

def safe_path(name):
    p = (WORKSPACE / name).resolve()
    if WORKSPACE not in p.parents:
        raise ValueError("path outside the workspace")
    return p

def list_files():
    return json.dumps([{"name": f.name, "bytes": f.stat().st_size} for f in sorted(WORKSPACE.iterdir()) if f.is_file()])

def read_file(filename):
    return safe_path(filename).read_text(encoding="utf-8-sig")

def write_file(filename, content):
    safe_path(filename).write_text(content, encoding="utf-8")
    return f"wrote {len(content)} characters to {filename}"

TOOLS = {"list_files": list_files, "read_file": read_file, "write_file": write_file}

SCHEMAS = [
    {"type": "function", "function": {"name": "list_files",
        "description": "List the files in the user's workspace folder",
        "parameters": {"type": "object", "properties": {}, "required": []}}},
    {"type": "function", "function": {"name": "read_file",
        "description": "Read a text file from the workspace",
        "parameters": {"type": "object", "properties": {
            "filename": {"type": "string", "description": "File name, e.g. todo.txt"}},
            "required": ["filename"]}}},
    {"type": "function", "function": {"name": "write_file",
        "description": "Create or overwrite a text file in the workspace",
        "parameters": {"type": "object", "properties": {
            "filename": {"type": "string", "description": "File name, e.g. summary.txt"},
            "content": {"type": "string", "description": "Full text to write"}},
            "required": ["filename", "content"]}}},
]

def chat(model, messages):
    body = json.dumps({"model": model, "messages": messages, "tools": SCHEMAS,
                       "stream": False, "options": {"temperature": 0}}).encode()
    req = urllib.request.Request(OLLAMA, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)

def run(model, question, max_rounds=6):
    messages = [{"role": "user", "content": question}]
    calls, t0 = [], time.time()
    for _ in range(max_rounds):
        msg = chat(model, messages)["message"]
        messages.append(msg)
        if not msg.get("tool_calls"):
            return {"answer": msg.get("content", ""), "calls": calls, "seconds": round(time.time() - t0, 1)}
        for tc in msg["tool_calls"]:
            name = tc["function"]["name"]
            args = tc["function"].get("arguments") or {}
            arg_type = type(args).__name__          # Ollama's native API returns a dict
            if isinstance(args, str):
                args = json.loads(args)
            try:
                result = TOOLS[name](**args) if name in TOOLS else f"error: unknown tool {name}"
            except Exception as e:                  # report errors back to the model
                result = f"error: {e}"
            calls.append({"tool": name, "args": args, "arg_type": arg_type, "result": str(result)[:200]})
            messages.append({"role": "tool", "tool_name": name, "content": str(result)})
    return {"answer": "(stopped: too many tool rounds)", "calls": calls, "seconds": round(time.time() - t0, 1)}

if __name__ == "__main__":
    model, question = sys.argv[1], sys.argv[2]
    out = run(model, question)
    out.update(model=model, question=question)
    print(json.dumps(out, ensure_ascii=False, indent=2))
    if "--log" in sys.argv:
        with open(sys.argv[sys.argv.index("--log") + 1], "a", encoding="utf-8") as f:
            f.write(json.dumps(out, ensure_ascii=False) + "\n")
