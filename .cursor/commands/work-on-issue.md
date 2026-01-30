**note: remote repo is https://github.com/asbjborg/journal-addon**

Use the github MCP tool to read the issue mentioned by the user and work on the issue. Follow this workflow:

## Workflow

1. **Read & Understand** - Read the issue carefully and understand the requirements. Always ask the user for clarification if needed.

2. **Verify/Reproduce** - **CRITICAL: Always verify the issue still exists before fixing.** Do this step before any implementation.

   - **Check commits since issue creation:** Run `git log --oneline --since="<issue-created-date>" -- <relevant-paths>` (e.g. `JournalingAddon/features/Travel.lua JournalingAddon/features/Combat.lua`) to see which commits touched the code the issue relates to. Use the issue’s `created_at` date (from the GitHub API) for `--since`.
   - **Review those commits:** If one or more commits clearly implement the requested behavior or fix, do not implement—close the issue as "already fixed" and add a comment citing the commit(s) (hash, version, and what changed). Then stop.
   - **Review the changelog:** Check `changes.md` for entries that may have already addressed the issue.
   - **For older issues:** If the issue is old and no commit obviously fixes it, ask the user to test/reproduce the current behavior before implementing.
   - Only proceed to implementation after confirming the issue still exists. This prevents unnecessary work and ensures we're fixing real problems.

3. **Implement** - Make code changes for ONE issue at a time (see `.cursor/rules/workflow.mdc` for full workflow)

4. **Deploy** - Run `deploy.sh` to deploy changes for testing (see `.cursor/rules/workflow.mdc` for details)

5. **Test** - Wait for user to test before proceeding

6. **Commit** - Only commit after successful testing and user approval, following commit message conventions (see `.cursor/rules/commit-messages.mdc`)

7. **Close** - Add a closing message to the issue when the issue is resolved