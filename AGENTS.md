# AGENTS.md

## Purpose

Guide AI coding agents working in `skillmod`. All work must follow best
practices and industry standards where applicable.

## Scope

These instructions cover repository code, documentation, tests, and Git
work. Source files and tooling configuration define actual behavior.

## Formatting Rules

- Keep lines at 80 characters or fewer when practical.
- Longer URLs, hashes, code blocks, and unbreakable commands are allowed;
  identify any other necessary exception inline.

## Quick Start

- Read `README.md` and run `git status --short --branch` before editing.
- Source `cbc-module.sh` in Bash to expose `sup`.
- Run `bash -n cbc-module.sh tests/sup.sh tests/ble.sh` and `npm test`.
- Run `git diff --stat` before committing.

## Environment

- Runtime commands: Bash, Git, find, tar, rsync, mktemp, mkdir, and rm.
- Gum is optional for progress and summaries; util-linux `script` enables
  pseudo-terminal spinner tests.
- Optional ble.sh integration tests use `/usr/share/blesh/ble.sh`, or
  `SKILLMOD_TEST_BLE_PATH`, with isolated home/cache/runtime directories.
- `HOME` determines repository discovery and installation paths.
- `TMPDIR`, when set, selects the temporary export parent directory.
- Node.js and npm are needed only for commitlint and Husky tooling.
- Verification needed: minimum runtime versions are not pinned.

## Repository Overview

- `cbc-module.sh` implements the CBC command `sup`.
- `tests/` contains isolated shell integration tests.
- `docs/` links root Markdown sources into the documentation tree.
- `site/` contains tracked generated documentation output.
- `.github/` and `.husky/` hold deployment and commit automation.

## Tracked Files Overview

- `.github/workflows/docs.yml`: Zensical build and Pages deployment.
- `.gitignore`: local dependency and environment exclusions.
- `.husky/commit-msg`: commitlint hook.
- `AGENTS.md`: repository agent instructions.
- `CHANGELOG.md`: generated release history; never edit manually.
- `LICENSE`: GPL license text.
- `README.md`: command usage, behavior, and development setup.
- `cbc-module.sh`: sourceable Bash `sup` function.
- `commitlint.config.cjs`: Conventional Commits preset.
- `docs/AGENTS.md`: symlink to root agent instructions.
- `docs/README.md`: symlink to root README.
- `done.txt`: completed-task placeholder.
- `inbox.txt.tuxedo-lock`: task-tool lock placeholder.
- `package-lock.json`: npm dependency lockfile.
- `package.json`: test command and development tooling dependencies.
- `site/`: generated output; individual files are intentionally omitted.
- `tests/ble.sh`: attached ble.sh interactive test driver.
- `tests/sup.sh`: temporary-home and local-upstream integration tests.
- `todo.txt`: user-managed task file; agents must not access it.
- `zensical.toml`: documentation site configuration.

## Architecture

- `sup` runs in a subshell with isolated options, helpers, and traps.
- Use builtin `read`, `trap`, and `exit` internally so interactive shell
  wrappers cannot change EOF handling or lose cleanup/reporting state.
- Validate the expected checkout before searching; report invalid paths
  directly instead of silently falling through to discovery.
- Gum wraps interactive stages and styles the final result; use plain
  progress and summaries when unavailable or output is redirected.
- Pass stage data as arguments; retain NUL-delimited search results,
  itemized rsync reports, and completed-package counts in temporary files.
- Suppress successful command chatter; replay diagnostics on failure and
  report the failed stage and possible partial installation on exit.
- Confirm Gum worker completion and exit status independently of the
  spinner; report silent failures with an explicit status and explanation.
- Treat verified unchanged installations as success and explicitly report
  that no updates are needed; never infer this from a failed stage.
- Distinguish changed and unchanged packages using rsync itemization and
  directory/link replacements, not the number of packages visited.
- Discover a matching origin or clone the canonical skills repository.
- Fetch GitHub `main`, pin its commit, and export only skill packages.
- Exclude user-managed `todo.txt` files from exports and copies.
- Merge approved files into `~/.agents/skills/` using rsync checksums.
- Replace matching destination links; preserve unrelated skills and
  destination-only files. Never switch the source checkout's branch.

