# Specs

Human-reviewable feature specs feed the ODD planning pipeline.

## Workflow

1. **Ideation** (optional) — explore scope, write `specs/<slug>.md`
2. **Plan** — `odd from-spec specs/<slug>.md` → `.odd/outcome.json`
3. **Build** — existing ODD loop: build → `odd prove` → `odd review`

Scaffold a new spec: `odd spec init "billing export"`

## Format

```markdown
---
type: software          # optional: software | api | analytics
artifact: ./export      # optional: primary CLI/binary/URL to exercise
slug: billing-export    # optional: filename hint
---

# Title

## Goal
One sentence the user will observe — becomes `odd init` input.

## Non-goals
What this change explicitly does NOT include.

## Acceptance criteria
Pipe-separated fields per line (at least one must be `kind: e2e` with `cmd:`):

- exports May paid invoices | cmd: `./export --month 2026-05 && wc -l < out.csv` | expect: `42` | kind: e2e
- skips unpaid rows | cmd: `./export --month 2026-05 && grep -c unpaid out.csv` | expect: `0` | kind: e2e
- rejects bad month | cmd: `./export --month nonsense` | expect-fail

Plain bullets without `cmd:` are recorded as TBD — `odd from-spec` warns and refuses `--apply` until filled in.

## Artifact hints
How to run/build the real thing: binary path, server start command, grader entry point.

## Open questions
Unresolved items — resolve before `odd from-spec --apply`.
```

See `example-export.md` for a filled example.
