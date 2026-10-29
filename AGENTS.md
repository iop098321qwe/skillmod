# AGENTS.md

## Purpose

This file guides AI coding agents working in `skillmod`.
All work must follow best practices and industry standards where
applicable.

## Scope

This file covers repository-wide expectations for code, docs, and git
work.
It does not replace verified instructions in source files, tooling
configs,
or release automation.

## Formatting Rules

- Keep lines at 80 characters or fewer when practical.
- Allow longer lines only for URLs, code blocks, hashes, or commands
  that cannot be wrapped cleanly.

## Quick Start

- Read `README.md` first for project context and setup notes.
- Run `git status --short --branch` before editing to confirm repo
  state.
- Run `git diff --stat` before committing to review the change scope.
- Verification needed: add authoritative setup, run, or build
  commands when this repository defines them.

## Environment

- Git is required for day-to-day work in this repository.
- Verification needed: document runtime versions, package managers,
  and env vars when they exist.

## Repository Overview

- Root files hold the initial project overview, license, and repo
  policies.
- Verification needed: add top-level directories here when the repo
  grows.

## Tracked Files Overview

- `AGENTS.md`: AI coding agent instructions for this repository.
- `cbc-module.sh`: CBC module entrypoint and shell workflow functions.
- `done.txt`: Root completed task list placeholder for bootstrap workflows.
- `inbox.txt.tuxedo-lock`: Blank Tuxedo inbox lock file created alongside todo.txt.
- `LICENSE`: Project license text.
- `README.md`: Primary repository overview and setup notes.
- `todo.txt`: Root task list placeholder for bootstrap workflows.

## Architecture

- This repository starts from a minimal scaffold and may not define
  subsystems yet.
- Verification needed: describe components, boundaries, and data flow
  after they are introduced.

## Commands

- `git status --short --branch`: show the current branch and worktree
  state.
- `git diff --stat`: review the size and spread of pending changes.
- `git log --oneline --decorate -5`: inspect recent commit history.
- Verification needed: document authoritative build, run, lint, and
  task commands when the repository defines them.

## Testing

- Verification needed: add test commands and expectations when tests
  exist.
- Do not claim coverage, test gates, or suites that are not verified.

## Linting and Formatting

- Verification needed: add formatter and linter commands after they
  are introduced.
- Keep changes minimal and consistent with the existing code style.

## CI and Release

- Use Conventional Commits for every commit. Prefer a scope when it
  adds clarity.
- Never create, edit, or update `CHANGELOG.md` manually.
- `CHANGELOG.md` is generated and maintained by release tooling only.
- If release automation adds or changes generated files, let the
  tooling own those updates.

## Conventions

- Use small, correct changes that fit the existing project structure.
- Verify behavior from the actual codebase before documenting or
  changing it.
- Keep `AGENTS.md` as instructions, not as a changelog, diary, or work
  log.
- Do not add update notes, status logs, or change summaries to
  `AGENTS.md`.

## Security and Compliance

- Never commit secrets, credentials, tokens, or private keys.
- Verify new dependencies, automation, and scripts before trusting
  them.

## Dependencies and Services

- Verification needed: document external services, databases, queues,
  or storage when they are added.
- Avoid assuming any third-party service exists until the repo proves
  it.

## Troubleshooting

- If repo behavior is unclear, inspect tracked files and git history
  before making assumptions.
- If a generated or managed file changes unexpectedly, verify which
  tool owns it before editing.

## Refining Existing AGENTS.md

- Re-check every statement against the repository before keeping it.
- Remove stale, duplicated, or vague guidance.
- Replace placeholders with exact commands, paths, and verified
  workflows.
- Keep bullets short and easy for AI agents to scan.
- Preserve this section order when improving the file.

## Maintenance

- After any code, config, or doc change, verify that `AGENTS.md` still
  matches the repository.
- When `AGENTS.md` needs an update, make it in a separate `docs`
  Conventional Commit such as `docs(agents): update repo instructions`.
- Keep `AGENTS.md` out of mixed code commits whenever possible.
- Remove stale instructions instead of appending historical notes.
