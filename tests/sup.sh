#!/usr/bin/env bash
set -euo pipefail

module=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/cbc-module.sh
source "$module"
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export HOME="$root/home with spaces"
mkdir -p "$HOME" "$root/upstream" "$root/tmp"
export TMPDIR="$root/tmp"
export GIT_CONFIG_GLOBAL="$root/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME='Skillmod Test' GIT_COMMITTER_NAME='Skillmod Test'
export GIT_AUTHOR_EMAIL='test@example.invalid'
export GIT_COMMITTER_EMAIL='test@example.invalid'
git config --global \
    url."$root/upstream".insteadOf https://github.com/iop098321qwe/skills.git
git init -q -b main "$root/upstream"
mkdir -p "$root/upstream/sample/references"
printf 'approved\n' >"$root/upstream/sample/SKILL.md"
printf 'reference\n' >"$root/upstream/sample/references/guide"
printf 'hidden\n' >"$root/upstream/sample/.hidden"
printf '#!/bin/sh\nexit 0\n' >"$root/upstream/sample/run.sh"
chmod +x "$root/upstream/sample/run.sh"
git -C "$root/upstream" add sample
git -C "$root/upstream" commit -qm 'feat: add approved skill'

# Missing repository: clone, copy nested/hidden files, preserve unrelated links.
mkdir -p "$HOME/.agents/skills" "$root/unrelated"
printf 'untouched\n' >"$root/unrelated/SKILL.md"
ln -s "$root/unrelated" "$HOME/.agents/skills/unrelated"
sup
repo="$HOME/Documents/github_repositories/skills"
installed="$HOME/.agents/skills/sample"
cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"
[[ -f "$installed/.hidden" && -f "$installed/references/guide" ]]
[[ -x "$installed/run.sh" ]]
[[ -L "$HOME/.agents/skills/unrelated" ]]
printf 'PASS: clone, nested files, hidden files, unrelated link\n'

# Neither local main, another branch nor uncommitted edits may be installed.
printf 'unapproved local main\n' >"$repo/sample/SKILL.md"
git -C "$repo" add sample
git -C "$repo" commit -qm 'feat: local only'
git -C "$repo" switch -qc wip
printf 'uncommitted\n' >"$repo/sample/SKILL.md"
printf 'keep\n' >"$installed/local-only"
printf 'outdated\n' >"$installed/SKILL.md"
ln -s "$root/unrelated" "$installed/references/link-only"
sup
cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"
[[ $(git -C "$repo" branch --show-current) == wip ]]
[[ $(<"$repo/sample/SKILL.md") == uncommitted ]]
[[ -f "$installed/local-only" && -L "$installed/references/link-only" ]]
printf 'PASS: main isolation, checkout preservation, destination-only files\n'

# Fresh approved updates overwrite same-size files and nested destination links.
rm "$installed/references/guide"
ln -s "$root/unrelated/SKILL.md" "$installed/references/guide"
printf 'updated!\n' >"$root/upstream/sample/SKILL.md"
git -C "$root/upstream" add sample
git -C "$root/upstream" commit -qm 'feat: update approved skill'
sup
cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"
[[ ! -L "$installed/references/guide" ]]
[[ $(<"$root/unrelated/SKILL.md") == untouched ]]
printf 'PASS: fresh main, nested file symlink replacement\n'

# Top-level skill symlinks become copies without writing to the checkout.
rm -r "$installed"
ln -s "$repo/sample" "$installed"
sup
[[ -d "$installed" && ! -L "$installed" ]]
[[ $(<"$repo/sample/SKILL.md") == uncommitted ]]
printf 'PASS: one-time skill symlink conversion\n'

# Discover a relocated checkout, including paths with spaces.
mkdir -p "$HOME/other place"
mv "$repo" "$HOME/other place/renamed checkout"
sup
[[ ! -e "$repo" ]]
printf 'PASS: relocated repository discovery\n'

# Multiple candidates are an error before destination changes.
git clone -q "$root/upstream" "$HOME/second checkout"
git -C "$HOME/second checkout" remote set-url origin \
    https://github.com/iop098321qwe/skills.git
if sup >"$root/output" 2>&1; then
    printf 'FAIL: ambiguous repositories accepted\n' >&2
    exit 1
fi
rm -rf "$HOME/second checkout"
printf 'PASS: ambiguous discovery rejected\n'

# Network failure must not fall back to stale main or touch installed files.
mv "$root/upstream" "$root/offline"
if sup >"$root/output" 2>&1; then
    printf 'FAIL: offline update accepted\n' >&2
    exit 1
fi
cmp "$installed/SKILL.md" "$root/offline/sample/SKILL.md"
mv "$root/offline" "$root/upstream"
printf 'PASS: failed fetch preserves installation\n'

# Destination directory links must not redirect writes outside installation.
rm -rf "$installed/references"
ln -s "$root/unrelated" "$installed/references"
sup
[[ ! -L "$installed/references" ]]
[[ ! -e "$root/unrelated/guide" ]]
printf 'PASS: nested directory symlink replacement\n'

# Refuse an ordinary file where a skill directory is expected.
mv "$installed" "$HOME/saved-sample"
printf 'preserve me\n' >"$installed"
if sup >"$root/output" 2>&1; then
    printf 'FAIL: conflicting destination file accepted\n' >&2
    exit 1
fi
[[ $(<"$installed") == 'preserve me' ]]
rm "$installed"
mv "$HOME/saved-sample" "$installed"
printf 'PASS: conflicting destination file preserved\n'

# Refuse linked install roots and source symlinks before copying anything.
mv "$HOME/.agents/skills" "$HOME/saved-skills"
ln -s "$HOME/saved-skills" "$HOME/.agents/skills"
if sup >"$root/output" 2>&1; then
    printf 'FAIL: linked installation root accepted\n' >&2
    exit 1
fi
rm "$HOME/.agents/skills"
mv "$HOME/saved-skills" "$HOME/.agents/skills"
ln -s /etc/passwd "$root/upstream/sample/external"
git -C "$root/upstream" add sample
git -C "$root/upstream" commit -qm 'test: source link'
if sup >"$root/output" 2>&1; then
    printf 'FAIL: source symlink accepted\n' >&2
    exit 1
fi
[[ ! -e "$installed/external" ]]
[[ -z $(find "$TMPDIR" -mindepth 1 -print -quit) ]]
printf 'PASS: source/root symlink guards and temporary cleanup\n'

if sup unexpected >"$root/output" 2>&1; then
    printf 'FAIL: unexpected arguments accepted\n' >&2
    exit 1
fi
printf 'All sup integration tests passed.\n'
