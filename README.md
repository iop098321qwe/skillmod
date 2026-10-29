# Skillmod

CBC module for installing approved skills as ordinary files with **`sup`**
(short for “skill-update”).

## Usage

Load this module through CBC, or source it directly in Bash:

```bash
source /path/to/skillmod/cbc-module.sh
sup
```

`sup` takes no arguments. It installs into `~/.agents/skills/` and reports
the GitHub `main` commit used for the update.

## Update workflow

1. Check `~/Documents/github_repositories/skills` for a checkout whose
   `origin` matches <https://github.com/iop098321qwe/skills.git>. Use it
   immediately if valid, without searching the home directory. If that
   path exists but is invalid, report the validation error and stop.
2. If the expected path is absent, search for matching checkouts, skipping
   `.git`, `.cache`, `node_modules`, `.venv`, and `.Trash` contents. The
   search does not follow symlinks. Multiple matches or an incomplete
   search cause an error.
3. If none exists, create the parent directory and clone GitHub `main`
   into the expected path. An occupied destination is never overwritten.
4. Fetch `main` directly from the canonical GitHub HTTPS URL and export
   that exact commit to a temporary directory. A failed fetch aborts the
   update; there is no fallback to an older local branch.
5. Install top-level directories containing `SKILL.md`, including their
   supporting files, hidden files, and executable permissions.

Repository validation resolves physical paths and accepts HTTPS or SSH
origins, with or without a trailing slash.

## Progress and results

In interactive terminals, `sup` uses Gum spinners for checkout validation,
fallback discovery, cloning, fetching, export preparation, and installation.
Successful stages omit raw Git output and per-skill chatter. If a stage
fails, its diagnostics are shown along with a failure summary naming the
stage. The summary states whether installation has started and may be
partially applied, including how many skills completed.

Every successful run ends with a result summary:

```text
Skills updated successfully

Skills: 7 processed · 2 changed · 5 unchanged
Destination: /home/user/.agents/skills
Repository: /home/user/Documents/github_repositories/skills
Source: main @ <full commit hash>
```

If all installed packages match, the heading is **Skills already up to
date**, followed by **No updates needed. Your installed skills already
match the approved main branch.** This is a successful check (exit status
0), not an update failure.

Counts describe packages, not individual files: rsync's itemized
content or metadata changes mark a package as changed, as do new package
directories and replaced skill symlinks. Unrelated skills are not counted.

Gum styles the final summary when available. If Gum is missing or output
is redirected, the same information is printed as plain text with one
progress line per stage. Search results and installation counts stay in
temporary files independently of spinner output. Styling failures fall
back to plain text without changing the update result.

Failures include an exit status as well as the stage name. If the stage
provides no diagnostic output, the result explicitly says so. Gum stages
must record worker completion independently of the spinner's own exit
status; missing completion or a failed worker stops the update. A failure
never uses the no-updates message to explain an unverified installation.

## Installation behavior

The local checkout's branch, uncommitted edits, untracked files, and
unpushed commits are not used as installation content. The command does
not switch branches or update local branches. Fetching does update Git's
object database and `FETCH_HEAD`.

Matching destination files are overwritten. Destination-only files and
skills absent from the repository are preserved, including skills removed
from `main`. User-managed `todo.txt` files are excluded from exports and
copies. No deletion-based mirror operation is performed.

## Moving away from symlinks

The first `sup` run replaces installed skill symlinks with ordinary
directories when their names match skill packages on GitHub `main`. Their
original targets are not modified or copied, so local work-in-progress
cannot enter the installation through those links.

Unrelated skill symlinks, such as Omarchy-managed skills, remain untouched.
Nested destination links that conflict with approved files or directories
are replaced without writing through to their targets.

The installation roots (`~/.agents` and `~/.agents/skills`) must be real
directories. Source skill symlinks are rejected before installation to
avoid copying content from outside the approved export. An ordinary file
blocking a skill directory is also reported as an error.

## Requirements

- Bash, Git, `find`, `tar`, `rsync`, `mktemp`, `mkdir`, and `rm`.
- Optional: `gum` for interactive stage spinners and styled result summaries.
- Network access to the GitHub repository when running `sup`.
- A writable home directory; paths containing spaces are supported.

The function runs in a subshell to isolate its shell options and cleanup
traps from your interactive shell. Internal file reads and cleanup use
Bash's builtin `read`, `trap`, and `exit`, bypassing interactive wrappers
such as ble.sh without changing those wrappers in your shell. Temporary
export files are cleaned up when it exits. Copy failures return a nonzero
status; updates are not
transactional across all skills, so rerun after resolving the failure.

## Development

Run syntax checks and the isolated integration tests:

```bash
bash -n cbc-module.sh tests/sup.sh tests/ble.sh
npm test
```

Alternatively, run `bash tests/sup.sh` without npm. Tests use temporary
home directories and a local Git upstream instead of your real skills or
GitHub. They exercise cloning, discovery, `main` isolation, symlink
conversion, overwrite behavior, preservation, and error handling.
Result tests cover changed, unchanged, and mixed-package counts, fetch
failures before installation, and possible partial installation failures.
Interactive spinner tests run in a pseudo-terminal when util-linux
`script` is available; other tests run without it.
With `script` and `/usr/share/blesh/ble.sh` installed, the suite also checks
successful no-update runs and failure summaries in an attached ble.sh
session. Set `SKILLMOD_TEST_BLE_PATH` to test a different ble.sh location.
These checks use temporary home, cache, and runtime directories.

`npm install` installs the repository's Husky and commitlint development
tooling. Use Conventional Commits. Documentation sources are linked into
`docs/`; `.github/workflows/docs.yml` builds and deploys the site with
Zensical on pushes to `main` and `master`.

## Troubleshooting shell integration

If you are testing changes from a repository checkout, source that
checkout's `cbc-module.sh` directly. CBC may load a separate installed copy
under `~/.config/cbc/modules/skillmod/`, so reloading CBC can restore an
older function until the installed module is updated.
