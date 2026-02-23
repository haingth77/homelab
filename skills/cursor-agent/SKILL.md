---
name: cursor-agent
description: Bridge OpenClaw with the Cursor CLI for AI-assisted code generation, review, and refactoring tasks. Covers installation, authentication, non-interactive automation, tmux TTY workaround, and the OpenClaw-to-Cursor handoff protocol.
metadata:
  {
    "openclaw":
      {
        "emoji": "🖥️",
        "requires": { "anyBins": ["tmux"] },
      },
  }
---

# Cursor CLI Agent Bridge

Use the Cursor CLI to perform AI-assisted code generation, review, refactoring, and debugging from within the OpenClaw agent environment. This skill defines the handoff protocol between OpenClaw and the Cursor CLI.

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
  └── sessions_spawn → cursor-agent
        ├── 1. Receive task description + target repo
        ├── 2. Setup workspace (clone repo, create branch)
        ├── 3. Invoke Cursor CLI (tmux or non-interactive)
        ├── 4. Review generated changes (git diff)
        ├── 5. Commit with agent footprint
        ├── 6. Push + create PR
        └── 7. Report results back via sessions_announce
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

# Follow-up refinement
tmux send-keys -t "${SESSION}" "agent --resume 'Add input validation and error handling'" Enter
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
