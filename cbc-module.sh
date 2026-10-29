#!/usr/bin/env bash

# Run in a subshell so traps, options, and helpers do not affect CBC's shell.
# Internal reads/traps/exits use builtins: interactive extensions such as
# ble.sh wrap those names and can alter EOF handling and cleanup scope.
sup() (
    set -euo pipefail
    local url='https://github.com/iop098321qwe/skills.git'
    local expected="${HOME:?HOME must be set}/Documents/github_repositories/skills"
    local destination="$HOME/.agents/skills"
    local repo='' tool temporary='' commit entry name skill
    local stage='Checking requirements' use_gum=0 changed=0 unchanged=0
    local completed=0 stage_status=''
    local -a matches=() skills=() paths=()

    _sup_result() {
        local color=$1 text=$2
        if (( use_gum )); then
            gum style --bold --border rounded --padding '1 2' \
                --border-foreground "$color" -- "$text" && return 0
        fi
        printf '%s\n' "$text"
    }

    _sup_counts() {
        local result
        changed=0 unchanged=0
        if [[ -n "$temporary" && -f "$temporary/results" ]]; then
            while IFS= builtin read -r result; do
                case "$result" in
                    changed) changed=$((changed + 1)) ;;
                    unchanged) unchanged=$((unchanged + 1)) ;;
                esac
            done <"$temporary/results"
        fi
    }

    _sup_finish() {
        local status=$? message
        builtin trap - EXIT
        # Reporting must continue even when a diagnostic helper fails under -e.
        set +e
        if (( status == 0 && ! completed )); then
            status=1
            printf 'sup: command ended before its result was confirmed.\n' >&2
        fi
        if (( status != 0 )); then
            if [[ -z ${stage-} || -z ${destination-} ]]; then
                printf 'sup: internal reporting state is missing.\n' >&2
                stage=${stage:-Unknown stage (reporting state unavailable)}
                destination=${destination:-$HOME/.agents/skills}
            fi
            _sup_counts
            printf -v message 'Skills update failed\n\nStage: %s\nExit status: %d' \
                "$stage" "$status"
            if [[ -n "$stage_status" ]]; then
                message+=$'\nStage exit status: '"$stage_status"
            fi
            if [[ -n "$temporary" && -f "$temporary/install-started" ]]; then
                message+=$'\nInstallation may be partially applied.'
                message+=$'\nCompleted skills: '"$((changed + unchanged))"
            else
                message+=$'\nSkill installation has not started.'
            fi
            message+=$'\nDestination: '"$destination"
            _sup_result 196 "$message" >&2
        fi
        if [[ -n "$temporary" ]]; then rm -rf -- "$temporary"; fi
        builtin exit "$status"
    }
    builtin trap _sup_finish EXIT
    if [[ -t 1 && -t 2 ]] && command -v gum >/dev/null 2>&1; then
        use_gum=1
    fi

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
        local root physical remote
        if ! root=$(git -C "$1" rev-parse --show-toplevel 2>&1); then
            printf 'sup: cannot inspect checkout %s: %s\n' "$1" "$root" >&2
            return 1
        fi
        root=$(cd -- "$root" && pwd -P) || return 1
        physical=$(cd -- "$1" && pwd -P) || return 1
        if [[ "$root" != "$physical" ]]; then
            printf 'sup: path is not a repository root: %s\n' "$1" >&2
            return 1
        fi
        remote=$(git -C "$1" config --get remote.origin.url 2>/dev/null) \
            || {
                printf 'sup: checkout has no origin: %s\n' "$1" >&2
                return 1
            }
        remote=${remote%/}
        case "$remote" in
            https://github.com/iop098321qwe/skills|\
            https://github.com/iop098321qwe/skills.git|\
            git@github.com:iop098321qwe/skills|\
            git@github.com:iop098321qwe/skills.git|\
            ssh://git@github.com/iop098321qwe/skills|\
            ssh://git@github.com/iop098321qwe/skills.git) return 0 ;;
            *)
                printf 'sup: origin does not match the skills repository: %s\n' \
                    "$1" >&2
                return 1
                ;;
        esac
    }

    _sup_search() {
        local home=$1 temporary=$2 candidate diagnostic
        # Keep NUL-delimited results out of Gum's output capture.
        if ! find "$home" \( -type d \( -name .cache -o -name node_modules \
            -o -name .venv -o -name .Trash \) -prune \) -o \
            \( -name .git \( -type d -o -type f \) -print0 -prune \) \
            >"$temporary/repositories" 2>"$temporary/search-errors"; then
            while IFS= builtin read -r diagnostic || [[ -n "$diagnostic" ]]; do
                printf '%s\n' "$diagnostic" >&2
            done <"$temporary/search-errors"
            printf 'sup: repository search was incomplete; aborting.\n' >&2
            return 1
        fi
        : >"$temporary/matches" || return 1
        while IFS= builtin read -r -d '' candidate; do
            candidate=${candidate%/.git}
            if _sup_is_repo "$candidate" 2>/dev/null; then
                printf '%s\0' "$candidate" >>"$temporary/matches" || return 1
            fi
        done <"$temporary/repositories"
    }

    _sup_prepare() {
        local repo=$1 commit=$2 temporary=$3
        shift 3
        mkdir -- "$temporary/source" || return 1
        git -C "$repo" archive --format=tar "$commit" -- "$@" \
            ':(glob,exclude)**/todo.txt' >"$temporary/skills.tar" || return 1
        tar -xf "$temporary/skills.tar" -C "$temporary/source" || return 1
        find "$temporary/source" -type l -print0 >"$temporary/links" || return 1
        if [[ -s "$temporary/links" ]]; then
            printf 'sup: source skills contain symlinks; refusing installation.\n' >&2
            return 1
        fi
    }

    _sup_install() {
        local temporary=$1 destination=$2 name skill modified
        shift 2
        : >"$temporary/results" || return 1
        : >"$temporary/install-started" || return 1
        mkdir -p -- "$destination" || return 1
        for name in "$@"; do
            skill="$destination/$name"
            modified=0
            if [[ ! -d "$skill" || -L "$skill" ]]; then modified=1; fi
            if [[ -L "$skill" ]]; then rm -- "$skill" || return 1; fi
            mkdir -p -- "$skill" || return 1
            # Count actual content/metadata changes, not files merely visited.
            rsync -rlpt --checksum --itemize-changes --out-format='%i' \
                --exclude=todo.txt -- "$temporary/source/$name/" "$skill/" \
                >"$temporary/changes" || return 1
            if (( modified )) || [[ -s "$temporary/changes" ]]; then
                printf 'changed\n' >>"$temporary/results" || return 1
            else
                printf 'unchanged\n' >>"$temporary/results" || return 1
            fi
        done
    }

    _sup_stage() {
        stage=$1
        stage_status=''
        shift
        local worker status diagnostic recorded
        : >"$temporary/stage.log" || return 1
        : >"$temporary/stage.status" || return 1
        if (( use_gum )); then
            # Only trusted definitions become source; all data stays in argv.
            worker=$(declare -f _sup_is_repo _sup_search \
                _sup_prepare _sup_install) || return 1
            worker+=$'\n''log=$1; receipt=$2; shift 2
if "$@" >"$log" 2>&1; then status=0; else status=$?; fi
printf "%s\n" "$status" >"$receipt" || exit 1
exit "$status"'
            if gum spin --show-error --title "$stage…" -- \
                bash -c "$worker" skillmod "$temporary/stage.log" \
                "$temporary/stage.status" "$@"; then
                status=0
            else
                status=$?
            fi
            if IFS= builtin read -r recorded <"$temporary/stage.status" && \
                [[ "$recorded" =~ ^[0-9]+$ ]]; then
                if (( status == 0 )); then status=$recorded; fi
            elif (( status == 0 )); then
                printf 'sup: stage did not confirm completion: %s\n' \
                    "$stage" >&2
                status=1
            fi
        else
            printf 'sup: %s…\n' "$stage"
            if "$@" >"$temporary/stage.log" 2>&1; then
                return 0
            else
                status=$?
            fi
        fi
        if (( status == 0 )); then return 0; fi
        stage_status=$status
        if [[ -s "$temporary/stage.log" ]]; then
            while IFS= builtin read -r diagnostic || [[ -n "$diagnostic" ]]; do
                printf '%s\n' "$diagnostic" >&2
            done <"$temporary/stage.log"
        else
            printf 'sup: %s failed with exit status %d; no diagnostics were provided.\n' \
                "$stage" "$status" >&2
        fi
        return "$status"
    }

    temporary=$(mktemp -d "${TMPDIR:-/tmp}/skillmod.XXXXXXXX") || return 1

    stage='Checking expected checkout'
    if [[ -e "$expected" || -L "$expected" ]]; then
        if [[ ! -d "$expected" ]]; then
            printf 'sup: expected checkout is not a directory: %s\n' \
                "$expected" >&2
            return 1
        fi
        if ! _sup_stage 'Checking expected checkout' _sup_is_repo "$expected"; then
            printf 'sup: fix the expected checkout before retrying.\n' >&2
            return 1
        fi
        repo=$expected
    else
        _sup_stage 'Searching for the skills repository' \
            _sup_search "$HOME" "$temporary" || return 1
        while IFS= builtin read -r -d '' repo; do
            matches+=("$repo")
        done <"$temporary/matches"
        if (( ${#matches[@]} > 1 )); then
            printf 'sup: multiple skills repositories found:\n' >&2
            printf '  %s\n' "${matches[@]}" >&2
            printf 'Place the intended checkout at %s and retry.\n' \
                "$expected" >&2
            return 1
        elif (( ${#matches[@]} == 1 )); then
            repo=${matches[0]}
        else
            stage='Cloning skills repository'
            mkdir -p -- "${expected%/*}" || return 1
            _sup_stage "$stage" git clone --single-branch --branch main \
                -- "$url" "$expected" \
                || return 1
            repo=$expected
        fi
    fi

    # Fetch from the canonical URL, even when origin uses another transport.
    # FETCH_HEAD pins this run without changing any local branch or worktree.
    _sup_stage 'Fetching approved main' git -C "$repo" fetch --no-tags \
        -- "$url" refs/heads/main || return 1
    stage='Preparing approved skills'
    commit=$(git -C "$repo" rev-parse --verify 'FETCH_HEAD^{commit}') \
        || return 1
    git -C "$repo" ls-tree -z "$commit" >"$temporary/tree" || return 1
    while IFS= builtin read -r -d '' entry; do
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

    _sup_stage "$stage" _sup_prepare "$repo" "$commit" "$temporary" \
        "${paths[@]}" || return 1
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
    for name in "${skills[@]}"; do
        skill="$destination/$name"
        if [[ -e "$skill" && ! -d "$skill" && ! -L "$skill" ]]; then
            printf 'sup: skill destination is not a directory: %s\n' \
                "$skill" >&2
            return 1
        fi
    done
    _sup_stage 'Installing skills' _sup_install "$temporary" "$destination" \
        "${skills[@]}" || return 1
    _sup_counts
    local heading='Skills already up to date' summary
    if (( changed )); then heading='Skills updated successfully'; fi
    printf -v summary \
        '%s\n\nSkills: %d processed · %d changed · %d unchanged\nDestination: %s\nRepository: %s\nSource: main @ %s' \
        "$heading" "${#skills[@]}" "$changed" "$unchanged" \
        "$destination" "$repo" "$commit"
    if (( ! changed )); then
        summary+=$'\n\nNo updates needed. Your installed skills already match'
        summary+=$'\nthe approved main branch.'
    fi
    _sup_result 42 "$summary" || return 1
    completed=1
    return 0
)
