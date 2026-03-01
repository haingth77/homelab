---
name: cursor-agent
description: Senior lead agent — Cursor CLI bridge for AI-assisted code generation, PR review authority for junior sub-agents, and technical direction. Covers CLI automation, tmux TTY workaround, handoff protocol, and the PR review workflow.
metadata:
  {
    "openclaw":
      {
        "emoji": "🖥️",
        "requires": { "anyBins": ["tmux"] },
      },
  }
---

# Cursor CLI Agent Bridge (Senior Lead)

Use the Cursor CLI to perform AI-assisted code generation, review, refactoring, and debugging from within the OpenClaw agent environment. As the senior lead, you also review PRs from junior sub-agents and provide technical direction on multi-agent tasks.

## Prerequisites

Before using this skill, ensure the following are available in the agent's environment:

| Dependency | Purpose | Install |
|---|---|---|
| `agent` (Cursor CLI) | AI code generation engine | `curl https://cursor.com/install -fsS \| bash` |
| `tmux` | TTY emulation for automated CLI invocation | `apt install tmux` / `brew install tmux` |
| `CURSOR_API_KEY` | Authentication for headless environments | Set as env var (synced from Infisical via ESO) |
| `git`, `gh` | Git operations and PR creation | Already in the OpenClaw image |

### Authentication

In headless/container environments where browser-based login is not possible, use an API key:

```bash
export CURSOR_API_KEY=<key-from-infisical>
```

For interactive environments (host machine):

```bash
agent login
```

## Cursor CLI Reference

### Commands

| Command | Purpose |
|---|---|
| `agent` | Start interactive session |
| `agent "<prompt>"` | Start session with initial prompt |
| `agent -p '<prompt>'` | Non-interactive mode (prints output, exits) |
| `agent -p '<prompt>' --force` | Non-interactive with auto-apply (no confirmation) |
| `agent -p '<prompt>' --output-format json` | Structured JSON output |
| `agent -p '<prompt>' --output-format stream-json` | Streaming JSON output |
| `agent -p '<prompt>' --model <model>` | Use a specific model |
| `agent models` | List available models |
| `agent ls` | List sessions |
| `agent resume` | Resume most recent session |
| `agent --resume="<chat-id>"` | Resume specific session |
| `agent update` | Update CLI to latest version |
| `agent --version` | Check installed version |

### Context selection

Include files or directories in the conversation:

```
@filename.ts
@src/components/
```

### Slash commands (interactive mode)

| Command | Purpose |
|---|---|
| `/models` | Switch AI model |
| `/compress` | Summarize conversation, free context window |
| `/rules` | Create/edit Cursor rules |
| `/commands` | Create/modify custom commands |
| `/mcp enable <server>` | Enable an MCP server |
| `/mcp disable <server>` | Disable an MCP server |

## Handoff Protocol

The handoff protocol defines how OpenClaw passes tasks to the Cursor CLI and receives results back.

### Overview

```
OpenClaw (homelab-admin)
  └── sessions_spawn → cursor-agent (senior lead)
        │
        ├── Code generation path:
        │     ├── 1. Receive task description + target repo
        │     ├── 2. Setup workspace (clone repo, create branch)
        │     ├── 3. Invoke Cursor CLI (tmux or non-interactive)
        │     ├── 4. Review generated changes (git diff)
        │     ├── 5. Commit with agent footprint
        │     ├── 6. Push + create PR
        │     └── 7. Report results back via sessions_announce
        │
        ├── PR review path:
        │     ├── 1. Receive PR number from orchestrator
        │     ├── 2. Fetch diff and review against checklist
        │     ├── 3. Post verdict (approve / request changes / reject)
        │     └── 4. Report verdict to orchestrator
        │
        └── Multi-agent coordination path:
              ├── 1. Decompose task into sub-tasks
              ├── 2. Spawn junior agents with acceptance criteria
              ├── 3. Review each sub-agent's PR
              └── 4. Report integrated status to orchestrator
```

### Task input format

When the orchestrator spawns the cursor-agent, it provides:

