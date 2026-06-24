# AGENTS.md

## Cursor Cloud specific instructions

`odd` is a single-purpose CLI for Outcome-Driven Development, distributed as a
Claude Code plugin/skill and as a Cursor integration (`.cursor/` config in this
repo). See `README.md` for the user-facing workflow and the full CLI reference,
and `skills/odd/SKILL.md` for the agent loop.

- **No dependencies, no build step.** Everything is pure Python 3.8+ standard
  library (`python3` is already on the VM). There is nothing to `pip install`,
  compile, or bundle.
- **No automated test suite or linter is configured.** There is no `pytest`,
  `package.json`, or lint config. "Running the app" means invoking the CLI; CI
  for the methodology itself is `odd ci` over `outcomes/*.outcome.json` specs
  (none are committed in this repo).
- **The CLI is the application.** After the Cloud Agent VM boots, `odd` is on
  PATH (via `.cursor/environment.json`). You can also run
  `python3 skills/odd/bin/odd <command>` or `skills/odd/bin/odd` directly. The
  subcommands are `init / check / prove / status / review / done / archive / ci /
  reset`.
- **`odd` must run inside a git repository.** It calls `git rev-parse
  --show-toplevel` to locate the project root and fingerprints the working tree
  via `git diff`/`git status`; outside a repo it falls back to `cwd` and tree
  fingerprints are meaningless. Demo/test it inside a throwaway `git init` dir,
  not in `/tmp` alone.
- **Checks run under `bash`, not `sh`.** `_run_check` explicitly uses bash so
  process-substitution checks (`diff <(...) <(...)`) work; keep bash available.
- **Working state lives in `.odd/`** (`outcome.json` + `evidence.json`), which
  is git-ignored. Durable specs live in committed `outcomes/`. Evidence is keyed
  to a working-tree fingerprint, so it goes `stale` after any edit — re-run
  `odd prove`.
- **The `e2e` gate is intentional:** `odd done` (and the Stop hook
  `skills/odd/hooks/outcome_gate.py`) only report `proven` when at least one
  `--kind e2e` check passes; all-green `self`/`unit` checks report `unverified`
  and the Stop hook exits 2 to block finishing.
- **Cursor integration:** This repo ships `.cursor/hooks.json` (sessionStart +
  stop), `.cursor/rules/odd-workflow.mdc`, and a skill symlink at
  `.cursor/skills/odd`. Install into other projects with `./install-cursor.sh
  /path/to/project`. **Cloud Agents do not run `sessionStart` or `stop` hooks
  yet** — you must follow the ODD workflow from this file and `skills/odd/SKILL.md`,
  and run `odd prove && odd done` before declaring a task complete.
- **Claude Code project install:** `./install.sh /path/to/project` copies the
  skill into that project's `.claude/skills/odd/` and registers the Stop hook in
  its `.claude/settings.json`.
