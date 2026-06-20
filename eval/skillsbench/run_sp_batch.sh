#!/usr/bin/env bash
# Run a batch of SkillsBench tasks under two conditions:
#   noskill      = vanilla Claude Code on tasks/<task>
#   superpowers  = Superpowers baked into the image (tasks_sp/<task>, built by
#                  make_superpowers_task.sh): writing-plans -> subagent-driven-dev.
# Captures BOTH correctness (reward) and cost (computed from native-ACP token
# counts in agent_result, since total_cost_usd is null on the native path).
# Usage: run_sp_batch.sh <start_idx> <count>   (1-based into /tmp/task_order.txt)
# Appends one CSV row per (task,condition) to /tmp/sp_results.csv.
set -uo pipefail
cd ~/skillsbench

START="${1:?start idx}"; COUNT="${2:?count}"
STAMP="$(date +%m%d_%H%M%S)"
RESULTS="/tmp/sp_results.csv"
ORDER="/tmp/task_order.txt"
DIFF="/tmp/task_diff.txt"
[ -f "$RESULTS" ] || echo "task,difficulty,condition,reward,cost_usd,in_tok,out_tok,cacheR_tok,cacheW_tok,sp_skill_calls,status,jobdir" > "$RESULTS"

mapfile -t ALL < "$ORDER"
TASKS=("${ALL[@]:$((START-1)):$COUNT}")

# Sonnet 4.6 pricing per 1M tokens: in 3, out 15, cache_read 0.30, cache_write 3.75
costf() { uv run --no-project python -c "import json
try:
 d=json.load(open('$1')); ar=d.get('agent_result') or {}
 ti=ar.get('n_input_tokens') or 0; to=ar.get('n_output_tokens') or 0
 cr=ar.get('n_cache_read_tokens') or 0; cw=ar.get('n_cache_creation_tokens') or 0
 c=ti/1e6*3 + to/1e6*15 + cr/1e6*0.30 + cw/1e6*3.75
 print(f'{c:.4f},{ti},{to},{cr},{cw}')
except Exception: print('NA,NA,NA,NA,NA')" 2>/dev/null || echo "NA,NA,NA,NA,NA"; }

pf() { uv run --no-project python -c "import json
try:
 d=json.load(open('$1')); print($2)
except Exception: print('NA')" 2>/dev/null || echo NA; }

difficulty_of() { awk -F'|' -v t="$1" '$2==t{print $1}' "$DIFF" | head -1; }

run_one() {
  local task="$1" cond="$2" tasks_dir="$3" diff="$4"
  local jd="jobs/sp_${cond}_${task}_${STAMP}"
  timeout 2700 uv run bench eval create \
    --tasks-dir "$tasks_dir" --agent claude-agent-acp --model "$ANTHROPIC_MODEL" \
    --skill-mode no-skill --sandbox docker --jobs-dir "$jd" \
    --agent-idle-timeout 1200 \
    --agent-env ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
    --agent-env ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
    --agent-env ANTHROPIC_MODEL="$ANTHROPIC_MODEL" \
    --agent-env 'ANTHROPIC_CUSTOM_HEADERS=x-databricks-use-coding-agent-mode: true' \
    > "/tmp/sp_${cond}_${task}.log" 2>&1
  # Durable cost capture: copy Claude Code's own session transcript OUT of the
  # sandbox before the container is reaped. Claude writes per-turn `usage`
  # incrementally, so this survives a timeout/kill — unlike benchflow's
  # end-of-session flush, which logs $0 on any killed run.
  local cont ts_local="$jd/claude_transcript.jsonl"
  cont=$(docker ps -q --filter "name=${task}__" | head -1)
  if [ -n "$cont" ]; then
    local ts_in
    ts_in=$(docker exec "$cont" bash -lc 'find /home/agent/.claude/projects -name "*.jsonl" 2>/dev/null | head -1' 2>/dev/null | tr -d '\r')
    [ -n "$ts_in" ] && docker cp "$cont:$ts_in" "$ts_local" >/dev/null 2>&1 || true
  fi
  docker ps -q --filter "name=${task}__" | xargs -r docker rm -f >/dev/null 2>&1 || true
  local rj reward status traj sp cost_fields
  rj=$(find "$jd" -name result.json | head -1)
  if [ -n "$rj" ]; then
    reward=$(pf "$rj" "d.get('rewards',{}).get('reward','NA')")
    status=$(pf "$rj" "(d.get('error_category') or ('done' if d.get('error') is None else 'error'))")
    cost_fields=$(costf "$rj")
  else
    reward=0.0; status=no_result; cost_fields="NA,NA,NA,NA,NA"
  fi
  # Prefer the transcript-derived cost (works even when result.json logs 0).
  if [ -f "$ts_local" ] && [ "$(echo "$cost_fields" | cut -d, -f1)" = "0.0000" -o "$(echo "$cost_fields" | cut -d, -f1)" = "NA" ]; then
    local tc
    tc=$(uv run --no-project python3 acp_cost.py "$ts_local" --csv 2>/dev/null)
    [ -n "$tc" ] && cost_fields="$tc"
  fi
  traj=$(find "$jd" -name acp_trajectory.jsonl | head -1)
  sp=0
  [ -n "$traj" ] && sp=$(grep -oiE 'writing-plans|subagent-driven-development' "$traj" 2>/dev/null | wc -l | tr -d ' \n')
  : "${sp:=0}"
  echo "$task,$diff,$cond,$reward,$cost_fields,$sp,$status,$jd" >> "$RESULTS"
  echo "[$cond] $task ($diff) -> reward=$reward cost=\$$(echo $cost_fields | cut -d, -f1) sp_calls=$sp status=$status"
}

for t in "${TASKS[@]}"; do
  [ -z "$t" ] && continue
  d=$(difficulty_of "$t"); [ -z "$d" ] && d="?"
  run_one "$t" "noskill" "tasks/$t" "$d"
  ./make_superpowers_task.sh "$t" >/dev/null 2>&1 && run_one "$t" "superpowers" "tasks_sp/$t" "$d" \
    || echo "[superpowers] $t -> SKIP (make_superpowers_task failed)"
  # Reclaim disk between tasks.
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null \
    | grep -iE "${t}__" | awk '{print $2}' | sort -u | xargs -r docker rmi -f >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
  rm -rf "tasks_sp/$t" 2>/dev/null || true
  df -h / | awk 'NR==2{print "  [disk] "$4" free ("$5" used)"}'
done
echo "BATCH DONE: ${TASKS[*]}"
