---
name: odd-plan
description: Turn a feature spec or user requirements into an ODD outcome contract. Use after ideation or when the user gives clear requirements, before writing code. Produces odd init + checks (or odd from-spec).
---

# ODD plan — spec → outcome contract

Run this **before** the ODD build skill when `.odd/outcome.json` does not exist or needs
replacing from a spec.

## Inputs (first match wins)

1. `specs/<slug>.md` the user points at (preferred)
2. Any markdown spec path with `## Goal` and `## Acceptance criteria`
3. Requirements in the current message (synthesize a spec mentally, then proceed)

If requirements are vague, use the **ideation** skill first (when available) or ask 1–2
clarifying questions — do not guess executable checks.

## Steps

### 1. Read the spec

Extract:

- **Goal** → one user-observable outcome sentence
- **Acceptance criteria** → 2–5 checks (see format in `specs/README.md`)
- **Artifact hints** → how to invoke the real CLI/endpoint/build
- **Non-goals** → scope guardrails for later review

### 2. Draft checks

Every contract needs **at least one `kind: e2e` check with a real `cmd:`** that runs the
artifact the way the user/grader would — not an internal function or self-built harness.

| Pattern | Check shape |
|---------|-------------|
| New feature | e2e happy path + regression (old behavior unchanged) |
| Bug fix | repro with `--expect-fail` first, then fixed behavior e2e |
| API | `curl` against running service (start server in cmd if needed) |

Use `odd-template` for common shapes (CLI flag, bug fix, endpoint). See
`references/check-patterns.md`.

Mark any check you cannot make executable as **TBD** — ask the user for artifact hints;
do not invent thresholds.

### 3. Materialize the contract

**From a spec file** (preferred — deterministic):

```
odd from-spec specs/<slug>.md --dry-run    # review first
odd from-spec specs/<slug>.md --apply      # writes .odd/outcome.json
```

**Or manually** when no spec file exists yet:

```
odd init "<goal sentence>"
odd check "..." --cmd "..." --expect "..." --kind e2e
```

### 4. Validate before build

```
odd spec validate specs/<slug>.md   # if a spec file exists
odd-lint                            # scope / unit-test traps on the contract
```

Fix issues, then hand off to the **ODD** skill (build → prove → review).

## Do not

- Write application code in this step
- Skip the e2e check because "we'll add it later"
- Use pytest/unittest as the only check — those are regression, not proof
