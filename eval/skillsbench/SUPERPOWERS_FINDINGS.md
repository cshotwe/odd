# SkillsBench — Superpowers (planning + subagent-driven-dev) vs no-skill

Date: 2026-06-20. Harness: benchflow `claude-agent-acp` (Claude Agent SDK),
model `databricks-claude-sonnet-4-6`, sandbox docker, native-ACP auth.
Conditions: **no-skill** (vanilla Claude Code) vs **superpowers** — the vendored
Superpowers skills library baked into the image with a SessionStart bootstrap
injecting the execution workflow **writing-plans → subagent-driven-development**
(the same arm wiring used in ProgramBench). Cost is computed from the native-ACP
token counts in `agent_result` (Sonnet 4.6 pricing: in $3, out $15, cache-read
$0.30, cache-write $3.75 per 1M), since the harness reports `total_cost_usd:
null` on the native path.

Raw data: `superpowers_results.csv`. Reproduce with `make_superpowers_task.sh`
+ `run_sp_batch.sh` (both in this directory).

## Headline (6 paired tasks: 4 easy + 2 medium)

| metric | no-skill | superpowers |
|---|---|---|
| avg reward (correctness) | **0.472** | 0.167 |
| win / loss / tie (SP vs no-skill) | — | **0 wins / 2 losses / 4 ties** |
| mean cost / task | $0.640 | **$0.829** |
| total cost | $3.84 | **$4.97** |

Superpowers was **worse on correctness and ~30% more expensive** (1.30×).

## Per-task

| task | difficulty | no-skill | superpowers | verdict |
|---|---|---|---|---|
| court-form-filling | easy | 0.0 · $0.78 | 0.0 · $0.75 (sp=6) | tie |
| dialogue-parser | easy | **0.833** · $0.45 | **0.0** · $0.31 (sp=7) | **SP loss** |
| offer-letter-generator | easy | 0.0 · $0.21 | 0.0 · $0.30 (sp=9) | tie (SP +$0.09) |
| powerlifting-coef-calc | easy | 1.0 · $0.37 | 1.0 · **$0.85** (sp=16) | tie (SP 2.3× cost) |
| adaptive-cruise-control | medium | **1.0** · $1.49 | **0.0** · $1.83 ¹ (sp=12) | **SP loss** (DNF) |
| azure-bgp-oscillation-route-leak | medium | 0.0 · $0.53 | 0.0 · **$0.94** (sp=10) | tie (SP +$0.41) |

`sp` = count of `writing-plans` / `subagent-driven-development` mentions in the
trajectory — confirms the workflow engaged in every superpowers run (it was not
guidance-only).

¹ **adaptive-cruise-control superpowers is a DNF (did-not-finish).** It timed out
on every attempt (45-min wall, a 30-min idle budget, then a 30-min hard wall with
the idle watchdog disabled), thrashing on PID-gain tuning across ~35 turns without
converging. The **$1.83 is measured, not estimated** — recovered from Claude
Code's own session transcript (`adaptive-cruise-control_superpowers_transcript.jsonl`,
summed by `acp_cost.py`). benchflow discards its in-memory token telemetry on a
killed run (`result.json` logs $0 or is absent), but Claude Code writes per-turn
`usage` to its session transcript *incrementally*, so the harness now copies that
file out of the sandbox before teardown — making cost durable even for a run that
never finishes cleanly.

## Findings

1. **Superpowers did not improve correctness on this set — it hurt it.** Avg
   reward dropped 0.472 → 0.167, with **0 wins, 2 losses, 4 ties**. Both losses
   are tasks vanilla *solved* (dialogue-parser 0.833, adaptive-cruise 1.0) that
   Superpowers then scored 0.0 on.

2. **The losses have two distinct mechanisms.** dialogue-parser: the planning
   workflow engaged (sp=7) but produced a worse answer than the direct attempt —
   over-planning an easy task. adaptive-cruise: the subagent-driven loop
   **never converged** — 100 tool calls of PID-gain thrashing across three runs,
   killed by the watchdog every time, where vanilla finished in one pass at 1.0.

3. **Cost: Superpowers is more expensive.** ~30% higher per task (1.30×: $0.83
   vs $0.64), and up to 2.3× on individual tasks (powerlifting $0.85 vs $0.37),
   because planning + per-task subagent dispatch + two-stage review multiplies
   turns and cached-token reads. (An earlier "looks cheaper" read was an artifact
   of the DNF logging $0; with the transcript-derived cost it is clearly higher.)

4. **Consistent with the TDAD thesis and the ProgramBench/SkillsBench pattern:**
   heavy process scaffolding on a capable model adds cost and can degrade
   quality. On a strong base model (Sonnet 4.6), a small validation framework +
   getting out of the way beats a prescriptive multi-step workflow.

## Caveats

- **n=6, single run per cell.** Directional, not significance-tested. A real
  claim needs N≥3/cell with within-condition variance (agent runs are stochastic
  — an earlier ODD SkillsBench replication saw single-run "wins" evaporate on
  repeat).
- Skewed easy (4) vs medium (2); no hard tasks yet.
- All six costs are **measured** — the one DNF (adaptive-cruise) is now recovered
  from the session transcript, not estimated (see footnote 1).
- The timeout is partly a harness-budget artifact (idle/wall caps), but it is
  *itself* a cost/quality signal: the workflow is more likely to blow the budget
  without converging.
