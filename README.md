```
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║                             _      _                              ║
║                            | |    | |                             ║
║                    ___   __| |  __| |                             ║
║                   / _ \ / _` | / _` |                             ║
║                  | (_) | (_| || (_| |                             ║
║                   \___/ \__,_| \__,_|                             ║
║                                                                    ║
║                  Outcome-Driven Development                       ║
║                                                                    ║
║       Prove the artifact. Review the diff. Merge with confidence. ║
╚════════════════════════════════════════════════════════════════════╝
```

# odd — Outcome-Driven Development

Replace TDD ritual with proof: **declare the outcome before building, run
checks against the REAL artifact, review the diff like a maintainer.** A skill
+ a small CLI for coding agents (Claude Code), with a Stop hook that won't let
the agent finish until the outcome is actually proven.

Why? [METR found](https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/)
only ~50% of test-passing AI PRs would actually merge. ODD targets the two
things that matter: did the artifact do what the user asked, and would a
maintainer take the diff.

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

## License

MIT — see [LICENSE](LICENSE).
