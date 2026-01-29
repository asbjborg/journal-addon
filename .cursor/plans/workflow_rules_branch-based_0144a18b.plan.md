---
name: Workflow rules branch-based
overview: Update the existing Cursor rules (workflow, deploy-changes, commit-messages, document-changes) to support branch-based parallel work with [TBD] changelog entries and version-at-merge, without adding a new rule file.
todos: []
isProject: false
---

# Branch-based workflow rules update

## Goal

Change the ruleset so you can work on multiple issues in parallel (one per branch), use a placeholder changelog section `[TBD]` while implementing, bump `.toc` on the branch for in-game build identity, and assign the real version only when merging. No new rule file; update the four relevant rules in place.

## Current state

- [workflow.mdc](.cursor/rules/workflow.mdc): "ONE issue at a time"; bump .toc and add versioned changelog section **before** deploy.
- [deploy-changes.mdc](.cursor/rules/deploy-changes.mdc): Bump .toc and update changes.md **before** deploy.
- [commit-messages.mdc](.cursor/rules/commit-messages.mdc): Version in .toc and changes.md; no mention of merge-time version.
- [document-changes.mdc](.cursor/rules/document-changes.mdc): New section at top with `## [X.Y.Z]`; no placeholder.

## 1. workflow.mdc

**Replace** the single-issue flow with a branch-based flow and keep the same step names.

- **Overview**: One issue per branch; one merge at a time. Steps (Implement, Deploy, Test, Commit, Close) apply per branch.
- **Implement**: Create a branch from main (e.g. `issue-59-death-hardcut`). Implement on that branch.
- **Deploy**: Run `deploy.sh` after addon changes and when switching to a branch you want to test in-game. On the branch: add a **single** draft changelog section at the top with placeholder `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`); set `.toc` **Version** to **dev-** plus the branch name (e.g. `dev-issue-59-death-hardcut`) so branch deployments are clearly marked in-game. (WoW .toc Version accepts any string.) Real version and date are **finalized at merge**, not when deploying.
- **Test / Commit / Close**: Unchanged (test before commit; wait for approval; close after commit).

**Critical rules** (reword):

- **One issue per branch** – Work on multiple issues by using separate branches; only one merge at a time (version = main's top + 1 at merge).
- **Deploy before commit** – Deploy and test before committing.
- **No premature commits** – Same as now.
- **Wait for approval** – Same as now.

**Add a short "At merge" subsection** (under Deploy or as its own step):

- Rebase on main (`git fetch origin && git rebase origin/main`).
- Set **final version** = top version in `changes.md` on main + 1 (e.g. main has 0.6.22 → use 0.6.23).
- In `changes.md`: replace the branch’s single `## [TBD]` section with `## [X.Y.Z] - YYYY-MM-DD`. When merging, only the current branch’s [TBD] is converted (one merge at a time); if another branch was merged first, rebase so your branch has only your [TBD].
- In `JournalingAddon/JournalingAddon.toc`: set `## Version: X.Y.Z` to that final version.
- Merge to main (direct merge; PRs optional). Use a **merge that preserves commits** (no squash), so every commit and its message are kept on main.

**Exception**: Keep existing exceptions (user says skip steps; not journal addon work).

## 2. deploy-changes.mdc

**Overview**: Keep "run deploy.sh after addon changes." Add: run `deploy.sh` when you switch to a branch you are about to test in-game, so WoW runs that branch’s code.

**Workflow section** – split into two cases:

- **On a feature branch (before merge):**
- Add or update the **single** draft changelog section at the top: `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`) with the change description; no version or date yet.
- Set `JournalingAddon/JournalingAddon.toc` **Version** to **dev-** plus the branch name (e.g. `dev-issue-59-death-hardcut`) so branch deployments are clearly marked in-game.
- Run `deploy.sh`. No requirement that .toc and a versioned changelog heading match until merge.

- **At merge (final deploy):**
- Version in `.toc` and the changelog heading in `changes.md` must match the final release (main’s top version + 1). Replace `[TBD]` with `[X.Y.Z] - date`.

Keep: "Deploy BEFORE commit and close"; "Changes outside JournalingAddon folder do not require deploy."

## 3. commit-messages.mdc

**Add one note** (e.g. after the existing Notes):

- **When merging a branch:** The version in the commit message is the **final** version assigned at merge (main’s top version in `changes.md` + 1). Use that same version in `.toc` and in the `## [X.Y.Z] `heading in `changes.md`.

**Add one example** for a merge-time commit:

- `v0.6.23 [fix]: treat death as hard cut so activity chunk before death (#59)`

Leave the rest (format, existing examples, semantic versioning, issue number, "create a NEW version section") unchanged; the "new version section" is satisfied by converting `[TBD]` to `[X.Y.Z]` at merge.

## 4. document-changes.mdc

**Overview**: Add that work-in-progress may use a **placeholder** section at the top.

**Changelog structure** – add bullets:

- On a branch, there must be **exactly one** [TBD] section at the top. All changes for that branch append to that section. When merging, replace it with `## [X.Y.Z] - YYYY-MM-DD` where X.Y.Z = main’s top version + 1.
- Placeholder heading: `## [TBD]` or `## [TBD] – #N` or `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`); no version or date until merge. Using the branch name improves clarity when scanning history.

Keep: "Never add changes to an already-released version"; "Never modify changelog entries for already-committed versions"; "Only add to a version section if that version hasn’t been committed yet" (for the final [X.Y.Z] section at merge).

## 5. Optional refinement (recommended)

- **Standardize [TBD] with branch name:** Prefer `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`) over `## [TBD] – #59`. Zero ambiguity during rebases; easier manual merges; clear ownership when scanning changelog. Mention in workflow.mdc and document-changes.mdc so agents use it by default.

## 6. What we are not doing

- **No new rule file** – All branch-based and [TBD] behavior lives in the four existing rules.
- **CONTRIBUTING.md** – Optional later: add one line like "For branch-based work and [TBD] changelog, see .cursor/rules/workflow.mdc and deploy-changes.mdc." Not in scope for this plan unless you want it.

## Summary

| File | Change |
|------|--------|
| workflow.mdc | Branch per issue; [TBD] + .toc Version = `dev-<branch-name>` on branch; "At merge" steps (rebase, version = main+1, replace [TBD], set .toc to X.Y.Z); relax "ONE issue" to "one issue per branch, one merge at a time". |
| deploy-changes.mdc | Two cases: on branch (draft [TBD] + .toc Version = `dev-<branch-name>`, deploy); at merge (final version in .toc and changelog). Deploy when switching branch to test. |
| commit-messages.mdc | One note: version in commit message = final version at merge (main+1). |
| document-changes.mdc | Exactly one [TBD] section per branch at top; all branch changes append there. Placeholder `## [TBD]` or `## [TBD] – <branch-name>`; replace with `## [X.Y.Z] - date` at merge. |

After implementation, agents and you can work in parallel on branches, use `[TBD]` and a draft .toc for deploy identity, and only set the real version and date when merging.