# close issue command

**note: remote repo is https://github.com/asbjborg/journal-addon**

the user has initiated a request to close the issue. the issue key should be available in the context, if not, ask the user to provide the issue key or find it in the github issue list.

When a user requests an issue to be closed, follow the branch-based workflow from `.cursor/rules/workflow.mdc`:

## 1) Confirm testing

- confirm (or infer from context) if the issue has been tested in-game.
    - if not: ask for confirmation. User must explicitly state that it is not necessary or not required to test in-game.

## 2) Finalize release metadata at merge time

- **Repo-only changes (non-addon)**:
    - no branch required; you can commit directly on `main`
    - no version bump or changelog required unless documenting in `changes.md`

- **Rebase on main before merging**:
    - `git fetch origin && git rebase origin/main`
- **Verify the date in changes.md BEFORE committing**:
    - Get the current date using: `date +%Y-%m-%d`
    - Check if the date in the new version section in `changes.md` matches today's date
    - If the dates don't match, update `changes.md` with today's date BEFORE committing
- **Set final version** (main's top version + 1):
    - Replace the branch's single `## [TBD] – <branch-name>` section with `## [X.Y.Z] - YYYY-MM-DD`
    - Update `JournalingAddon/JournalingAddon.toc` to `## Version: X.Y.Z`

## 3) Commit, push, merge (no squash)

- commit the changes on the branch following commit message conventions
- push the branch to origin
- merge into `main` **without squash** (preserve commits) using a versioned merge commit:
    - `vX.Y.Z [fix|feature]: <description> (#issue)`

## 4) Deploy after merge

- run `./deploy.sh` on `main` after the merge (addon changes only)

## 5) Close the issue

- Add a closing message to the issue
    - either by referencing the issue key in the commit with a message like `closes #<issue-key>`
    - or by adding a comment to the issue using github MCP tool.
- if the commit did not automatically close the issue, close it using github MCP tool.

## When to auto-close vs manual close

- **Auto-close via commit message**:
    - small/simple change documented in `changes.md`, no extra context needed
- **Manual close via GitHub**:
    - large/complex change requiring extra explanation
    - touches 3–4 files or more and needs more context than a commit message or changelog entry can provide