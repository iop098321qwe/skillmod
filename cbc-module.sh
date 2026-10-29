#!/usr/bin/env bash

# Run in a subshell so traps, options, and helpers do not affect CBC's shell.
sup() (
    set -euo pipefail
    local url='https://github.com/iop098321qwe/skills.git'
    local expected="${HOME:?HOME must be set}/Documents/github_repositories/skills"
    local destination="$HOME/.agents/skills"
    local repo='' candidate remote tool temporary commit entry name skill
    local -a matches=() skills=() paths=()

    if (( $# )); then
        printf 'Usage: sup\n' >&2
        return 2
    fi
    for tool in git find tar rsync mktemp mkdir rm; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf 'sup: required command not found: %s\n' "$tool" >&2
            return 1
        fi
    done

    _sup_is_repo() {
        local root
        root=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
        [[ "$root" == "$(cd -- "$1" && pwd -P)" ]] || return 1
        remote=$(git -C "$1" config --get remote.origin.url 2>/dev/null) \
            || return 1
        case "$remote" in
            https://github.com/iop098321qwe/skills|\
            https://github.com/iop098321qwe/skills.git|\
            git@github.com:iop098321qwe/skills|\
            git@github.com:iop098321qwe/skills.git|\
            ssh://git@github.com/iop098321qwe/skills|\
            ssh://git@github.com/iop098321qwe/skills.git) return 0 ;;
            *) return 1 ;;
        esac
    }

    temporary=$(mktemp -d "${TMPDIR:-/tmp}/skillmod.XXXXXXXX") || return 1
    trap 'rm -rf -- "$temporary"' EXIT

    if [[ -d "$expected" ]] && _sup_is_repo "$expected"; then
        repo=$expected
    else
        printf 'sup: searching for the skills repository in %s\n' "$HOME"
        # Do not follow symlinks or descend into Git/dependency/cache data.
        if ! find "$HOME" \( -type d \( -name .cache -o -name node_modules \
            -o -name .venv -o -name .Trash \) -prune \) -o \
            \( -name .git \( -type d -o -type f \) -print0 -prune \) \
            >"$temporary/repositories"; then
            printf 'sup: repository search was incomplete; aborting.\n' >&2
            return 1
        fi
        while IFS= read -r -d '' candidate; do
            candidate=${candidate%/.git}
            if _sup_is_repo "$candidate"; then
                matches+=("$candidate")
            fi
        done <"$temporary/repositories"
        if (( ${#matches[@]} > 1 )); then
            printf 'sup: multiple skills repositories found:\n' >&2
            printf '  %s\n' "${matches[@]}" >&2
            printf 'Place the intended checkout at %s and retry.\n' \
                "$expected" >&2
            return 1
        elif (( ${#matches[@]} == 1 )); then
            repo=${matches[0]}
        else
            if [[ -e "$expected" || -L "$expected" ]]; then
                printf 'sup: clone destination is already occupied: %s\n' \
                    "$expected" >&2
                return 1
            fi
            mkdir -p -- "${expected%/*}" || return 1
            git clone --single-branch --branch main -- "$url" "$expected" \
                || return 1
            repo=$expected
        fi
    fi

    printf 'sup: fetching GitHub main using %s\n' "$repo"
    # Fetch from the canonical URL, even when origin uses another transport.
    # FETCH_HEAD pins this run without changing any local branch or worktree.
    git -C "$repo" fetch --no-tags -- "$url" refs/heads/main || return 1
    commit=$(git -C "$repo" rev-parse --verify 'FETCH_HEAD^{commit}') \
        || return 1
    git -C "$repo" ls-tree -z "$commit" >"$temporary/tree" || return 1
    while IFS= read -r -d '' entry; do
        [[ "$entry" == '040000 tree '* ]] || continue
        name=${entry#*$'\t'}
        if git -C "$repo" cat-file -e "$commit:$name/SKILL.md" 2>/dev/null; then
            skills+=("$name")
            paths+=(":(literal)$name")
        fi
    done <"$temporary/tree"
    if (( ${#skills[@]} == 0 )); then
        printf 'sup: no top-level skill packages found on GitHub main.\n' >&2
        return 1
    fi

    mkdir -- "$temporary/source" || return 1
    # User-managed task files are not installation material.
    git -C "$repo" archive --format=tar "$commit" -- "${paths[@]}" \
        ':(glob,exclude)**/todo.txt' >"$temporary/skills.tar" || return 1
    tar -xf "$temporary/skills.tar" -C "$temporary/source" || return 1
    # Reject source links rather than dereferencing outside the approved tree.
    find "$temporary/source" -type l -print0 >"$temporary/links" || return 1
    if [[ -s "$temporary/links" ]]; then
        printf 'sup: source skills contain symlinks; refusing installation.\n' >&2
        return 1
    fi
    for name in "${skills[@]}"; do
        if [[ ! -f "$temporary/source/$name/SKILL.md" ]]; then
            printf 'sup: exported skill has no regular SKILL.md: %s\n' \
                "$name" >&2
            return 1
        fi
    done
    if [[ -L "$HOME/.agents" || -L "$destination" ]]; then
        printf 'sup: the installation root must be a real directory.\n' >&2
        return 1
    fi
    mkdir -p -- "$destination" || return 1
    for name in "${skills[@]}"; do
        skill="$destination/$name"
        if [[ -e "$skill" && ! -d "$skill" && ! -L "$skill" ]]; then
            printf 'sup: skill destination is not a directory: %s\n' \
                "$skill" >&2
            return 1
        fi
    done
    for name in "${skills[@]}"; do
        skill="$destination/$name"
        if [[ -L "$skill" ]]; then
            rm -- "$skill" || return 1
        fi
        mkdir -p -- "$skill" || return 1
        # No --delete: retain destination-only files and unrelated skills.
        # --checksum catches same-size edits made within one timestamp tick.
        rsync -rlpt --checksum --exclude=todo.txt -- \
            "$temporary/source/$name/" "$skill/" || return 1
        printf 'sup: installed %s\n' "$name"
    done
    printf 'sup: installed %d skills from main at %s into %s\n' \
        "${#skills[@]}" "$commit" "$destination"
)
