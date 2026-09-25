---
type: llm
---

PASS only if the response satisfies every item below:

- States clearly that it is not enough — git rm --cached removes the file from the current commit only; the secret remains in history
- Requires rotating the secret immediately as the primary fix
- Recommends scrubbing history (git filter-repo or BFG) with coordinated force-push, plus the .gitignore pattern to prevent recurrence

FAIL if any item is missing or contradicted.
