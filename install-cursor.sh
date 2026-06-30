#!/usr/bin/env bash
# Install ODD into a target project for Cursor (skills + hooks).
# Usage: ./install-cursor.sh /path/to/your/project
set -euo pipefail

TARGET="${1:?usage: ./install-cursor.sh /path/to/project}"
SRC="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$TARGET/.cursor/skills"
rm -rf "$TARGET/.cursor/skills/odd" "$TARGET/.cursor/skills/odd-plan"
cp -r "$SRC/skills/odd" "$TARGET/.cursor/skills/odd"
cp -r "$SRC/skills/odd-plan" "$TARGET/.cursor/skills/odd-plan"
chmod +x "$TARGET/.cursor/skills/odd/bin/"* 2>/dev/null || true

HOOKS="$TARGET/.cursor/hooks.json"
python3 - "$HOOKS" <<'PY'
import json, os, sys

path = sys.argv[1]
hooks = {
    "version": 1,
    "hooks": {
        "sessionStart": [
            {
                "command": "bash .cursor/skills/odd/hooks/session-start",
                "timeout": 10,
            }
        ],
        "stop": [
            {
                "command": "python3 .cursor/skills/odd/hooks/outcome_gate.py",
                "loop_limit": 5,
            }
        ],
    },
}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(hooks, f, indent=2)
    f.write("\n")
print(f"hooks registered in {path}")
PY

GITIGNORE="$TARGET/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -qxF '.odd/' "$GITIGNORE" 2>/dev/null; then
    printf '\n.odd/\n' >> "$GITIGNORE"
    echo "added .odd/ to $GITIGNORE"
  fi
else
  printf '.odd/\n' > "$GITIGNORE"
  echo "created $GITIGNORE with .odd/"
fi

cat <<EOF

ODD installed for Cursor in $TARGET/.cursor/
  - skill:     .cursor/skills/odd/SKILL.md
  - plan:      .cursor/skills/odd-plan/SKILL.md
  - cli:       .cursor/skills/odd/bin/odd
  - hooks:     .cursor/hooks.json (sessionStart + stop gate)
  - stop gate: .cursor/skills/odd/hooks/outcome_gate.py

Add .cursor/skills/odd/bin to PATH for the session, or invoke as
.cursor/skills/odd/bin/odd.

Desktop Cursor enforces the stop gate when .odd/outcome.json exists.
Cloud Agents do not run stop hooks yet — agents must run odd prove && odd done.
EOF
