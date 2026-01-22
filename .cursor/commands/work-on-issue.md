**note: remote repo is https://github.com/asbjborg/journal-addon**

Use the github MCP tool to read the issue mentioned by the user and work on the issue. Follow this workflow:

## Workflow

1. **Read & Understand** - Read the issue carefully and understand the requirements. Always ask the user for clarification if needed.

2. **Verify/Reproduce** - **CRITICAL: Always verify the issue still exists before fixing**, especially for older issues:
   - Check when the issue was created vs when related code changes were made
   - Review the changelog (`changes.md`) to see if the issue may have already been fixed
   - For old issues, ask the user to test/reproduce the current behavior first
   - Only proceed to implementation after confirming the issue still exists
   - This prevents unnecessary work and ensures we're fixing real problems

3. **Implement** - Make code changes for ONE issue at a time (see `.cursor/rules/workflow.mdc` for full workflow)

4. **Deploy** - Run `deploy.sh` to deploy changes for testing (see `.cursor/rules/workflow.mdc` for details)

5. **Test** - Wait for user to test before proceeding

6. **Commit** - Only commit after successful testing and user approval, following commit message conventions (see `.cursor/rules/commit-messages.mdc`)

7. **Close** - Add a closing message to the issue when the issue is resolved