# Eval results

ODD has been measured on four benchmark suites — two we authored and two
published external benchmarks graded by their own harnesses. Results are
reported honestly, wins and net-zeros alike. The recurring caveat: a single
run of a stochastic agent is not evidence — treat any delta measured at fewer
than N≥3 runs/cell as directional.

---

## 1. SWE-bench Lite — real GitHub issues, official Docker grader

15 pinned `SWE-bench_Lite` instances, run headlessly from the raw issue (no
spec, hidden tests unseen), graded by the **official SWE-bench Docker harness**.
ODD vs Superpowers, with the published SWE-agent+Sonnet submission as a neutral
external yardstick.

| Condition | Resolved | Avg lines added | Avg files | Avg merge-risk ↓ |
|---|---|---|---|---|
| **ODD** | **12/15** | **12.6** | **2.13** | **0.47** |
| Superpowers | 9/15 | 63.8 | 3.4 | 1.47 |
| _published SWE-agent+Sonnet_ (reference) | 10/15 | — | — | — |

ODD resolves more instances **and** ships ~5× smaller diffs. Pass-rate is the
neutral external claim (official grader). Merge-risk thresholds (>2 files, >80
lines, etc.) echo ODD's own scope rules and were authored in this project, so
merge-risk is a **secondary diagnostic** — raw lines/files are shown so the
diffs can be judged directly.

- Model: `databricks-claude-sonnet-4-6`; swebench 4.1.0; Docker grader.
- The same autonomous-mode instruction is applied to both conditions, so
  neither is advantaged.

## 2. ProgramBench — reverse-engineer a binary, hidden behavioral tests

A single-variable replication of [@kunchenguid's experiment](https://x.com/kunchenguid/status/2064196344244531404),
which ran ProgramBench with and without Superpowers' TDD skill and found the
skill made pass-rate *worse* and ~50% pricier. Same benchmark, agent (Claude
Code), and model; the only thing varied is the injected methodology. Score =
mean fraction of hidden behavioral tests passing (partial credit).

| Condition | Score | Δ vs baseline | Cost | Δ cost |
|---|---|---|---|---|
| baseline | 30.4% | — | $5.94 | — |
| TDD (skill only) | 40.7% | +10.3 pts | $8.99 | +51% |
| **ODD (full toolkit)** | **56.2%** | **+25.8 pts** | $8.25 | +39% |

ODD is the highest-quality arm and **reverses the X-post's "skills hurt"
finding** — but it buys quality with *more* tokens, not fewer. The "cheaper AND
better" dual win is structurally unreachable here: ProgramBench tasks are
reverse-engineering, irreducibly coupled even across "separate" files, so a
capable agent correctly refuses to decompose and cheap-model delegation can't
lift quality above a strong baseline. Small-n pilot — directional, not
significance-tested.

## 3. Custom A/B harness — outcome + merge-readiness

Our own paired harness measuring the two axes [METR](https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/)
showed matter: did the artifact do what was asked (held-out, end-to-end
ground-truth checks), and would a maintainer take the diff (merge-risk proxies).

| Metric | ODD | Superpowers |
|---|---|---|
| Outcome correctness | **62.5%** (5/8) | 25% (2/8) |
| Merge-readiness (GEval) | **81.2%** | 53.7% |
| Zero red flags | **5/8** (62%) | 2/8 (25%) |
| Lines added | **−45%** | baseline |
| Unrequested files | **0** | multiple |
| Defensive code | **0** | common |

A maintainer-lens read of the diffs (applying METR's rejection taxonomy)
separates them where the mechanical score ties: the baseline arm repeatedly
added narration comments, unrequested error paths, and style-mismatched edits;
ODD's diffs were the minimal change matching surrounding style.

## 4. SkillsBench — net-zero, and the failure mode we found

21 paired tasks on [SkillsBench](https://github.com/benchflow-ai/skillsbench)
(benchflow `claude-agent-acp`, Sonnet 4.6), ODD baked in vs vanilla.

| | value |
|---|---|
| ODD wins | 2 |
| ODD losses | 2 |
| ties | 17 |
| **net reward delta** | **≈ 0** |

**No aggregate quality effect** — and a replication run showed the two "wins"
were run-to-run variance, not signal (e.g. `econ-detrending`: the original
noskill 0.0 was an outlier; on 3×3 replication both conditions were 1.0). The
valuable result here was diagnostic: both losses share one **reproducible
failure mode**. When acceptance criteria are *latent* (numeric thresholds,
dispatch values) rather than *given* (a binary, golden file, endpoint), the
agent authors checks against its *own* oracle — even building a private test
harness — which agree with its code by construction. `odd prove` then certifies
a wrong mental model and the hidden grader scores 0.

**The fix this drove (now in the skill):** `odd` refuses to certify "proven"
without a passing **end-to-end** (`--kind e2e`) check that runs the real
artifact the way the grader does. All-green self/unit checks report as
`unverified`, not `proven`. The full trace review and the broader system-design
recommendations it produced are the basis for ODD's check-kind typing.

---

## Honest takeaway

ODD's first-order value is **outcome quality and diff discipline** — clear on
SWE-bench Lite (more resolved, ~5× smaller diffs) and ProgramBench (top quality
arm, reversing the "skills hurt" result), and on the merge-readiness axis of the
custom A/B. It is **not** a universal win on every harness: SkillsBench was
net-zero, and its sharpest signal was a failure mode that made the toolkit
better. ODD also costs wall-clock — the prove/review loop adds iterations, so it
can time out on the heaviest tasks where vanilla finishes. Single-run agent A/B
is noisy; any future delta needs N≥3/cell and a within-condition variance
estimate before it's called real.
