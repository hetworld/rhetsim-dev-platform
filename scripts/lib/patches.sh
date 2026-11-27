#!/usr/bin/env bash
# Component patch helpers. Callers must source scripts/lib/common.sh first.
#
# Patches are applied to a temporary git worktree at the component commit, so
# repos/ stays clean and instances can build concurrently. The patch set is
# included in the component build ID by the caller.
set -euo pipefail

: "${SHARED_DIR:?source scripts/lib/common.sh before patches.sh}"

# Print patch files from each directory in argument order. Files within one
# directory are sorted lexically.
patch_list() {
    local dir
    for dir in "$@"; do
        [ -n "$dir" ] && [ -d "$dir" ] || continue
        find "$dir" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort
    done
}

# Stable signature of the ordered patch set; "none" when no patches exist.
patch_signature() {
    local files=() f
    mapfile -t files < <(patch_list "$@")
    if [ ${#files[@]} -eq 0 ]; then
        printf 'none'
        return 0
    fi
    {
        for f in "${files[@]}"; do
            printf '%s  %s\n' "$(sha256_of "$f")" "$(basename "$f")"
        done
    } | sha256sum | awk '{print $1}'
}

PATCHED_WORKTREES=()
PATCHED_CLEANUP_INSTALLED=0
PATCHED_SOURCE=""

patched_source_cleanup() {
    local entry repo path
    for entry in "${PATCHED_WORKTREES[@]}"; do
        repo="${entry%%|*}"
        path="${entry#*|}"
        [ -n "$repo" ] && [ -n "$path" ] || continue
        git -C "$repo" worktree remove --force "$path" >/dev/null 2>&1 \
            || rm -rf -- "$path"
        git -C "$repo" worktree prune >/dev/null 2>&1 || true
    done
    PATCHED_WORKTREES=()
}

# prepare_patched_source COMPONENT SRC REF [PATCH_DIR...]
# Set PATCHED_SOURCE to the source tree to build from. Without patches this is
# SRC; with patches it is a temporary worktree at REF with the patches applied
# in order. Must run in the build script's main shell so the EXIT trap and the
# worktree registry survive; do not use it in a command substitution.
prepare_patched_source() {
    local component="$1" src="$2" ref="$3"
    shift 3
    local files=() f repo tmp wt_output
    PATCHED_SOURCE="$src"
    mapfile -t files < <(patch_list "$@")
    if [ ${#files[@]} -eq 0 ]; then
        return 0
    fi
    require_cmd git
    require_cmd mktemp
    git -C "$src" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || die "$component: patches require a git source tree: $src"
    # Applying patches to a dirty worktree would silently drop the changes in
    # the temporary tree. Make the caller commit or stash them first.
    if ! git -C "$src" diff --quiet --ignore-submodules HEAD --; then
        die "$component: cannot apply patches with uncommitted tracked changes in $src"
    fi
    repo="$(git -C "$src" rev-parse --show-toplevel)"
    mkdir -p "$SHARED_DIR/tmp"
    tmp="$(mktemp -d "$SHARED_DIR/tmp/patch-$component.XXXXXX")"
    rmdir -- "$tmp"
    # The large Linux checkout prints thousands of "Updating files" progress
    # lines on stderr; keep them out of the normal build log.
    if ! wt_output="$(git -C "$repo" worktree add --detach "$tmp" "$ref" 2>&1)"; then
        printf '%s\n' "$wt_output" >&2
        rm -rf -- "$tmp"
        die "$component: failed to create a temporary worktree at $ref"
    fi
    for f in "${files[@]}"; do
        if ! git -C "$tmp" apply --whitespace=nowarn "$f"; then
            git -C "$repo" worktree remove --force "$tmp" >/dev/null 2>&1 \
                || rm -rf -- "$tmp"
            git -C "$repo" worktree prune >/dev/null 2>&1 || true
            die "$component: failed to apply patch $(basename "$f")"
        fi
    done
    PATCHED_WORKTREES+=("$repo|$tmp")
    if [ "$PATCHED_CLEANUP_INSTALLED" -eq 0 ]; then
        # shellcheck disable=SC2064
        trap patched_source_cleanup EXIT
        PATCHED_CLEANUP_INSTALLED=1
    fi
    PATCHED_SOURCE="$tmp"
}
