---
type: llm
---

PASS only if the response satisfies every item below:

- Flags + concatenation and converts to parameterized {} placeholders
- Flags System.out and the java.util.logging introduction (use the project facade only)
- Flags log.error(e.getMessage()) for dropping the stack trace — pass the exception as the last argument
- Flags the token and request body as sensitive data that must not be logged at any level

FAIL if any item is missing or contradicted.
