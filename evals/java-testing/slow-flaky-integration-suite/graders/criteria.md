---
type: llm
---

PASS only if the response satisfies every item below:

- Rejects H2 — keeps the real production engine via Testcontainers, citing dialect/SQL-fidelity risk
- Makes containers static and shares one container across the whole suite (singleton or Spring-managed @TestConfiguration bean)
- Removes inter-test order dependence via per-test state isolation (transaction rollback in slices, or truncate/Flyway reset)
- Does not disable or skip any failing tests

FAIL if any item is missing or contradicted.
