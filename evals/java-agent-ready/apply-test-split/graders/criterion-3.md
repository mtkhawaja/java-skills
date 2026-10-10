---
type: llm
---

The response proposes changes for the user to apply (it has no write tools); grade what it proposes.

PASS only if the response satisfies this:

- Proposes changes for the test split area only — no wrapper, JaCoCo, logging, or AGENTS.md changes

FAIL if it is missing or contradicted.
