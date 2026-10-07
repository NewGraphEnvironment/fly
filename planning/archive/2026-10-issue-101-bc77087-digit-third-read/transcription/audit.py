#!/usr/bin/env python3
"""fly#101: audit the reader's transcript for compliance (Amendment A1, G5).

Usage: audit.py <transcript.jsonl> <reader dir>
Lists every tool call the reader made. PASS only if every call is a Read of a file inside the
reader dir and every image in that dir was read. Prints counts only, never file contents.
"""
import json, os, sys

path, rdir = sys.argv[1], os.path.realpath(sys.argv[2])
calls, undecodable, errored = [], 0, set()
with open(path) as fh:
    for line in fh:
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            # A line that cannot be read could hold a tool call; it fails the audit (code-check round 3).
            undecodable += 1
            continue
        msg = rec.get("message") or {}
        if not isinstance(msg.get("content"), list):
            continue
        if msg.get("role") == "user":
            # Tool results: a Read that errored did not read its image (round 4).
            for part in msg["content"]:
                if isinstance(part, dict) and part.get("type") == "tool_result" and part.get("is_error"):
                    errored.add(part.get("tool_use_id"))
            continue
        if msg.get("role") != "assistant":
            continue
        for part in msg["content"]:
            if isinstance(part, dict) and part.get("type") == "tool_use":
                calls.append((part.get("name"), part.get("input") or {}, part.get("id")))

images = {f for f in os.listdir(rdir) if f.endswith((".jpg", ".png"))}
read, bad = set(), []
for name, inp, use_id in calls:
    fp = inp.get("file_path", "")
    real = os.path.realpath(fp) if fp else ""
    if name == "SubagentHandback":  # the harness's hand-back of the final reply, not a tool use
        continue
    if name == "Read" and real and os.path.dirname(real) == rdir:
        if use_id not in errored:
            read.add(os.path.basename(real))
    else:
        bad.append((name, fp or sorted(inp.keys())))
print(f"tool calls: {len(calls)}; Reads inside the reader dir: {sum(1 for n, i, u in calls if n == 'Read') - sum(1 for b in bad if b[0] == 'Read')}")
print(f"images in dir: {len(images)}; distinct images read: {len(read & images)}")
for b in bad:
    print("NON-COMPLIANT CALL:", b)
missing = sorted(images - read)
if missing:
    print("NOT READ:", ", ".join(missing))
if undecodable:
    print("UNDECODABLE TRANSCRIPT LINES:", undecodable)
print("AUDIT:", "PASS" if not bad and not missing and not undecodable else "FAIL")
