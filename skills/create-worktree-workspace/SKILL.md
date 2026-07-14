---
name: create-worktree-workspace
description: Create a git worktree, generate a scoped Cursor workspace, and open it in a new window. Use when planning or starting feature work, when a plan includes worktree setup or a worktree-setup todo, or when the user asks to work in an isolated worktree workspace instead of the multi-repo sandbox. If the plan has no worktree block, propose repo/branch from context and create after a brief confirmation.
---

# Create Worktree Workspace

Spin up an isolated git worktree and open a dedicated Cursor window scoped to that worktree. This keeps agent shell commands inside the worktree checkout so fewer commands need sandbox elevation.

Pair this skill with Cursor plans: add a `worktree` block and a first todo for setup, then run implementation in the new window.

## Script location

The companion script ships with this skill:

```text
~/.cursor/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh
```

If that path does not exist, fall back to the clone path from install:

```text
$REPO_ROOT/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh
```

Override checkout layout with `CODE_ROOT` (default: `$HOME/code`) and `WORKSPACES_DIR` (default: `$CODE_ROOT/workspaces`).

## When to use

- Starting a new branch for getsentry, sentry, or seer
- A plan's first step is "create worktree + open workspace"
- The multi-repo workspace is the wrong cwd (agent keeps hitting sandbox limits)
- Parallel work without disturbing the main checkout

## Quick start

```bash
SCRIPT="$HOME/.cursor/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh"

"$SCRIPT" \
  --repo getsentry \
  --branch feat/my-feature \
  --plan ~/.cursor/plans/my-feature_<id>.plan.md
```

