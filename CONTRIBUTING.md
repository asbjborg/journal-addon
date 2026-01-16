# Contributing

## Commit Message Format

All commits should follow this format:

`vX.Y.Z [bug|feature]: <description>`

Examples:
- `v0.4.3 [bug]: log rep gains from "Reputation with X increased"`
- `v0.5.0 [feature]: capture vendor sales and repairs`

Notes:
- Use semantic versioning for `X.Y.Z`.
- Include the same version in `JournalingAddon/JournalingAddon.toc`.
- Add a matching entry in `changes.md` for every change.

## Optional Git Commit Template

You can use the provided `.gitmessage` to make the format easier to follow:

```
git config commit.template .gitmessage
```
