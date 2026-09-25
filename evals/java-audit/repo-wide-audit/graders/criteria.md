---
type: llm
---

PASS only if the response satisfies every item below:

- Scopes to the repository's main Java source, sampling representatively (and saying so) if the repo is large
- Produces one consolidated report: verdict, severity-grouped findings with file:line and the violated rule, and what was checked clean

FAIL if any item is missing or contradicted.
