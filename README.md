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
   `origin` matches <https://github.com/iop098321qwe/skills.git>.
2. If needed, search the home directory for matching checkouts, skipping
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
- Network access to the GitHub repository when running `sup`.
- A writable home directory; paths containing spaces are supported.

The function runs in a subshell to isolate its shell options and cleanup
traps from your interactive shell. Temporary export files are cleaned up
when it exits. Copy failures return a nonzero status; updates are not
transactional across all skills, so rerun after resolving the failure.

## Development

Run syntax checks and the isolated integration tests:

```bash
bash -n cbc-module.sh tests/sup.sh
npm test
```

Alternatively, run `bash tests/sup.sh` without npm. Tests use temporary
home directories and a local Git upstream instead of your real skills or
GitHub. They exercise cloning, discovery, `main` isolation, symlink
conversion, overwrite behavior, preservation, and error handling.

`npm install` installs the repository's Husky and commitlint development
tooling. Use Conventional Commits. Documentation sources are linked into
`docs/`; `.github/workflows/docs.yml` builds and deploys the site with
Zensical on pushes to `main` and `master`.
