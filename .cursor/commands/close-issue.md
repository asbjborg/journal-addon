# close issue command

**note: remote repo is https://github.com/asbjborg/journal-addon**

the user has initiated a request to close the issue. the issue key should be available in the context, if not, ask the user to provide the issue key or find it in the github issue list.

When a user request an issue to be closed, you should do the following:

- confirm (or infer from context) if the issue has been tested in-game.
    - if not: ask for confirmation. User must explicitly state that it is not necessary or not required to test in-game.
- **Verify the date in changes.md BEFORE committing**:
    - Get the current date using: `date +%Y-%m-%d` (or equivalent command to get today's date in YYYY-MM-DD format)
    - Check if the date in changes.md for the new version matches today's date
    - If the dates don't match, update changes.md with today's date BEFORE committing
- commit the changes to the repository and push the changes to the remote repository while following the commit message conventions.
- Add a closing message to the issue
    - either by referencing the issue key in the commit with a message like "closes #<issue-key>"
    - or by adding a comment to the issue using github MCP tool.
- if the commmit did not automatically close the issue, also close the issue using github MCP tool.
- when to close the issue automatically with the commit message:
    - when it's a small and simple change that is documented in the changes.md file, and doesn't require any further explanation or history.
- when to close the issue manually with the github MCP tool:
    - when it's a large and complex change that requires further explanation
    - when it touches 3-4 files or more and requires a more detailed explanation or history, which can't be easily documented in the changes.md file or the commit message.