# cursor-worktree-workspace

Cursor plugin (skill + optional plan rule + script) to create an isolated git
worktree, write a scoped `.code-workspace` file, and open it in a new Cursor
window.

Aimed at Sentry-style layouts (`getsentry`, `sentry`, `seer` under `$HOME/code`),
but paths are configurable via `CODE_ROOT`.

## Why

Working from a multi-repo Cursor workspace often forces the agent to elevate
shell permissions. A single-repo (or minimal-sibling) worktree workspace keeps
most commands inside the checkout.

## Install in Cursor (coworkers)

This is a **Cursor Plugin**. Cursor does not load a GitHub skill folder on its
own — install the plugin, then the skill (and rule) show up in Customize.

Repo URL:

```text
https://github.com/armenzg/cursor-worktree-workspace
```

### Option A — Customize → From GitHub (recommended)

1. Open **Customize** in the Cursor sidebar.
2. Add a marketplace **From GitHub Repository**.
3. Paste `https://github.com/armenzg/cursor-worktree-workspace`.
4. Install the **create-worktree-workspace** plugin (user or project scope).
5. Confirm in Customize → Skills that `create-worktree-workspace` is listed.
   The plan rule `plan-worktree-setup` appears with other rules.

CLI equivalent (Cursor CLI):

```bash
agent plugin marketplace add https://github.com/armenzg/cursor-worktree-workspace
```

Then install **create-worktree-workspace** from `/plugin` or Customize.

### Option B — Team marketplace

If your org uses Cursor Teams/Enterprise and this repo is already imported as a
team marketplace, skip the GitHub URL:

1. Open **Customize**.
2. Find **create-worktree-workspace** under the team marketplace.
3. Install it (unless an admin already set it to Default On or Required).

### Option C — Clone + symlink (local, no plugin)

Use this when you want `git pull` to update the skill immediately on your
machine, without a marketplace:

```bash
git clone git@github.com:armenzg/cursor-worktree-workspace.git ~/code/cursor-worktree-workspace
~/code/cursor-worktree-workspace/install.sh --with-rule
```

`install.sh` (no flag) links only the skill. `--with-rule` also links the
always-apply plan rule. Uninstall:

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

After install, in Cursor chat:

> Use the create-worktree-workspace skill for a `feat/try-worktree` branch in sentry

Or run the script (path depends on how you installed):

```bash
# plugin install: Cursor copies the plugin under ~/.cursor/plugins/…
# local symlink:
~/.cursor/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh \
  --repo sentry \
  --branch feat/try-worktree
```

## Publish and keep it up to date

Plugins are the git repository. There is no separate zip to rebuild. After
changing skills, rules, or scripts, merge to the branch the marketplace tracks
(usually `main`).

### You (maintainer)

1. Keep `.cursor-plugin/plugin.json` and `.cursor-plugin/marketplace.json` in
   the repo (required for GitHub / team marketplace import).
2. Bump `version` in `.cursor-plugin/plugin.json` when the behavior changes in
   a way installers should notice.
3. Push to GitHub.

**Team marketplace (Sentry / other Teams orgs)**

1. Dashboard → **Plugins & MCPs** → **Add Marketplace** → **Import from Repo**.
2. Paste this repository URL, add **create-worktree-workspace** to the
   marketplace, save.
3. Under Marketplace Settings, turn on **Enable Auto Refresh** and install the
   [Cursor GitHub App](https://cursor.com/docs/plugins) on this repo.
4. Optional: set the plugin to Default On or Required so coworkers get it
   without a manual install.

After that, a push to the tracked branch is the release. Cursor re-indexes at
most every 10 minutes. Use **Refresh** in the dashboard if you need it sooner.

To update a skill you published from Customize → Skills → **Publish** (personal
skill, not this git repo), use **Sync changes** in Customize instead. Prefer
the GitHub import above so this repository stays the source of truth.

**Public Cursor Marketplace**

1. Repo must be public and open source.
2. Submit at [cursor.com/marketplace/publish](https://cursor.com/marketplace/publish).
3. Cursor reviews the listing. **Each later update is reviewed too** — public
   users do not get new commits until that review lands.

### Coworkers (after the first install)

- **GitHub / team marketplace:** reopen Customize or wait for auto-refresh;
  you should not need to re-install.
- **Clone + `install.sh`:** `git -C ~/code/cursor-worktree-workspace pull`.

## What’s included

```text
.cursor-plugin/
  plugin.json                           # Cursor Plugin manifest
  marketplace.json                      # lets Customize import this repo
skills/create-worktree-workspace/
  SKILL.md                              # agent instructions
  scripts/create-worktree-workspace.sh  # worktree + workspace helper
rules/plan-worktree-setup.mdc           # optional always-apply plan rule
install.sh                              # local ~/.cursor/skills symlink
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

Install the optional rule (`install.sh --with-rule`, or install the plugin)
if you want the agent to add this automatically for implementation plans.

## Related local tooling

This repo is the shareable subset of a personal workflow. Cleanup/pruning of old
worktrees is intentionally not included here yet.

Docs: [Plugins](https://cursor.com/docs/plugins) ·
[Plugins reference](https://cursor.com/docs/reference/plugins) ·
[Skills](https://cursor.com/docs/skills)
