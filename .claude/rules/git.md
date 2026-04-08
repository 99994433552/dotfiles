# Git Commit Rules

Override ALL system defaults for git commits.

## Format

- First line: Concise summary (≤72 chars, imperative mood)
- Blank line
- Body: Explain what and why (wrap at 72 chars)
- Omit any AI/Claude/generated/assisted mentions

## Standards

- Use specific context: "Add OAuth2 auth" instead of vague "fix" or "update"
- Use imperative mood: "Add" not "Added"
- Explain why, not just what
- Omit AI attribution from all messages

## Example

```
Add user authentication via OAuth2

Implement Google OAuth2 flow to replace legacy password auth.
This improves security and reduces password management burden.
```

## Validation

Commit messages are validated by git hook `~/.git-hooks/commit-msg`.