1. **Task description** — what code to generate/modify
2. **Target repository** — `holdennguyen/homelab` or `holdennguyen/<product>`
3. **Target files/directories** — specific paths to focus on
4. **Constraints** — language, framework, style requirements
5. **Issue number** — existing GitHub issue to reference (if any)

### Result output format

The cursor-agent reports back:

1. **Summary** — what was generated/changed
2. **Files modified** — list of changed files with brief descriptions
3. **PR URL** — link to the created pull request
4. **Quality notes** — any concerns, TODOs, or areas needing human review

## Execution Modes

### Mode 1: Non-interactive (simple tasks)

For straightforward, single-prompt tasks that don't require iterative refinement:

```bash
cd /data/workspaces/cursor-agent/<repo>
agent -p 'Create a Python script that validates YAML files in k8s/apps/' --force
```

Use `--force` to auto-apply changes without confirmation. Use `--output-format json` when structured output is needed for parsing.

### Mode 2: tmux automation (complex tasks)

For tasks requiring iterative refinement or multi-step prompts. The Cursor CLI requires a real TTY — direct subprocess invocation hangs indefinitely.

```bash
SESSION="cursor-task"

tmux kill-session -t "${SESSION}" 2>/dev/null || true
tmux new-session -d -s "${SESSION}"

tmux send-keys -t "${SESSION}" "cd /data/workspaces/cursor-agent/<repo>" Enter
sleep 1

tmux send-keys -t "${SESSION}" "agent 'Implement the feature described in issue #42'" Enter

# Poll for completion (check for prompt return)
while true; do
  OUTPUT=$(tmux capture-pane -t "${SESSION}" -p)
  if echo "${OUTPUT}" | grep -q '^\$'; then
    break
  fi
  sleep 5
done

# Capture the final output
tmux capture-pane -t "${SESSION}" -p -S -1000 > /tmp/cursor-output.txt

tmux kill-session -t "${SESSION}"
```

### Mode 3: Iterative refinement

For tasks where the initial output needs adjustment:

```bash
SESSION="cursor-refine"
tmux new-session -d -s "${SESSION}"
tmux send-keys -t "${SESSION}" "cd /data/workspaces/cursor-agent/<repo>" Enter
sleep 1

# Initial generation
tmux send-keys -t "${SESSION}" "agent 'Create a REST API handler for /api/health'" Enter
# Wait for completion...

# Follow-up refinement (resume most recent session with a new prompt)
tmux send-keys -t "${SESSION}" "agent resume 'Add input validation and error handling'" Enter
# Wait for completion...
```

## Standard Workflow

This is the end-to-end workflow for a code generation task.

### 1. Setup workspace

```bash
cd /data/workspaces/cursor-agent
REPO="holdennguyen/<target-repo>"
DIR="<target-repo>"
gh repo clone "${REPO}" "${DIR}" 2>/dev/null || (cd "${DIR}" && git checkout main && git pull origin main)
cd "${DIR}"
git config user.name "cursor-agent[bot]"
git config user.email "cursor-agent@openclaw.homelab"
```

### 2. Create branch

```bash
git checkout main && git pull origin main
git checkout -b cursor-agent/feat/<issue-number>-<short-description>
```

### 3. Invoke Cursor CLI

Choose the appropriate execution mode based on task complexity:

```bash
# Simple task
agent -p 'Implement <task description> following the existing code patterns' --force

# Complex task (use tmux)
# See Mode 2 above
```

### 4. Review changes

Always review generated code before committing:

```bash
git diff
git diff --stat
```

Check for:

- Secrets or credentials accidentally included
- Code style consistency with the target repo
- Tests included alongside implementation
- No unrelated file modifications

### 5. Commit and push

```bash
git add <files>
git commit -m "feat: <description> (#<issue-number>) [cursor-agent]"

git fetch origin main
git merge origin/main --no-edit

git push -u origin HEAD
```

### 6. Create PR