## Commands

- `source cbc-module.sh`: expose `sup` in the current Bash shell.
- `sup`: fetch and install approved skills; mutates the real installation.
- `bash -n cbc-module.sh tests/sup.sh tests/ble.sh`: validate shell syntax.
- `bash tests/sup.sh` or `npm test`: run integration tests.
- `npm install`: install commitlint and configure Husky.
- `zensical build --clean`: regenerate documentation with Zensical.

## Testing

- Tests create temporary homes and repositories and rewrite the GitHub
  URL to a local upstream through an isolated Git configuration.
- Verify main-only content, discovery, cloning, updates, permissions,
  symlink conversion, preservation, failure paths, and temporary cleanup.
- Cover expected-path priority, validation diagnostics, spinner result and
  failure propagation, and missing-Gum/non-interactive fallbacks.
- Verify changed, unchanged, and mixed result counts, failure summaries,
  and install-stage diagnostics without falsely reporting success.
- Cover silent spinner failures, missing worker completion, masked worker
  failures, and successful no-update messages in plain and terminal output.
- Verify wrapper isolation and nonempty failure stage/destination fields;
  run attached ble.sh checks when the local installation is available.
- Never test against the real installation without explicit user intent.

## Linting and Formatting

- Use Bash syntax checks and `git diff --check` before committing.
- `commitlint.config.cjs` extends the Conventional Commits preset.
- No shell formatter or ShellCheck dependency is configured.

## CI and Release

- `.github/workflows/docs.yml` deploys Pages on `main` and `master` pushes.
- CI installs Zensical and runs `zensical build --clean`.
- Use Conventional Commits with standalone, changelog-ready headers and
  supplemental bodies. Select the type from the actual change impact.
- Prefer amending small related corrections into the relevant current
  branch commit when explicitly authorized and history is unpublished;
  avoid unnecessary fixup or cleanup commits.
- Never edit `CHANGELOG.md` manually; generated changelogs belong to
  release tooling. No release filters are configured in this repository.

## Conventions

- Keep the module sourceable; loading it must not perform an update.
- Check failures explicitly so `if sup` callers also stop on errors.
- Keep README and AGENTS changes in separate docs-only commits.
- Agents must never read, create, edit, delete, move, stage, commit, or
  otherwise touch `todo.txt`; only the user may modify it manually.
- Keep instructions concise and free of update notes or work logs.

## Security and Compliance

- Never commit secrets, credentials, tokens, or private keys.
- Fetch installation content from the canonical GitHub URL, not local
  branches or working-tree files.
- Reject source symlinks and linked installation roots before copying.
- Do not follow destination symlinks when overwriting approved paths.

## Dependencies and Services

- `sup` uses <https://github.com/iop098321qwe/skills.git> over HTTPS.
- rsync merges files without `--delete` and preserves executable modes.
- Development uses Husky and commitlint from `package.json`.
- Docs deployment uses Zensical and GitHub Pages.

## Troubleshooting

- A failed fetch must abort without falling back to stale local content.
- For ambiguous discovery, place the intended checkout at the expected
  path documented in `README.md`.
- Fix reported Git or origin validation errors at the expected path;
  incomplete searches retain filesystem error details.
- Resolve occupied clone paths, linked roots, source links, and file
  conflicts before retrying. Copy failures may leave partial updates.
- Edit root Markdown sources, not their `docs/` symlinks or generated site.
- CBC can load an older installed module; source the intended checkout's
  `cbc-module.sh` directly when verifying uninstalled changes.

## Refining Existing AGENTS.md

- Verify every statement against the repository before keeping it.
- Remove stale, duplicated, or vague guidance and any update logs.
- Replace placeholders with exact verified commands and paths.
- Keep bullets short and preserve this section order.
- Mark unverified claims with the exact verification still needed.

## Maintenance

- After code, configuration, or docs changes, compare this file with the
  current source, tests, dependencies, and tracked file inventory.
- Recheck commands, paths, runtime requirements, and automation.
- Update mismatches in a separate docs Conventional Commit.
- Preserve the user-only task-file rule; never append maintenance logs.
