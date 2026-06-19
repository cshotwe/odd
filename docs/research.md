# Research grounding

Why Outcome-Driven Development (ODD) deviates from TDD and heavyweight
spec-driven development for coding agents.

## 1. Passing tests ≠ mergeable code (METR, March 2026)

[Many SWE-bench-Passing PRs Would Not Be Merged into Main](https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/)

METR had 4 active maintainers from 3 SWE-bench Verified repositories
(scikit-learn, Sphinx, pytest) review 296 AI-generated PRs that **passed**
SWE-bench's automated grader.

Key findings:

- Only **~48–50%** of test-passing AI PRs would actually be merged.
  Average merge rate was **24.2 percentage points lower** than the
  automated benchmark score suggested (~72% grader pass vs ~48% merge).
- **Core functionality failure was the rarest rejection reason.** The
  dominant reasons, in METR's least→most-serious ordering:
  1. **Code quality** — bad style, not following repo standards (most common)
  2. **Other failures** — undocumented issues
  3. **Breaks other code** — solves the issue but regresses something else
  4. **Core functionality failure** — doesn't solve the issue (rare)
- Even human-written reference patches: 100% passed the automated tests,
  but strict reviewers approved only 68% — automated test pass is a weak
  proxy for "this is the change the project wanted."

**Implication for agent tooling:** optimizing for "tests pass" optimizes
the wrong objective. The lever is (a) validating the *user-observable
outcome* against the *real artifact*, and (b) reviewing the diff with a
maintainer's eye (style fit, scope, collateral damage) before declaring done.

## 2. TDD process prompting makes agents worse (TDAD, 2026)

[TDAD: Test-Driven Agentic Development — Reducing Code Regressions in AI
Coding Agents via Graph-Based Impact Analysis](https://arxiv.org/abs/2603.17973)

- Adding **TDD procedural instructions** to an agent's prompt *without*
  targeted context **increased regressions to 9.94% — worse than no
  intervention at all** (vanilla baseline: 6.08%).
- Root cause: process-ritual prompts consume context tokens and crowd out
  the repository context the model needs to make accurate changes. The
  effect is worse on smaller models.
- What actually reduced regressions (−70%, 6.08% → 1.82%) was *targeted,
  relevant context* (impact analysis), not the TDD ritual.
- Related: Cui (2025) found TDD-style agent performance degrades as
  instructions get long — instruction-following burden, not coding skill,
  is the bottleneck ("TDD prompting paradox").

**Implication for agent tooling:** any skill/process you hand an agent
must be *short*. ODD's skill is a four-step loop that fits in ~40 lines;
enforcement lives in hooks and a CLI (out-of-band), not in prompt bulk.

## 3. The validation gap

Agents today routinely "validate" by writing fresh unit tests for the code
they just wrote. These tests are written by the same model holding the
same misunderstanding of the task — so they encode the misunderstanding
and pass. They verify *the code does what the agent thinks it should do*,
not *what the user asked for*.

ODD replaces this with **acceptance checks**: executable commands that
exercise the real artifact the way the user would (run the CLI, hit the
endpoint, render the page, reproduce the reported bug) with expected
observable results written down *before* building. Evidence of running
them is captured verbatim and gates completion.

## Design principles derived

| Research finding | ODD design response |
|---|---|
| Code-quality/style is the #1 merge blocker (METR) | `odd review`: mechanical maintainer-lens diff audit (comment bloat, defensive code, scope creep, style mismatch) |
| "Breaks other code" is #2 (METR) | Review step flags files touched beyond task scope; checks run against the real artifact, not isolated units |
| Test-pass is a weak completion signal (METR) | Stop-gate requires *fresh evidence from executing the artifact*, keyed to the current diff |
| Long process prompts degrade performance (TDAD) | Skill is ~40 lines; enforcement is out-of-band (hook + CLI), costing zero prompt tokens during the build phase |
| Self-written unit tests are self-fulfilling | Acceptance checks are declared from *user intent* before building, and must invoke the artifact end-to-end |
