#!/usr/bin/env python3
"""Stop hook: block the agent from finishing until the outcome is proven.

Reads Stop-hook JSON from stdin (Claude Code and Cursor). If an outcome
contract exists (.odd/outcome.json) but the evidence is missing, stale (code
changed since checks last ran), incomplete, or failing, exits with code 2 —
which blocks the stop and feeds the reason back to the agent.

Fail-open by design:
- No .odd contract in this repo -> allow stop (ODD wasn't engaged for this task).
- stop_hook_active is true (Claude: already blocked once this turn-chain) -> allow
  stop, so a wedged check can never trap the agent in a loop.
- loop_count >= loop_limit (Cursor stop hook) -> allow stop for the same reason.
- Any unexpected error -> allow stop.

Register in Claude Code .claude/settings.json:
  {"hooks": {"Stop": [{"hooks": [{"type": "command",
    "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/odd/hooks/outcome_gate.py"}]}]}}

Register in Cursor .cursor/hooks.json:
  {"version": 1, "hooks": {"stop": [{"command": "python3 skills/odd/hooks/outcome_gate.py"}]}}
"""

import json
import os
import subprocess
import sys

_DEFAULT_LOOP_LIMIT = 5


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    if payload.get("stop_hook_active"):
        sys.exit(0)

    loop_count = payload.get("loop_count", 0)
    loop_limit = payload.get("loop_limit", _DEFAULT_LOOP_LIMIT)
    if loop_limit is not None and loop_count >= loop_limit:
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
    message = (
        "Outcome not yet proven — do not stop.\n"
        f"{detail}\n"
        "Run `odd prove` to execute the acceptance checks against the real "
        "artifact. If a check fails, fix the code (not the check) unless the "
        "check itself was wrong. Then `odd review` the diff before finishing."
    )
    print(message, file=sys.stderr)

    # Cursor can also read followup_message from stdout JSON on stop hooks.
    print(json.dumps({"followup_message": message}))
    sys.exit(2)


if __name__ == "__main__":
    main()