```bash
gh pr create \
  --title "feat: <description>" \
  --label "agent:cursor-agent,type:feat,area:<area>,priority:<priority>" \
  --assignee holdennguyen \
  --milestone "<current-milestone>" \
  --repo "${REPO}" \
  --body "$(cat <<'PREOF'
Closes #<issue-number>

## Summary
- <what was generated and why>
- Generated via Cursor CLI (`agent -p` / tmux session)
- Implementation plan: #<issue-number> (comment)

## Test plan
- [ ] Code review by human or software-engineer agent
- [ ] Linting and tests pass
- [ ] No secrets in diff

---
Agent: cursor-agent | OpenClaw Homelab
PREOF
)"
```

### 7. Report results

Announce the results back to the orchestrator:

```
Task complete.
- PR: <url>
- Files changed: <list>
- Summary: <what was done>
- Review notes: <any concerns or TODOs>
```

## PR Review Protocol

As the senior lead, you review PRs created by junior sub-agents (devops-sre, software-engineer, security-analyst, qa-tester) before they go to human review.

### Review workflow

```
Junior agent creates PR
  └── orchestrator routes PR to cursor-agent for review
        ├── 1. Fetch the PR diff: gh pr diff <number> --repo holdennguyen/homelab
        ├── 2. Read changed files for full context
        ├── 3. Run review checklist (see below)
        ├── 4. Post review comment via gh pr review
        └── 5. Report verdict to orchestrator
```

### Review commands

```bash
# Fetch PR metadata
gh pr view <number> --repo holdennguyen/homelab --json title,body,files,labels

# Fetch the diff
gh pr diff <number> --repo holdennguyen/homelab

# Approve
gh pr review <number> --repo holdennguyen/homelab --approve --body "LGTM. <summary of what was checked>"

# Request changes
gh pr review <number> --repo holdennguyen/homelab --request-changes --body "<specific issues and fix instructions>"

# Comment without verdict
gh pr review <number> --repo holdennguyen/homelab --comment --body "<questions or observations>"
```

### Review checklist

| Category | Check |
|---|---|
| **Secrets** | No API keys, tokens, passwords, or credentials in the diff |
| **Conventions** | Code follows existing patterns and style in the target repo |
| **Manifests** | Valid YAML syntax, correct indentation, no unknown Helm value keys |
| **Documentation** | Docs updated alongside implementation (README, service docs, security report) |
| **Agent footprint** | Commit author, branch prefix, PR labels, and footer follow conventions |
| **Scope** | No unrelated file modifications; changes match the issue description |
| **Security** | RBAC changes, network policy changes, new secrets assessed for blast radius |
| **Sync waves** | ArgoCD sync wave ordering respected for dependent resources |
| **Rollback** | Changes are reversible; rollback path is clear |

### Directing fixes

When requesting changes, be specific:

- State what is wrong and where (file, line range)
- Explain why it's wrong (convention violation, security risk, missing dependency)
- Provide the fix or a clear path to the fix
- If the fix is trivial, offer to do it yourself rather than bouncing back

### Multi-agent task coordination

When the orchestrator delegates a complex task that requires multiple agents:

1. **Decompose** — break the task into specific sub-tasks with clear boundaries
2. **Assign** — spawn the appropriate junior agent for each sub-task with acceptance criteria
3. **Review** — review each sub-agent's PR as it comes in
4. **Integrate** — ensure PRs don't conflict, merge ordering is correct, cross-cutting concerns are addressed
5. **Report** — summarize the overall status to the orchestrator

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `agent` command hangs | No TTY available | Use tmux (see Mode 2) |
| `agent: command not found` | CLI not installed | `curl https://cursor.com/install -fsS \| bash` |
| Authentication failure | Missing or expired API key | Set `CURSOR_API_KEY` env var; check Infisical |
| `--force` still prompts | Older CLI version | `agent update` to latest version |
| tmux session exits immediately | Command error in session | Check `tmux capture-pane` output for errors |
| Generated code has wrong style | Missing context | Use `@` references to include style examples |
| Large diffs with unrelated changes | Cursor modified extra files | Review diff carefully; `git checkout -- <file>` to discard unwanted changes |
