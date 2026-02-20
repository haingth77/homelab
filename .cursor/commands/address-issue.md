Read the specified GitHub issue, draft an implementation plan, and execute the full workflow.

## Steps

1. **Read the issue** to understand requirements:
   ```bash
   gh issue view <issue-number> --repo holdennguyen/homelab
   ```

2. **Draft an implementation plan** covering:
   - Which files/services will be modified
   - The approach and key design decisions
   - Risks, dependencies, or open questions
   - Docs that need updating (check the `/documentation` skill for the matrix)

3. **Comment the plan on the issue**:
   ```bash
   gh issue comment <issue-number> --repo holdennguyen/homelab --body "## Implementation Plan ..."
   ```

4. **Create a feature branch** from latest main:
   ```bash
   git checkout main && git pull origin main
   git checkout -b <type>/<short-description>
   ```

5. **Implement the changes** referencing the plan. Include documentation updates in the same PR.

6. **Before pushing**, sync with main:
   ```bash
   git fetch origin main && git merge origin/main --no-edit
   ```

7. **Commit, push, and create a PR**:
   ```bash
   git add <files>
   git commit -m "<type>: <description>"
   git push -u origin HEAD
   gh pr create --title "<type>: <description>" --body "Closes #<issue-number> ..."
   ```

8. **Report** the PR URL when done.

If the issue number is not provided, ask the user for it before proceeding.
