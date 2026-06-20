#!/usr/bin/env bash
# Materialize a Superpowers-instrumented copy of a SkillsBench task.
#   make_superpowers_task.sh <task_name>
# Creates tasks_sp/<task_name>/ = the task + the vendored Superpowers skills
# library baked into the image at /root/.claude/ with the using-superpowers
# SessionStart bootstrap. benchflow's setup_sandbox_user copies /root/.claude
# -> the agent's home, so the agent boots with Superpowers installed AND the
# bootstrap injecting using-superpowers (which drives writing-plans ->
# subagent-driven-development). Mirrors the ProgramBench superpowers arm.
set -euo pipefail
cd ~/skillsbench
TASK="${1:?task name}"
# Superpowers is an external dependency (not vendored in this repo). Point
# SUPERPOWERS_VENDOR at a Superpowers checkout/plugin that has skills/ + hooks/.
# Default = the installed Claude Code plugin cache.
SP_VENDOR="${SUPERPOWERS_VENDOR:-$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3}"
SRC="tasks/$TASK"
DST="tasks_sp/$TASK"
[ -d "$SRC" ] || { echo "no such task: $SRC" >&2; exit 1; }
[ -d "$SP_VENDOR/skills" ] || { echo "no Superpowers skills at $SP_VENDOR (set SUPERPOWERS_VENDOR)" >&2; exit 1; }

rm -rf "$DST"; mkdir -p "$DST"
cp -r "$SRC/." "$DST/"

# Stage Superpowers into the build context (environment/_sp/.claude/...).
CTX="$DST/environment/_sp/.claude"
mkdir -p "$CTX/skills" "$CTX/hooks"
cp -r "$SP_VENDOR/skills/." "$CTX/skills/"
chmod +x "$CTX/hooks" 2>/dev/null || true

# Custom SessionStart hook: inject using-superpowers (the standard bootstrap)
# PLUS a preamble naming the exact execution workflow — writing-plans ->
# subagent-driven-development — so it engages even where skills don't auto-fire.
# This mirrors the ProgramBench superpowers arm's methodology preamble verbatim.
cat > "$CTX/hooks/session-start" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
using_sp="$(cat "${ROOT}/skills/using-superpowers/SKILL.md" 2>/dev/null || echo 'Error reading using-superpowers')"
preamble="## Required methodology: Superpowers (execution workflow)

Superpowers skills are installed in .claude/skills/ and the using-superpowers bootstrap is active. Follow the Superpowers software-development workflow, with one deliberate exception:

- DO NOT brainstorm or ask for requirements. The task description IS your spec — treat it as the agreed outcome and proceed.
- Use the writing-plans skill to turn the spec into a concrete, step-by-step implementation plan.
- Then execute the plan with the subagent-driven-development skill: dispatch a fresh subagent per task and run its two-stage review (spec compliance, then code quality) after each.
- Verify the build end-to-end before declaring done.

Invoke these skills via the Skill tool; do not merely read them."
escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"; printf '%s' "$s"; }
ctx="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n$(escape "$preamble")\n\n**Your 'using-superpowers' skill:**\n\n$(escape "$using_sp")\n</EXTREMELY_IMPORTANT>"
printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  },\n  "additionalContext": "%s"\n}\n' "$ctx" "$ctx"
exit 0
HOOK
chmod +x "$CTX/hooks/session-start" 2>/dev/null || true

# SessionStart bootstrap: the vendored hook derives PLUGIN_ROOT as SCRIPT_DIR/..
# = $HOME/.claude, and reads $HOME/.claude/skills/using-superpowers/SKILL.md.
cat > "$CTX/settings.json" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|clear|compact",
        "hooks": [ { "type": "command",
          "command": "bash \"$HOME/.claude/hooks/session-start\"" } ] }
    ]
  }
}
JSON

# Append install steps: copy the toolkit to /root/.claude in the image.
cat >> "$DST/environment/Dockerfile" <<'DOCKER'

# --- Superpowers toolkit (baked in for the superpowers condition) ---
COPY _sp/.claude /root/.claude
RUN chmod +x /root/.claude/hooks/session-start 2>/dev/null || true
DOCKER

echo "built $DST (Superpowers baked in)"
