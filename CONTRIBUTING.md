# Contributing

## Commit Message Format

All commits should follow this format:

`vX.Y.Z [fix|feature]: <description> (#issue)`

Examples:
- `v0.4.3 [fix]: log rep gains from "Reputation with X increased" (#22)`
- `v0.5.0 [feature]: capture vendor sales and repairs (#15)`

Notes:
- Use semantic versioning for `X.Y.Z`.
- Include the same version in `JournalingAddon/JournalingAddon.toc`.
- Add a matching entry in `changes.md` for every change.
- Always include the issue number `(#N)` at the end - this links the commit to the issue on GitHub.

For branch-based work, [TBD] changelog, and version-at-merge, see `.cursor/rules/workflow.mdc` and `.cursor/rules/deploy-changes.mdc`.

## Optional Git Commit Template

You can use the provided `.gitmessage` to make the format easier to follow:

```
git config commit.template .gitmessage
```
