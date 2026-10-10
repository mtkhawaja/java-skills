---
type: llm
---

The response proposes changes for the user to apply (it has no write tools); grade what it proposes.

PASS only if the response satisfies this:

- With the proposed config, a plain `verify` (`./mvnw` or `mvn`) still runs every test, including the slow-tagged one; slow tests are excluded only under the `fast` profile

FAIL if it is missing or contradicted.
