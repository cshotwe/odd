# SkillsBench — methodology A/B (Superpowers vs no-skill)

Does a heavy agent methodology help on [SkillsBench](https://github.com/benchflow-ai/skillsbench)?
This harness runs each task under two conditions and captures **both
correctness (reward) and cost**:

- **no-skill** — vanilla Claude Code (the SkillsBench default)
- **superpowers** — the Superpowers skills library baked into the task image,
  with a SessionStart bootstrap that injects the execution workflow
  **writing-plans → subagent-driven-development** (same arm wiring as the
  ProgramBench eval in `eval/programbench/`)

Results: **[SUPERPOWERS_FINDINGS.md](SUPERPOWERS_FINDINGS.md)** ·
raw rows: [superpowers_results.csv](superpowers_results.csv)

## What's here

| file | purpose |
|---|---|
| `make_superpowers_task.sh` | Materialize `tasks_sp/<task>/` = a task with Superpowers baked into the image at `/root/.claude/` (skills + SessionStart hook). Mirrors `make_odd_task.sh`. |
| `run_sp_batch.sh` | Run a batch over both conditions; capture reward + cost per run into `/tmp/sp_results.csv`. Copies Claude Code's session transcript out of the sandbox before teardown so cost survives a timeout. |
| `acp_cost.py` | Sum true token usage + cost from a Claude Code session transcript (`--csv` for the batch runner). Durable: works on killed/timed-out runs. |
| `SUPERPOWERS_FINDINGS.md` | Write-up of the run (6 paired tasks). |
| `superpowers_results.csv` | Raw per-run data (reward, cost, tokens, workflow-call count, status). |
| `adaptive-cruise-control_superpowers_transcript.jsonl` | Captured session transcript for the one DNF run — its $1.83 cost was recovered from this. |

## Prerequisites

- SkillsBench cloned (default `~/skillsbench`) with the `bench`/`benchflow` CLI
  (`uv tool install "benchflow>=0.6.2,<0.7"`), and Docker.
- A Superpowers checkout/plugin (external dependency — not vendored here),
  with `skills/` + `hooks/`. Defaults to the installed plugin cache
  (`~/.claude/plugins/cache/claude-plugins-official/superpowers/<ver>`); override
  with `SUPERPOWERS_VENDOR=...`.
- Anthropic creds exported as `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` /
  `ANTHROPIC_MODEL`. Passing `ANTHROPIC_AUTH_TOKEN` takes benchflow's native-ACP
  path (Claude Code talks to the endpoint directly with Bearer auth); on that
  path the harness reports `total_cost_usd: null`, so the scripts **compute cost
  from the token counts** in `agent_result` using Sonnet 4.6 pricing
  (in $3 / out $15 / cache-read $0.30 / cache-write $3.75 per 1M).
- `/tmp/task_order.txt` (one task name per line, the run order) and
  `/tmp/task_diff.txt` (`difficulty|task` lines). The runner indexes into these.

## Run

```bash
# Copy the scripts next to the SkillsBench tasks/ dir, then:
cd ~/skillsbench
ANTHROPIC_BASE_URL=… ANTHROPIC_AUTH_TOKEN=… ANTHROPIC_MODEL=… \
  ./run_sp_batch.sh 1 6      # tasks 1..6 from /tmp/task_order.txt, both conditions
```

Each row in `/tmp/sp_results.csv`:
`task,difficulty,condition,reward,cost_usd,in_tok,out_tok,cacheR_tok,cacheW_tok,sp_skill_calls,status,jobdir`.

## Caveats

Single run per cell, n=6 — directional, not significance-tested. Agent runs are
stochastic; a real claim needs N≥3/cell with within-condition variance (an
earlier ODD SkillsBench replication saw single-run "wins" evaporate on repeat).
One run (`adaptive-cruise-control` superpowers) is a
DNF/timeout whose cost ($1.83) is **measured** — recovered from Claude Code's
session transcript (`acp_cost.py`), since benchflow discards its own token
telemetry on a killed run while Claude Code writes `usage` per-turn. `run_sp_batch.sh`
copies that transcript out before teardown, so cost is durable even when a run
never finishes cleanly.
