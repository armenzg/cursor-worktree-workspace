#!/usr/bin/env bash
#
# create-worktree-workspace.sh
#
# Create (or reuse) a git worktree, write a scoped .code-workspace file, and
# optionally open it in a new Cursor window.
#
# Usage:
#   create-worktree-workspace.sh --repo getsentry --branch feat/my-thing
#   create-worktree-workspace.sh --repo sentry --branch fix/foo --sibling relay
#   create-worktree-workspace.sh --repo getsentry --path ~/code/getsentry-armenzg-foo --open-only
#
# Options:
#   --repo REPO          getsentry | sentry | seer (required unless --open-only with --path)
#   --branch BRANCH      branch to create or check out (required unless --open-only)
#   --base BASE          base ref for new branches (default: remote default branch)
#   --path PATH          explicit worktree path (default: ~/code/<repo>-<branch-slug>)
#   --sibling NAME       add sibling repo folder (repeatable; getsentry defaults to sentry)
#   --no-siblings        do not add default siblings
#   --open-only          skip worktree creation; only write/open workspace for --path
#   --plan PATH          copy plan into worktree .cursor/plans/ and open it with the workspace
#   --no-open            write workspace file but do not launch Cursor
#   -h, --help           show this help

set -euo pipefail

CODE_ROOT="${CODE_ROOT:-$HOME/code}"
WORKSPACES_DIR="${WORKSPACES_DIR:-$CODE_ROOT/workspaces}"

REPO=""
BRANCH=""
BASE=""
WORKTREE_PATH=""
OPEN_ONLY=0
NO_OPEN=0
NO_SIBLINGS=0
PLAN_PATH=""
PLAN_DEST=""
declare -a SIBLINGS=()

usage() {
  sed -n '3,22p' "$0"
}

die() {
  echo "error: $*" >&2
  exit 1
}

slugify_branch() {
  # feat/quota-exceeded -> feat-quota-exceeded
  echo "$1" | tr '/' '-'
}

default_branch() {
  local repo_path="$1"
  local remote
  remote="$(git -C "$repo_path" remote | grep -qx origin && echo origin || git -C "$repo_path" remote | head -1 || true)"
  if [[ -z "$remote" ]]; then
    echo "master"
    return
  fi
  git -C "$repo_path" symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null \
    | sed "s|refs/remotes/$remote/||" | tr -d '[:space:]' || echo "master"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --base) BASE="${2:-}"; shift 2 ;;
    --path) WORKTREE_PATH="${2:-}"; shift 2 ;;
    --sibling) SIBLINGS+=("${2:-}"); shift 2 ;;
    --no-siblings) NO_SIBLINGS=1; shift ;;
    --open-only) OPEN_ONLY=1; shift ;;
    --plan) PLAN_PATH="${2:-}"; shift 2 ;;
    --no-open) NO_OPEN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

if [[ "$OPEN_ONLY" -eq 1 ]]; then
  [[ -n "$WORKTREE_PATH" ]] || die "--open-only requires --path"
else
  [[ -n "$REPO" ]] || die "--repo is required"
  [[ -n "$BRANCH" ]] || die "--branch is required"
  case "$REPO" in
    getsentry|sentry|seer) ;;
    *) die "--repo must be getsentry, sentry, or seer" ;;
  esac
fi

MAIN_REPO="$CODE_ROOT/$REPO"
if [[ "$OPEN_ONLY" -eq 0 && ! -d "$MAIN_REPO/.git" ]]; then
  die "main checkout not found at $MAIN_REPO"
fi

if [[ -n "$PLAN_PATH" ]]; then
  PLAN_PATH="${PLAN_PATH/#\~/$HOME}"
  [[ -f "$PLAN_PATH" ]] || die "plan file not found: $PLAN_PATH (use the real path, e.g. ~/.cursor/plans/<name>.plan.md — not the WORKTREE placeholder)"
fi

if [[ -z "$WORKTREE_PATH" ]]; then
  slug="$(slugify_branch "$BRANCH")"
  WORKTREE_PATH="$CODE_ROOT/${REPO}-${slug}"
fi

# Expand ~ for comparisons and git.
WORKTREE_PATH="${WORKTREE_PATH/#\~/$HOME}"

if [[ "$NO_SIBLINGS" -eq 0 && ${#SIBLINGS[@]} -eq 0 ]]; then
  case "$REPO" in
    getsentry) SIBLINGS=("sentry") ;;
  esac
fi

if [[ "$OPEN_ONLY" -eq 0 ]]; then
  if [[ -d "$WORKTREE_PATH/.git" || -f "$WORKTREE_PATH/.git" ]]; then
    echo "worktree already exists at $WORKTREE_PATH"
  else
    if [[ -z "$BASE" ]]; then
      BASE="$(default_branch "$MAIN_REPO")"
    fi
    echo "creating worktree at $WORKTREE_PATH (branch=$BRANCH base=$BASE)"
    git -C "$MAIN_REPO" fetch origin --quiet || true
    if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/$BRANCH"; then
      git -C "$MAIN_REPO" worktree add "$WORKTREE_PATH" "$BRANCH"
    else
      if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
        git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE_PATH" "origin/$BASE"
      else
        git -C "$MAIN_REPO" worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE"
      fi
    fi
  fi
else
  [[ -d "$WORKTREE_PATH" ]] || die "worktree path does not exist: $WORKTREE_PATH"
fi

basename="$(basename "$WORKTREE_PATH")"
WORKSPACE_FILE="$WORKSPACES_DIR/${basename}.code-workspace"
mkdir -p "$WORKSPACES_DIR"

# Paths in the workspace file are relative to WORKSPACES_DIR.
worktree_rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$WORKTREE_PATH" "$WORKSPACES_DIR")"

{
  echo '{'
  echo '  "folders": ['
  echo '    {'
  echo "      \"path\": \"$worktree_rel\""
  echo '    }'
  for sibling in "${SIBLINGS[@]}"; do
    sibling_path="$CODE_ROOT/$sibling"
    [[ -d "$sibling_path" ]] || die "sibling repo not found: $sibling_path"
    sibling_rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$sibling_path" "$WORKSPACES_DIR")"
    echo '    ,{'
    echo "      \"path\": \"$sibling_rel\""
    echo '    }'
  done
  echo '  ],'
  echo '  "settings": {'
  echo '    "search.followSymlinks": false'
  echo '  }'
  echo '}'
} > "$WORKSPACE_FILE"

if [[ -n "$PLAN_PATH" ]]; then
  plan_dest_dir="$WORKTREE_PATH/.cursor/plans"
  mkdir -p "$plan_dest_dir"
  PLAN_DEST="$plan_dest_dir/$(basename "$PLAN_PATH")"
  cp "$PLAN_PATH" "$PLAN_DEST"
  echo "plan: $PLAN_DEST"
fi

echo "worktree: $WORKTREE_PATH"
echo "workspace: $WORKSPACE_FILE"

if [[ "$NO_OPEN" -eq 0 ]]; then
  open_args=("$WORKSPACE_FILE")
  if [[ -n "$PLAN_DEST" ]]; then
    open_args+=("$PLAN_DEST")
  fi
  if command -v cursor >/dev/null 2>&1; then
    echo "opening Cursor in a new window..."
    cursor -n "${open_args[@]}"
  else
    echo "cursor CLI not found; open manually:"
    echo "  cursor -n ${open_args[*]}"
  fi
fi
