#!/usr/bin/env bash
#
# Install manage-worktree-workspace skill (and optionally the plan rule) into Cursor.
#
# Usage:
#   ./install.sh              # skill only
#   ./install.sh --with-rule  # skill + always-apply plan rule
#   ./install.sh --uninstall  # remove symlinks created by this script
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$REPO_ROOT/skills/manage-worktree-workspace"
RULE_SRC="$REPO_ROOT/rules/plan-worktree-setup.mdc"

SKILLS_DIR="${CURSOR_SKILLS_DIR:-$HOME/.cursor/skills}"
RULES_DIR="${CURSOR_RULES_DIR:-$HOME/.cursor/rules}"

SKILL_DEST="$SKILLS_DIR/manage-worktree-workspace"
LEGACY_SKILL_DEST="$SKILLS_DIR/create-worktree-workspace"
RULE_DEST="$RULES_DIR/plan-worktree-setup.mdc"

WITH_RULE=0
UNINSTALL=0

usage() {
  sed -n '3,10p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-rule) WITH_RULE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

link_or_replace() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" || -e "$dest" ]]; then
    rm -rf "$dest"
  fi
  ln -s "$src" "$dest"
  echo "linked: $dest -> $src"
}

remove_symlink() {
  local dest="$1"
  if [[ -L "$dest" ]]; then
    rm "$dest"
    echo "removed: $dest"
  else
    echo "skip (not a symlink or missing): $dest"
  fi
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  remove_symlink "$SKILL_DEST"
  remove_symlink "$LEGACY_SKILL_DEST"
  if [[ -L "$RULE_DEST" ]]; then
    rm "$RULE_DEST"
    echo "removed: $RULE_DEST"
  else
    echo "skip (not a symlink or missing): $RULE_DEST"
  fi
  exit 0
fi

[[ -d "$SKILL_SRC" ]] || { echo "error: skill not found at $SKILL_SRC" >&2; exit 1; }
[[ -x "$SKILL_SRC/scripts/manage-worktree-workspace.sh" ]] || \
  chmod +x "$SKILL_SRC/scripts/manage-worktree-workspace.sh"

link_or_replace "$SKILL_SRC" "$SKILL_DEST"
if [[ -L "$LEGACY_SKILL_DEST" || -e "$LEGACY_SKILL_DEST" ]]; then
  rm -rf "$LEGACY_SKILL_DEST"
  echo "removed legacy skill: $LEGACY_SKILL_DEST"
fi

if [[ "$WITH_RULE" -eq 1 ]]; then
  [[ -f "$RULE_SRC" ]] || { echo "error: rule not found at $RULE_SRC" >&2; exit 1; }
  link_or_replace "$RULE_SRC" "$RULE_DEST"
  echo
  echo "Installed skill + always-apply plan rule."
else
  echo
  echo "Installed skill only."
  echo "Optional: re-run with --with-rule to also install plan-worktree-setup.mdc"
fi

echo
echo "Try it:"
echo "  $SKILL_DEST/scripts/manage-worktree-workspace.sh --repo sentry --branch feat/try-worktree"
echo
echo "Or in Cursor: ask the agent to use the manage-worktree-workspace skill."
echo "Repos: CODE_ROOT=\$HOME/code (override if your checkouts live elsewhere)."
