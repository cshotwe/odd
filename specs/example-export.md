---
type: software
artifact: ./export
slug: billing-export
---

# Billing CSV export

## Problem

Finance needs a monthly CSV of paid invoices. Today they copy from the admin UI.

## Goal

running `./export --month YYYY-MM` writes a CSV with one row per paid invoice for that month

## Non-goals

- Unpaid or partial invoices
- PDF export
- Changing invoice storage schema

## Acceptance criteria

- exports May paid invoices | cmd: `./export --month 2026-05 && wc -l < out.csv` | expect: `42` | kind: e2e
- skips unpaid invoices | cmd: `./export --month 2026-05 && grep -c unpaid out.csv` | expect: `0` | kind: e2e
- rejects malformed month | cmd: `./export --month nonsense` | expect-fail | kind: e2e

## Artifact hints

- Build or invoke `./export` from repo root after implementing the CLI.
- Output file defaults to `out.csv` in cwd.

## Open questions

- (none)
