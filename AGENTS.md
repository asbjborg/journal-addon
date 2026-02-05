# AGENTS

This repo uses the rules in `.cursor/rules/`. The list below links to the authoritative files.

- Workflow (issues/branches/deploy/test/commit/close): [`.cursor/rules/workflow.mdc`](.cursor/rules/workflow.mdc) - One issue per branch, deploy/test before commit, merge rules.
- Deploy after addon changes: [`.cursor/rules/deploy-changes.mdc`](.cursor/rules/deploy-changes.mdc) - Run `deploy.sh` for addon edits; dev versioning on branches.
- Commit message format + versioning rules: [`.cursor/rules/commit-messages.mdc`](.cursor/rules/commit-messages.mdc) - Branch commits vs merge-time versioned commits.
- Changelog/version documentation rules: [`.cursor/rules/document-changes.mdc`](.cursor/rules/document-changes.mdc) - Always add a new top section; use [TBD] on branches.
- New issue templates + labeling rules: [`.cursor/rules/new-issue.mdc`](.cursor/rules/new-issue.mdc) - Use templates; no labels in titles.
- Update rules when corrected by human: [`.cursor/rules/update-rules-when-corrected.mdc`](.cursor/rules/update-rules-when-corrected.mdc) - Offer to update rules when behavior is corrected.
