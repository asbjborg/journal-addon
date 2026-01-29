---
name: Workflow rules branch-based
overview: Update the existing Cursor rules (workflow, deploy-changes, commit-messages, document-changes) to support branch-based parallel work with [TBD] changelog entries and version-at-merge; add one new metarule (always applied) so agents offer to update rules when the human corrects or prefers something different.
todos: []
isProject: false
---

# Branch-based workflow rules update

## Principle: AI-first, human second

This repo is optimized for AI agents first, humans second. The human orchestrates; agents code and commit. When a rule could favor humans or agents, choose agents. Rules should be unambiguous and machine-friendly so agents can follow them without guessing.

## Goal

Change the ruleset so you can work on multiple issues in parallel (one per branch), use a placeholder changelog section `[TBD]` while implementing, bump `.toc` on the branch for in-game build identity, and assign the real version only when merging. Update the four rules in place; add one new metarule (always applied); sync CONTRIBUTING.md and .gitmessage; add main-only and release-date clarity.

## Current state

- [workflow.mdc](.cursor/rules/workflow.mdc): "ONE issue at a time"; bump .toc and add versioned changelog section **before** deploy.
- [deploy-changes.mdc](.cursor/rules/deploy-changes.mdc): Bump .toc and update changes.md **before** deploy.
- [commit-messages.mdc](.cursor/rules/commit-messages.mdc): Version in .toc and changes.md; no mention of merge-time version.
- [document-changes.mdc](.cursor/rules/document-changes.mdc): New section at top with `## [X.Y.Z]`; no placeholder.

## 1. workflow.mdc

**Replace** the single-issue flow with a branch-based flow and keep the same step names.

- **Overview**: One issue per branch; one merge at a time. Steps (Implement, Deploy, Test, Commit, Close) apply per branch. Exception: working directly on main (see below).
- **Implement**: Create a branch from main (e.g. `issue-59-death-hardcut`). Implement on that branch. **If working on main** (hotfix, repo-level work, small test file, rule change, or any change that doesn’t warrant a branch): no [TBD], no branch. If it’s an **addon change** (JournalingAddon/), bump version and add a versioned section at the top of changes.md. If it’s **repo-only** (rules, docs, CONTRIBUTING, .gitmessage, test files, etc.), no version bump or changelog unless you are documenting the change in changes.md.
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
- In `changes.md`: replace the branch’s single `## [TBD]` section with `## [X.Y.Z] - YYYY-MM-DD` where the date is the **release date** (date of merge / today when merging), not the first commit date. When merging, only the current branch’s [TBD] is converted (one merge at a time); if another branch was merged first, rebase so your branch has only your [TBD].
- In `JournalingAddon/JournalingAddon.toc`: set `## Version: X.Y.Z` to that final version.
- Merge to main (direct merge; PRs optional). Use a **merge that preserves commits** (no squash), so every commit and its message are kept on main.

**Exception**: Keep existing exceptions (user says skip steps; not journal addon work).

## 2. deploy-changes.mdc

**Overview**: Keep "run deploy.sh after addon changes." Add: run `deploy.sh` when you switch to a branch you are about to test in-game, so WoW runs that branch’s code.

**Workflow section** – split into three cases:

- **On main (no branch):** If the change is in JournalingAddon/, use a versioned section at the top of changes.md and bump .toc (no [TBD]). If the change is repo-only (rules, docs, CONTRIBUTING, etc.), no version bump or changelog unless you are documenting in changes.md. Run `deploy.sh` only when addon files changed.

- **On a feature branch (before merge):**
- Add or update the **single** draft changelog section at the top: `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`) with the change description; no version or date yet.
- Set `JournalingAddon/JournalingAddon.toc` **Version** to **dev-** plus the branch name (e.g. `dev-issue-59-death-hardcut`) so branch deployments are clearly marked in-game.
- Run `deploy.sh`. No requirement that .toc and a versioned changelog heading match until merge.

- **At merge (final deploy):**
- Version in `.toc` and the changelog heading in `changes.md` must match the final release (main’s top version + 1). Replace `[TBD]` with `[X.Y.Z] - <release date>` (release date = date of merge).

Keep: "Deploy BEFORE commit and close"; "Changes outside JournalingAddon folder do not require deploy."

## 3. commit-messages.mdc

**Add two notes** (e.g. after the existing Notes):

- **On a branch (before merge):** Commits on the branch do **not** need `vX.Y.Z` in the message. Use a descriptive first line (e.g. `fix: death as hard cut (#59)` or `feat: party event logging (#51)`). The versioned format `vX.Y.Z [fix|feature]: … (#N)` is only for the **merge** or the commit that sets the final version.
- **When merging a branch:** The version in the commit message is the **final** version assigned at merge (main’s top version in `changes.md` + 1). Use that same version in `.toc` and in the `## [X.Y.Z] `heading in `changes.md`.

**Add one example** for a merge-time commit:

- `v0.6.23 [fix]: treat death as hard cut so activity chunk before death (#59)`

