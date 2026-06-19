#!/usr/bin/env python3
"""Stop hook: block the agent from finishing until the outcome is proven.

Reads the Claude Code Stop-hook JSON from stdin. If an outcome contract
exists (.odd/outcome.json) but the evidence is missing, stale (code changed
since checks last ran), incomplete, or failing, exits with code 2 — which
blocks the stop and feeds the reason back to the agent.

Fail-open by design:
- No .odd contract in this repo -> allow stop (ODD wasn't engaged for this task).
- stop_hook_active is true (we already blocked once this turn-chain) -> allow
  stop, so a wedged check can never trap the agent in a loop.
- Any unexpected error -> allow stop.

Register in .claude/settings.json:
  {"hooks": {"Stop": [{"hooks": [{"type": "command",
    "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/odd/hooks/outcome_gate.py"}]}]}}
"""

import json
import os
import subprocess
import sys


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if payload.get("stop_hook_active"):
        sys.exit(0)

    cwd = payload.get("cwd") or os.getcwd()
    try:
        root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, cwd=cwd,
        ).stdout.strip() or cwd
    except Exception:
        root = cwd

    if not os.path.exists(os.path.join(root, ".odd", "outcome.json")):
        sys.exit(0)

    odd = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "odd")
    try:
        r = subprocess.run(
            [sys.executable, odd, "done"],
            capture_output=True, text=True, cwd=root, timeout=30,
        )
    except Exception:
        sys.exit(0)

    if r.returncode == 0:
        sys.exit(0)

    detail = (r.stdout + r.stderr).strip()
    print(
        "Outcome not yet proven — do not stop.\n"
        f"{detail}\n"
        "Run `odd prove` to execute the acceptance checks against the real "
        "artifact. If a check fails, fix the code (not the check) unless the "
        "check itself was wrong. Then `odd review` the diff before finishing.",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
