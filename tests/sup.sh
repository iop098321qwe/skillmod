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
sup >"$root/output" 2>&1
[[ $(<"$root/output") == *'Skills updated successfully'* ]]
[[ $(<"$root/output") == *'1 processed · 1 changed · 0 unchanged'* ]]
[[ $(<"$root/output") != *'Cloning into'* ]]
repo="$HOME/Documents/github_repositories/skills"
installed="$HOME/.agents/skills/sample"
cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"
[[ -f "$installed/.hidden" && -f "$installed/references/guide" ]]
[[ -x "$installed/run.sh" ]]
[[ -L "$HOME/.agents/skills/unrelated" ]]
printf 'PASS: clone, nested files, hidden files, unrelated link\n'
sup >"$root/output" 2>&1
[[ $(<"$root/output") == *'Skills already up to date'* ]]
[[ $(<"$root/output") == *'No updates needed. Your installed skills already match'* ]]
[[ $(<"$root/output") != *'Skills update failed'* ]]
[[ $(<"$root/output") == *'1 processed · 0 changed · 1 unchanged'* ]]
[[ $(<"$root/output") == *"Destination: $HOME/.agents/skills"* ]]
printf 'PASS: changed and already-up-to-date summaries\n'

# Internal stream reads and cleanup must bypass interactive shell wrappers.
read() { printf 'unexpected wrapped read\n' >&2; return 79; }
trap() { printf 'unexpected wrapped trap\n' >&2; return 79; }
exit() { printf 'unexpected wrapped exit\n' >&2; return 79; }
if ! sup >"$root/output" 2>&1; then
    unset -f read trap exit
    printf 'FAIL: shell wrappers interfered with sup\n' >&2
    exit 1
fi
unset -f read trap exit
[[ $(<"$root/output") == *'No updates needed.'* ]]
[[ $(<"$root/output") != *'unexpected wrapped'* ]]
printf 'PASS: builtin isolation from interactive shell wrappers\n'

# Count changed packages rather than merely counting every visited package.
mkdir -p "$root/upstream/second"
printf 'second skill\n' >"$root/upstream/second/SKILL.md"
git -C "$root/upstream" add second
git -C "$root/upstream" commit -qm 'feat: add second approved skill'
sup >"$root/output" 2>&1
printf 'outdated second skill\n' >"$HOME/.agents/skills/second/SKILL.md"
sup >"$root/output" 2>&1
[[ $(<"$root/output") == *'2 processed · 1 changed · 1 unchanged'* ]]
rsync() {
    if [[ "${*: -1}" == */second/ ]]; then
        printf 'simulated second-package failure\n' >&2
        return 23
    fi
    command rsync "$@"
}
if sup >"$root/output" 2>&1; then
    printf 'FAIL: later package failure reported success\n' >&2
    exit 1
fi
unset -f rsync
[[ $(<"$root/output") == *'Completed skills: 1'* ]]
[[ $(<"$root/output") == *'Installation may be partially applied'* ]]
[[ $(<"$root/output") != *'Skills updated successfully'* ]]
git -C "$root/upstream" rm -qr second
git -C "$root/upstream" commit -qm 'test: restore single-package fixture'
sup >"$root/output" 2>&1
printf 'PASS: mixed changed/unchanged counts\n'

# The preferred checkout must bypass home discovery, even with another match.
find() {
    if [[ "$1" == "$HOME" ]]; then
        printf 'FAIL: home search ran despite the preferred checkout\n' >&2
        return 1
    fi
    command find "$@"
}
git clone -q "$root/upstream" "$HOME/duplicate"
git -C "$HOME/duplicate" remote set-url origin \
    https://github.com/iop098321qwe/skills.git
sup
git -C "$repo" remote set-url origin \
    https://github.com/iop098321qwe/skills.git/
sup
git -C "$repo" remote set-url origin \
    https://github.com/iop098321qwe/skills.git
rm -rf "$HOME/duplicate"

# Resolve physical paths for a preferred checkout reached through a link.
mv "$repo" "$HOME/physical checkout"
ln -s "$HOME/physical checkout" "$repo"
sup
rm "$repo"
mv "$HOME/physical checkout" "$repo"

# An invalid preferred checkout gets a direct diagnostic, not a home search.
mv "$repo" "$HOME/saved-checkout"
git init -q -b main "$repo"
if sup >"$root/output" 2>&1; then
    printf 'FAIL: preferred checkout without origin accepted\n' >&2
    exit 1
fi
[[ $(<"$root/output") == *'checkout has no origin'* ]]
git -C "$repo" remote add origin https://github.com/example/other.git
if sup >"$root/output" 2>&1; then
    printf 'FAIL: preferred checkout with unrelated origin accepted\n' >&2
    exit 1
