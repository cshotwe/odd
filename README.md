```
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║                          _      _                                  ║
║                         | |    | |                                 ║
║                 ___   __| |  __| |                                 ║
║                / _ \ / _` | / _` |                                 ║
║               | (_) | (_| || (_| |                                 ║
║                \___/ \__,_| \__,_|                                 ║
║                                                                    ║
║                  Outcome-Driven Development                        ║
║                                                                    ║
║    Prove the artifact. Review the diff. Merge with confidence.     ║
╚════════════════════════════════════════════════════════════════════╝
```

# odd — Outcome-Driven Development

Replace TDD ritual with proof: **declare the outcome before building, run
checks against the REAL artifact, review the diff like a maintainer.** A skill
+ a small CLI for coding agents (Claude Code), with a Stop hook that won't let
the agent finish until the outcome is actually proven.

## Why

Two findings motivate ODD ([full grounding](docs/research.md)):

- **Passing tests ≠ mergeable code.** [METR](https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/)
  had maintainers review 296 AI PRs that *passed* SWE-bench's grader — only
  ~48–50% would actually merge. The dominant rejection reasons were code
  quality, scope creep, and collateral breakage; "doesn't solve the issue" was
  the *rarest*. Optimizing for "tests pass" optimizes the wrong objective.
- **Long process prompts make agents worse.** [TDAD (2026)](https://arxiv.org/abs/2603.17973)
  found that adding TDD *procedural instructions* to an agent's prompt raised
  regressions to **9.94% — worse than no intervention (6.08%)**: ritual prompts
  crowd out the repo context the model needs. What helped (−70%) was *targeted
  context*, not the ritual. So a methodology you hand an agent must be **short**.

ODD's response: the skill is a ~40-line four-step loop (enforcement lives
out-of-band in a CLI + Stop hook, costing zero prompt tokens during the build),
and "done" requires *fresh evidence from running the real artifact*, not
self-written unit tests that encode the same misunderstanding as the code.

## The loop

The agent drives this autonomously once the skill is installed:

1. **Intent** — write the outcome as the user would observe it, plus 2–5
   acceptance checks that exercise the real artifact. At least one must be
   `--kind e2e` (runs the real thing end-to-end).
2. **Build** — the smallest change that achieves the outcome.
3. **Prove** — `odd prove` runs every check against the real artifact and
   records verbatim evidence. The Stop hook blocks finishing until a passing
   e2e check exists — self-authored/unit checks alone report `unverified`, not
   `proven`.
4. **Review** — `odd review` audits the diff like the maintainer who must
   merge it (scope creep, defensive code, comment bloat).

## Install

**As a Claude Code plugin** (recommended — registers the skill + hooks globally):

```
/plugin marketplace add cshotwe/odd
/plugin install odd@odd
```

**Or into a single project** (copies the skill into `.claude/` and wires the
Stop hook in that project's `settings.json`):

```bash
./install.sh /path/to/your/project
echo ".odd/" >> /path/to/your/project/.gitignore
```

That's it. The skill is auto-discovered by Claude Code and the agent runs the
loop on its own. **You don't run the `odd` CLI yourself.**

## What you control: domain-specific acceptance tests

The `odd` CLI is the agent's tool. Your job is to define *what "working" means*
for your domain, as black-box checks against the real artifact. Drop **outcome
specs** into `outcomes/` — the agent reads them before working, must keep them
green, and `odd ci` re-runs them as a regression suite.

An outcome spec is one JSON file. For example `outcomes/billing-export.outcome.json`:

```json
{
  "outcome": "running `./export --month 2026-05` writes a CSV with one row per paid invoice",
  "type": "software",
  "checks": [
    { "desc": "exports May's paid invoices",
      "cmd": "./export --month 2026-05 && wc -l < out.csv", "expect": "42" },
    { "desc": "skips unpaid invoices",
      "cmd": "./export --month 2026-05 && grep -c unpaid out.csv", "expect": "0" },
    { "desc": "rejects a malformed month",
      "cmd": "./export --month nonsense", "expect_fail": true }
  ]
}
```

Each check is the kind of end-to-end test only the domain owner knows to
demand — pin exact values, run the actual CLI/endpoint, assert error paths.
These become a contract the agent can't fudge: a self-authored check that
agrees with its own code can't certify "proven", and every spec is re-run on
every future change.

```bash
odd ci                       # re-run every outcome spec (your regression suite)
odd ci --junit report.xml    # same, as JUnit XML for CI
```

`outcome-types/*.yaml` define the validator vocabulary per domain (`software`,
`api`, `data_analytics`).

## CLI reference (run by the agent, not you)

| Command | Purpose |
|---|---|
| `odd init` | Start an outcome contract |
| `odd check` | Add an acceptance check (`--kind e2e` runs the real artifact) |
| `odd prove` | Run all checks, record evidence fingerprinted to the tree |
| `odd review` | Maintainer-lens diff audit |
| `odd done` | Exit 0 iff the outcome is proven (a passing e2e check exists) |
| `odd status` | Show contract and evidence state |
| `odd archive` | Promote a proven contract to a durable `outcomes/*.outcome.json` spec |
| `odd ci` | Re-run archived outcome specs as a regression suite (`--junit` XML) |
| `odd reset` | Clear all state |

Helper tools: `odd-lint` (scope-creep warnings), `odd-template` (pattern
expansion), `odd-analyze`, `odd-compose`, `odd-check-scope`,
`odd-validate-outcome`, `odd-interference`, `odd-add-regressions`.

Working state lives in `.odd/` (`outcome.json` + tree-fingerprinted
`evidence.json`); durable specs live in committed `outcomes/`.

No dependencies beyond the Python 3.8+ standard library.

## Results

Measured on four benchmark suites — two we authored, two published external
benchmarks graded by their own harnesses ([full results](docs/results.md)).
Each cell is the suite's pass metric, with cost where the harness tracked it:

| Benchmark (pass metric) | Baseline | Superpowers | ODD | How ODD did |
|---|---|---|---|---|
| **SWE-bench Lite** (resolved /15) | 10/15 ¹ | 9/15 | **12/15** | ✅ most resolved, **~5× smaller diffs** (13 vs 64 lines avg) |
| **ProgramBench** (hidden-test score · cost) | 30.4% · $5.94 | 40.7% · $8.99 ² | **56.2% · $8.25** | ✅ top quality, **+25.8 pts**; reverses "skills hurt" |
| **Custom A/B** (outcome pass /8) | — | 25% (2/8) | **62.5% (5/8)** | ✅ **+37.5 pts**, 81% merge-ready vs 54% |
| **SkillsBench** (21 paired tasks) | tie | — | tie | ➖ **net-zero**; surfaced the self-oracle failure mode that drove the `--kind e2e` gate |

¹ SWE-bench has no "baseline" condition we ran; the figure is the published
SWE-agent+Sonnet submission on the same pinned instances — a neutral external
yardstick. ² ProgramBench's "Superpowers" arm is its TDD skill (skill-only, as
the [original experiment](https://x.com/kunchenguid/status/2064196344244531404)
injected it). Cost was tracked only on ProgramBench; `—` = condition not run.

## License

MIT — see [LICENSE](LICENSE).
