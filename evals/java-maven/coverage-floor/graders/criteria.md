---
type: llm
---

PASS only if the response satisfies every item below:

- Line and branch minimums are at or just below current coverage (rounded down), not an arbitrary target
- Keeps the existing -Xmx1g by using late property replacement (`@{argLine}`) so the JaCoCo agent isn't dropped
- Explains that raising the floor is a deliberate edit, and where the report is (target/site/jacoco)

FAIL if any item is missing or contradicted.
