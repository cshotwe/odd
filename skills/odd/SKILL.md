---
name: odd
description: Outcome-driven development. Use when implementing a feature, fixing a bug, or making any code change a user asked for. Replaces TDD/spec rituals with proof that the real artifact does what the user wanted.
---

# Outcome-driven development

The objective is never "tests pass." It is: **the user runs the thing and
sees what they asked for, and a maintainer would merge the diff.**

Four steps. Spend your effort on 1 and 3, not on process.

## 1. Intent — before touching code

Write the outcome as the user would observe it, then 2–5 acceptance checks
that exercise the **real artifact** (the CLI, the endpoint, the page, the
build) the way the user would. **At least one check must be `--kind e2e`** —
it runs the real artifact end-to-end and observes the outcome. `odd done` (and
the Stop gate) will refuse to certify "proven" until a passing e2e check exists,
no matter how many other checks are green.

```
odd init "users can filter the report by date range"
odd check "filtering works end-to-end" --cmd "./report --from 2026-01-01" --expect "3 rows" --kind e2e
odd check "old behavior unchanged"      --cmd "./report"                   --expect "12 rows" --kind e2e
```

For a bug fix, the first check is the user's reproduction, recorded
*failing* before you change anything (`--expect-fail` flips later — update
it to assert the fixed behavior once you understand it).

**Check `--kind` is load-bearing — pick the strongest the task allows:** `e2e`
(runs the real artifact as the user/grader does — **required**) > `reference`
(diff against a *provided* oracle you did NOT write) > `spec` (a value quoted
verbatim from the task, needs `--source`) > `differential` > `unit`/`self`
(internal function or self-defined threshold — **cannot satisfy the gate**).

**The trap this prevents (it has bitten real runs):** do NOT build your own
simulator/harness/threshold and treat passing *it* as proof — a check you author
against code you wrote agrees with itself by construction, and can be green while
the real grader scores zero. If the task ships an evaluation entry point, invoke
*that*. If you cannot phrase any executable e2e check, you don't yet know what
the user wants — re-read the request or ask, don't guess.

## 2. Build

Smallest change that achieves the outcome. Match the surrounding code's
style, naming, and comment density exactly. No defensive code, refactors,
new files, or comments the task didn't ask for.

## 3. Prove

```
odd prove
```

Runs every check against the real artifact and records verbatim evidence, plus
a **verification profile** showing how the outcome was checked (by `--kind`). If
a check fails, fix the code, not the check. Evidence goes stale when the code
changes — re-prove after any edit. (A Stop hook blocks finishing without fresh
passing evidence **including a passing `e2e` check** — all-green self/unit checks
report as `unverified`, not `proven`.)

## 4. Review — as the maintainer who must merge this

```
odd review
```

Then read the full diff yourself and cut anything that doesn't serve the
outcome. Half of test-passing AI changes get rejected by maintainers, and
the top reasons are style mismatch, scope creep, and collateral breakage —
not wrong functionality. If existing project tests exist, run them now
(that's regression protection, which is what existing tests are for).

---

## Checks must target what YOU build

When the workspace contains a provided reference artifact (a binary to match,
a golden output, an existing service), it is the **comparison oracle — never
the artifact under test**. Snapshot it first, then write checks that run the
artifact *your build produces* and compare against the snapshot:

```bash
cp executable .odd/reference_bin    # preserve the oracle before building
odd check "kerning matches reference" \
  --cmd 'bash compile.sh >/dev/null 2>&1 && diff <(./executable -k "Hi") <(.odd/reference_bin -k "Hi")'
```

A check that only exercises the provided artifact proves nothing about your
work — it passes before you write a single line.

## Outcomes outlive the task: archive + ci

Once proven, `odd archive` promotes the contract to a durable
`outcomes/<slug>.outcome.json` spec. Archived specs are ODD's regression suite
— each is the promise the code makes to users (one outcome sentence + black-box
checks against the real artifact). `odd ci` (optionally `--junit report.xml`)
re-runs every spec like a unit-test job. Contract changes show up as spec edits
in the diff, so they're reviewed, never silent. When you work near an archived
outcome, read its spec first — it's the distilled context of what must keep
working.