Leave the rest (format, existing examples, semantic versioning, issue number, "create a NEW version section") unchanged; the "new version section" is satisfied by converting `[TBD]` to `[X.Y.Z]` at merge.

## 4. document-changes.mdc

**Overview**: Add that work-in-progress may use a **placeholder** section at the top.

**Changelog structure** – add bullets:

- On a branch, there must be **exactly one** [TBD] section at the top. All changes for that branch append to that section. When merging, replace it with `## [X.Y.Z] - YYYY-MM-DD` where X.Y.Z = main’s top version + 1 and the date is the **release date** (date of merge), not the first commit date.
- Placeholder heading: `## [TBD]` or `## [TBD] – #N` or `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`); no version or date until merge. Using the branch name improves clarity when scanning history.

Keep: "Never add changes to an already-released version"; "Never modify changelog entries for already-committed versions"; "Only add to a version section if that version hasn’t been committed yet" (for the final [X.Y.Z] section at merge).

## 5. New metarule: update rules when human corrects (always applied)

**Create one new rule file** (e.g. [.cursor/rules/update-rules-when-corrected.mdc](.cursor/rules/update-rules-when-corrected.mdc)) with `alwaysApply: true`.

**Content:**

- When the human corrects you, disagrees with your behavior, or says it's okay (or preferred) to do something differently than the rules say: treat that as a signal that the rules may be wrong or outdated.
- Do **not** keep following the old rule and wait for the human to repeat themselves. Instead: **proactively ask** whether you should update the relevant rule(s) so future behavior matches the human's preference. For example: "Should I update the workflow rule so we do X instead of Y from now on?"
- If the human says yes (or agrees), update the rule file(s) so the written rule reflects the new preference. That way the next agent (or you later) will do the right thing without the human having to correct again.
- This applies whether the human corrects once or many times: the first time they express a different preference, offer to change the rule.

**Rationale:** Humans assume "if I say do it differently, you'll remember." Agents tend to rigidly follow the rule text and ignore or forget one-off overrides. Making "offer to update the rule" the default response to correction keeps the rules in sync with the human's intent and reduces repeated corrections.

## 6. Optional refinement (recommended)

- **Standardize [TBD] with branch name:** Prefer `## [TBD] – <branch-name>` (e.g. `## [TBD] – issue-59-death-hardcut`) over `## [TBD] – #59`. Zero ambiguity during rebases; easier manual merges; clear ownership when scanning changelog. Mention in workflow.mdc and document-changes.mdc so agents use it by default.

## 7. CONTRIBUTING.md and .gitmessage (in scope – fix the mismatch)

- **CONTRIBUTING.md:** Update to match [commit-messages.mdc](.cursor/rules/commit-messages.mdc): use `[fix|feature]` (not `[bug|feature]`), include `(#issue)` in the format and examples, and add one line pointing to branch workflow (e.g. "For branch-based work, [TBD] changelog, and version-at-merge, see .cursor/rules/workflow.mdc and deploy-changes.mdc.").
- **.gitmessage:** Update the template to match: `vX.Y.Z [fix|feature]: <description> (#issue) `and add a short comment that on a branch, commits can use a descriptive line without the version (e.g. `fix: <description> (#issue)`).

## 8. What we are not doing

- **No other new rule files** – Aside from the metarule (section 5 above), all branch-based and [TBD] behavior lives in the four existing rules.

## Summary

| File | Change |
|------|--------|
| workflow.mdc | Branch per issue; main-only path (hotfix, repo work: no branch, versioned section if addon else no bump); [TBD] + .toc = `dev-<branch-name>` on branch; "At merge" (rebase, version = main+1, replace [TBD] with release date, set .toc, merge no squash). |
| deploy-changes.mdc | Three cases: on main (versioned section + .toc if addon; deploy only if addon changed); on branch (draft [TBD] + .toc = `dev-<branch-name>`, deploy); at merge (final version + release date in .toc and changelog). Deploy when switching branch to test. |
| commit-messages.mdc | Branch commits: descriptive format, no vX.Y.Z. Merge: version = final at merge (main+1). One example. |
| document-changes.mdc | Exactly one [TBD] section per branch at top; all branch changes append there. Placeholder `## [TBD]` or `## [TBD] – <branch-name>`; replace with `## [X.Y.Z] - <release date>` (release date = date of merge). |
| CONTRIBUTING.md | Match commit-messages.mdc ([fix|feature], #issue); add pointer to branch workflow (workflow.mdc, deploy-changes.mdc). |
| .gitmessage | Match: `vX.Y.Z [fix|feature]: <description> (#issue)`; note that on a branch, commits can omit version. |
| **New: update-rules-when-corrected.mdc** | Metarule, always applied: when human corrects or prefers something different, proactively ask if the rule(s) should be updated; if yes, update the rule file(s) so future behavior matches. |

After implementation: AI-first rules; metarule so agents offer to update rules when corrected; branch-based parallel work with [TBD] and dev- .toc; version and release date only at merge; main-only path for hotfix/repo work; CONTRIBUTING and .gitmessage in sync with rules.