fi
[[ $(<"$root/output") == *'origin does not match'* ]]
rm -rf "$repo"
mv "$HOME/saved-checkout" "$repo"
unset -f find
printf 'PASS: preferred path priority, normalization, and diagnostics\n'

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
mv "$repo" "$HOME/other place/renamed 'checkout'"
sup
[[ ! -e "$repo" ]]
printf 'PASS: relocated repository discovery\n'

# Exercise interactive spinner dispatch in a PTY when util-linux is present.
# The stub runs the real search worker, checking cross-process result transfer.
if command -v script >/dev/null 2>&1; then
    export SKILLMOD_TEST_MODULE="$module"
    export SKILLMOD_TEST_SPIN_LOG="$root/spinner"
    gum() {
        if [[ "$1" == style ]]; then
            if [[ ${SKILLMOD_TEST_STYLE_FAIL:-0} == 1 ]]; then return 1; fi
            printf '%s\n' "${@: -1}"
            return 0
        fi
        [[ "$1" == spin && "$2" == --show-error ]]
        printf '%s\n' "$4" >>"$SKILLMOD_TEST_SPIN_LOG"
        case ${SKILLMOD_TEST_SPIN_MODE:-normal} in
            silent-failure) return 19 ;;
            skipped-worker) return 0 ;;
        esac
        while [[ "$1" != -- ]]; do shift; done
        shift
        if [[ ${SKILLMOD_TEST_SPIN_MODE:-normal} == masked-failure ]]; then
            "$@" || :
            return 0
        fi
        "$@"
    }
    _sup_test_run() {
        source "$SKILLMOD_TEST_MODULE"
        sup
    }
    export -f gum _sup_test_run
    script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1
    spin_log=$(<"$SKILLMOD_TEST_SPIN_LOG")
    [[ "$spin_log" == *'Searching for the skills repository'* ]]
    [[ "$spin_log" == *'Fetching approved main'* ]]
    [[ "$spin_log" == *'Preparing approved skills'* ]]
    [[ "$spin_log" == *'Installing skills'* ]]
    [[ $(<"$root/output") == *'Skills already up to date'* ]]
    [[ $(<"$root/output") == *'No updates needed.'* ]]
    cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"

    export SKILLMOD_TEST_STYLE_FAIL=1
    script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1
    [[ $(<"$root/output") == *'Skills already up to date'* ]]
    unset SKILLMOD_TEST_STYLE_FAIL
    spin_log=$(<"$SKILLMOD_TEST_SPIN_LOG")

    # No spinner in redirected/non-interactive output, even if Gum exists.
    sup >"$root/output" 2>&1
    [[ $(<"$SKILLMOD_TEST_SPIN_LOG") == "$spin_log" ]]

    # Missing Gum still permits an interactive search with a plain message.
    command() {
        if [[ "${1-}" == -v && "${2-}" == gum ]]; then return 1; fi
        builtin command "$@"
    }
    export -f command
    script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1
    [[ $(<"$SKILLMOD_TEST_SPIN_LOG") == "$spin_log" ]]
    unset -f command

    # A silent Gum failure must still explain the stage and its exit status.
    export SKILLMOD_TEST_SPIN_MODE=silent-failure SKILLMOD_TEST_STYLE_FAIL=1
    if script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1; then
        printf 'FAIL: silent spinner failure reported success\n' >&2
        exit 1
    fi
    [[ $(<"$root/output") == *'no diagnostics were provided'* ]]
    [[ $(<"$root/output") == *'Stage exit status: 19'* ]]
    [[ $(<"$root/output") == *'Skills update failed'* ]]
    [[ $(<"$root/output") != *'No updates needed.'* ]]
    unset SKILLMOD_TEST_STYLE_FAIL

    # Gum success without a completed worker cannot authorize the next stage.
    export SKILLMOD_TEST_SPIN_MODE=skipped-worker
    if script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1; then
        printf 'FAIL: unconfirmed stage completion accepted\n' >&2
        exit 1
    fi
    [[ $(<"$root/output") == *'stage did not confirm completion'* ]]
    [[ $(<"$root/output") == *'Skills update failed'* ]]

    # Read worker status independently when a spinner masks a failed fetch.
    export SKILLMOD_TEST_SPIN_MODE=masked-failure
    mv "$root/upstream" "$root/offline"
    if script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1; then
        printf 'FAIL: masked worker failure reported success\n' >&2
        exit 1
    fi
    mv "$root/offline" "$root/upstream"
    [[ $(<"$root/output") == *'Stage: Fetching approved main'* ]]
    [[ $(<"$root/output") == *'Skill installation has not started'* ]]
    unset SKILLMOD_TEST_SPIN_MODE
    printf 'PASS: silent, skipped, and masked spinner failure diagnostics\n'

    # Filesystem errors propagate through the worker and spinner.
    find() {
        if [[ "$1" == "$HOME" ]]; then
            printf 'simulated search permission denied\n' >&2
            return 1
        fi
        command find "$@"
    }
    export -f find
    if script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1; then
        printf 'FAIL: spinner swallowed a search failure\n' >&2
        exit 1
    fi
    [[ $(<"$root/output") == *'simulated search permission denied'* ]]
    [[ $(<"$root/output") == *'repository search was incomplete'* ]]
    [[ $(<"$root/output") == *'Skills update failed'* ]]
    [[ $(<"$root/output") == *'Skill installation has not started'* ]]
    unset -f find gum
    if command -v gum >/dev/null 2>&1; then
        script -qec 'bash -c _sup_test_run' /dev/null >"$root/output" 2>&1
        cmp "$installed/SKILL.md" "$root/upstream/sample/SKILL.md"
        printf 'PASS: real Gum spinner with a quoted checkout path\n'
    fi

    # Optional real ble.sh checks reproduce the user's interactive environment.
    ble_path=${SKILLMOD_TEST_BLE_PATH:-/usr/share/blesh/ble.sh}
    if [[ -f "$ble_path" ]]; then
        export SKILLMOD_TEST_BLE_PATH="$ble_path"
        export SKILLMOD_TEST_BLE_DRIVER="${module%/*}/tests/ble.sh"
        export XDG_CACHE_HOME="$root/ble-cache" XDG_RUNTIME_DIR="$root/ble-run"
        export TERM=xterm-256color
        mkdir -p "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
        script -qec 'bash --noprofile --norc -i "$SKILLMOD_TEST_BLE_DRIVER"' \
            /dev/null >"$root/output" 2>&1
        [[ $(<"$root/output") == *'No updates needed.'* ]]
        [[ $(<"$root/output") == *'BLE_SUP_STATUS=0'* ]]

        mv "$root/upstream" "$root/offline"
        if script -qec 'bash --noprofile --norc -i "$SKILLMOD_TEST_BLE_DRIVER"' \
            /dev/null >"$root/output" 2>&1; then
            printf 'FAIL: ble.sh failed fetch reported success\n' >&2
            exit 1
        fi
        mv "$root/offline" "$root/upstream"
        [[ $(<"$root/output") == *'Stage: Fetching approved main'* ]]
        [[ $(<"$root/output") == *"Destination: $HOME/.agents/skills"* ]]
        [[ $(<"$root/output") == *'BLE_SUP_STATUS=1'* ]]
        [[ $(<"$root/output") != *'internal reporting state is missing'* ]]
        unset SKILLMOD_TEST_BLE_DRIVER SKILLMOD_TEST_BLE_PATH
        unset XDG_CACHE_HOME XDG_RUNTIME_DIR
        printf 'PASS: real attached ble.sh no-update and failure reporting\n'
    else
        printf 'SKIP: real ble.sh checks require a local ble.sh installation\n'
    fi
    unset -f _sup_test_run
    unset SKILLMOD_TEST_MODULE SKILLMOD_TEST_SPIN_LOG
    printf 'PASS: spinner results, failures, and plain-output fallbacks\n'
else
    printf 'SKIP: interactive spinner checks require util-linux script\n'
fi

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
[[ $(<"$root/output") == *'Skills update failed'* ]]
[[ $(<"$root/output") == *'Stage: Fetching approved main'* ]]
[[ $(<"$root/output") == *'Skill installation has not started'* ]]
[[ $(<"$root/output") != *'Skills updated successfully'* ]]
mv "$root/offline" "$root/upstream"
printf 'PASS: failed fetch preserves installation\n'

# Copy failures retain diagnostics and explicitly report possible partial work.
rsync() {
    printf 'simulated copy failure\n' >&2
    return 23
}
if sup >"$root/output" 2>&1; then
    printf 'FAIL: failed copy reported success\n' >&2
    exit 1
fi
unset -f rsync
[[ $(<"$root/output") == *'simulated copy failure'* ]]
[[ $(<"$root/output") == *'Stage: Installing skills'* ]]
[[ $(<"$root/output") == *'Installation may be partially applied'* ]]
[[ $(<"$root/output") == *'Completed skills: 0'* ]]
[[ $(<"$root/output") != *'Skills updated successfully'* ]]
printf 'PASS: installation failure summary and diagnostics\n'

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