`--plan` must be a real file path (typically `~/.cursor/plans/<name>_<id>.plan.md` from Cursor's plan tool). Do not pass the literal placeholder `WORKTREE/...`.

When `--plan` is set, the script copies the plan into the worktree’s `.cursor/plans/` and opens that file in the new Cursor window alongside the workspace (`cursor -n WORKSPACE.code-workspace PLAN.plan.md`).

Open an existing worktree without recreating it:

```bash
"$SCRIPT" \
  --repo getsentry \
  --path "$HOME/code/getsentry-feat-my-feature" \
  --open-only
```

The script prints the worktree path and workspace file. It opens Cursor in a new window when `--no-open` is not passed.

## Plan authoring convention

When creating a Cursor plan (`.cursor/plans/*.plan.md`), include a `worktree` block in the YAML frontmatter and make setup the first todo:

```yaml
---
name: my feature
overview: ...
worktree:
  repo: getsentry          # getsentry | sentry | seer
  branch: feat/my-feature  # branch to create (or existing branch to check out)
  base: master             # optional; default: remote default branch
  siblings:                # optional extra folders in the workspace
    - sentry
    - options
todos:
  - id: worktree-setup
    content: Create worktree and open scoped Cursor workspace (run create-worktree-workspace skill)
    status: pending
  - id: implement-change
    content: ...
    status: pending
---
```

In the plan body, add a short **Worktree setup** section with the exact command:

```markdown
## Worktree setup

Run in the planning workspace (or any checkout of the main repo):

\`\`\`bash
$HOME/.cursor/skills/create-worktree-workspace/scripts/create-worktree-workspace.sh \
  --repo getsentry \
  --branch feat/my-feature \
  --plan ~/.cursor/plans/my-feature_<id>.plan.md
\`\`\`

Use the actual plan file path from the plan tool output, not `WORKTREE/...`.

Continue implementation in the new Cursor window. All shell commands should use the worktree as cwd.
```

After the worktree exists, copy the plan if `--plan` was not used:

```bash
mkdir -p WORKTREE/.cursor/plans
cp PLAN_PATH WORKTREE/.cursor/plans/
```

## Workflow (agent steps)

1. Resolve `repo` + `branch` (see **Missing worktree block** below). Prefer the plan's `worktree` frontmatter when present.
2. Run `create-worktree-workspace.sh`. Pass `--plan` when the plan file exists. Use `required_permissions: ["all"]` — the script writes under `$CODE_ROOT` and launches Cursor.
3. Tell the user to continue in the new Cursor window. Do not implement feature todos in the planning workspace once the worktree window is open.
4. In the worktree window, verify context:
   ```bash
   git branch --show-current
   pwd
   test -L .venv && readlink .venv   # getsentry: should point at ../sentry/.venv
   ```
5. Mark `worktree-setup` complete and proceed with remaining todos.

## Missing worktree block

When the user invokes this skill (or a plan has a `worktree-setup` todo) but the plan has no `worktree:` frontmatter — including research/findings-only plans — **propose** defaults; do not stall on an open-ended ask.

### Infer defaults

1. **repo** (first match wins):
   - Explicit user choice in the current turn
   - Dominant code path in the plan/conversation (`getsentry/…` → `getsentry`, `src/sentry/…` → `sentry`, seer paths → `seer`)
   - Active workspace folder among `getsentry` | `sentry` | `seer`
   - Fall back to `getsentry` only when the conversation clearly centers on SaaS/billing there
2. **branch**:
   - Prefer `feat/<plan-slug>` from the plan file basename (strip trailing `_<id>`, replace `_` with `-`)
   - Else from plan `name` / overview slug, kebab-case, prefixed with `feat/`
   - Keep under ~50 chars; drop filler words if needed
3. **plan path**: the active `.plan.md` when one is in context; pass it as `--plan`
4. **siblings / base**: use script defaults unless the user or plan specified them

### Confirm once, then create

Show a short proposal, then run the script unless the user corrects it:

```text
Proposed worktree:
  repo: getsentry
  branch: feat/tally-usage-invalidation-gate
  plan: ~/.cursor/plans/tally_usage_invalidation_gate_15a7b6f6.plan.md

Creating unless you change repo/branch.
```

Only ask when inference is ambiguous (e.g. plan touches multiple primary repos with no clear owner). Offer 1–2 concrete choices, not a blank “which repo/branch?”.

### Optional: backfill the plan

If a plan file exists and this invocation is starting implementation, add/update its `worktree:` block and a `worktree-setup` todo to match what you created. Skip backfill for pure research plans the user is not turning into implementation.

## Path conventions

Assumes checkouts under `$CODE_ROOT` (default `$HOME/code`):

| Repo | Main checkout | Worktree path pattern |
|------|---------------|------------------------|
| getsentry | `$CODE_ROOT/getsentry` | `$CODE_ROOT/getsentry-<branch-with-slashes-as-dashes>` |
| sentry | `$CODE_ROOT/sentry` | `$CODE_ROOT/sentry-<branch-with-slashes-as-dashes>` |
| seer | `$CODE_ROOT/seer` | `$CODE_ROOT/seer-<branch-with-slashes-as-dashes>` |

Workspace files live in `$CODE_ROOT/workspaces/<worktree-basename>.code-workspace`.

## Default workspace folders

| Repo | Primary folder | Default siblings |
|------|----------------|------------------|
| getsentry | worktree | `sentry` (required for imports + `.venv` symlink) |
| sentry | worktree | none |
| seer | worktree | none |

Override siblings with `--sibling sentry --sibling options` or the plan's `worktree.siblings` list.

## Post-checkout hooks

Worktrees auto-provision dev env on creation:

- **sentry**: `devenv sync` runs via `config/hooks/post-checkout` (own `.venv`)
- **getsentry**: `config/hooks/post-checkout` symlinks `.venv` → `../sentry/.venv`
- **seer**: run `devenv sync` manually if `.venv` is missing after add

If hooks did not run, from the worktree:

```bash
cd WORKTREE && devenv sync && direnv allow
```

## Cleanup

Before removing a worktree you are done with:

```bash
git -C "$CODE_ROOT/REPO" worktree remove PATH
```

## Notes

- Prefer a **single-repo or minimal-sibling** workspace over the full multi-repo workspace. Smaller workspace roots mean the agent cwd stays in the worktree.
- `cursor -n WORKSPACE.code-workspace [PLAN.plan.md]` opens a new window (and the plan tab when `--plan` was used); use `--no-open` when driving setup from a script and opening manually.
- Opening a `.plan.md` path opens it as an editor tab; it may not enter Cursor’s Plan UI automatically.
- Getsentry worktrees must keep `../sentry` as a sibling so the `.venv` symlink resolves.
