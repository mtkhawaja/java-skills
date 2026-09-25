---
type: llm
---

PASS only if the response satisfies every item below:

- Audits only what the current branch changed versus main (ShippingService.java), not the unchanged billing code
- Does not expand scope to unchanged files except flagging pre-existing issues as optional follow-ups
- Reports severity-grouped findings with file:line citations

FAIL if any item is missing or contradicted.
