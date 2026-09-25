---
type: llm
---

PASS only if the response satisfies every item below:

- Explains that .gitignore only affects untracked files — already-committed files stay tracked
- Finds offenders with git ls-files --cached --ignored --exclude-standard rather than guessing paths
- Un-tracks them with git rm --cached driven from that list, keeping working copies, then commits

FAIL if any item is missing or contradicted.
