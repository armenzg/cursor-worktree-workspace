# cursor-worktree-workspace

Cursor skill + script to create an isolated git worktree, write a scoped
`.code-workspace` file, and open it in a new Cursor window.

Aimed at Sentry-style layouts (`getsentry`, `sentry`, `seer` under `$HOME/code`),
but paths are configurable via `CODE_ROOT`.

## Why

Working from a multi-repo Cursor workspace often forces the agent to elevate
shell permissions. A single-repo (or minimal-sibling) worktree workspace keeps
most commands inside the checkout.

## Install

```bash
git clone git@github.com:armenzg/cursor-worktree-workspace.git ~/code/cursor-worktree-workspace
~/code/cursor-worktree-workspace/install.sh
```

This symlinks the skill into `~/.cursor/skills/create-worktree-workspace`.

Optional always-apply rule (plans auto-include a `worktree` block):

```bash
~/code/cursor-worktree-workspace/install.sh --with-rule
```

Uninstall:

```bash
~/code/cursor-worktree-workspace/install.sh --uninstall
```

### Layout assumptions

| Variable | Default | Purpose |
|----------|---------|---------|
| `CODE_ROOT` | `$HOME/code` | Main checkouts + worktrees |
| `WORKSPACES_DIR` | `$CODE_ROOT/workspaces` | Generated `.code-workspace` files |

Example if repos live elsewhere:

```bash
export CODE_ROOT="$HOME/src"
```

For **getsentry**, keep a `sentry` checkout as a sibling under `CODE_ROOT` so
the worktree `.venv` symlink resolves.

## Try it

```bash
~/.cursor/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh \
  --repo sentry \
  --branch feat/try-worktree
```

Or in Cursor chat:

> Use the create-worktree-workspace skill for a `feat/try-worktree` branch in sentry

## What’s included

```text
skills/create-worktree-workspace/
  SKILL.md                              # agent instructions
  scripts/create-worktree-workspace.sh  # worktree + workspace helper
rules/plan-worktree-setup.mdc           # optional always-apply plan rule
install.sh
```

## Script options

```text
--repo REPO          getsentry | sentry | seer
--branch BRANCH      create or check out this branch
--base BASE          base ref for new branches (default: remote default)
--path PATH          explicit worktree path
--sibling NAME       extra sibling folder (repeatable; getsentry defaults to sentry)
--no-siblings        skip default siblings
--plan PATH          copy plan into worktree and open it with the workspace
--open-only          skip worktree creation; write/open workspace for --path
--no-open            do not launch Cursor
```

## Plan convention

Implementation plans can include:

```yaml
worktree:
  repo: getsentry
  branch: feat/my-feature
todos:
  - id: worktree-setup
    content: Create worktree and open scoped Cursor workspace
    status: pending
```

Install the optional rule (`--with-rule`) if you want the agent to add this
automatically for implementation plans.

## Related local tooling

This repo is the shareable subset of a personal workflow. Cleanup/pruning of old
worktrees is intentionally not included here yet.
