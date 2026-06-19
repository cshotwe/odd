#!/usr/bin/env bash
# Install ODD into a target project's .claude/ directory.
# Usage: ./install.sh /path/to/your/project
set -euo pipefail

TARGET="${1:?usage: ./install.sh /path/to/project}"
SRC="$(cd "$(dirname "$0")" && pwd)"

# ODD is a self-contained skill: copy the whole skills/odd/ tree (SKILL.md +
# bin/ + hooks/ + outcome-types/) as one unit.
mkdir -p "$TARGET/.claude/skills"
rm -rf "$TARGET/.claude/skills/odd"
cp -r "$SRC/skills/odd" "$TARGET/.claude/skills/odd"
chmod +x "$TARGET/.claude/skills/odd/bin/"* 2>/dev/null || true

SETTINGS="$TARGET/.claude/settings.json"
STOP_CMD='python3 "$CLAUDE_PROJECT_DIR"/.claude/skills/odd/hooks/outcome_gate.py'

python3 - "$SETTINGS" "$STOP_CMD" <<'PY'
import json, sys, os
path, stop_cmd = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)
hooks = settings.setdefault("hooks", {})

# Stop hook: gate completion on a proven outcome.
stop = hooks.setdefault("Stop", [])
if not any(stop_cmd == h.get("command")
           for entry in stop for h in entry.get("hooks", [])):
    stop.append({"hooks": [{"type": "command", "command": stop_cmd}]})

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
print(f"Stop hook registered in {path}")
PY

cat <<EOF

ODD installed into $TARGET/.claude/
  - skill:     .claude/skills/odd/SKILL.md            (auto-discovered by Claude Code)
  - cli:       .claude/skills/odd/bin/odd
  - stop gate: .claude/skills/odd/hooks/outcome_gate.py (registered in settings.json)

Add .claude/skills/odd/bin to PATH for the session, or invoke as
.claude/skills/odd/bin/odd. Add '.odd/' to the project's .gitignore.
EOF
