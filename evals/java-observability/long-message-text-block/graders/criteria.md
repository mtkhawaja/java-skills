---
type: llm
---

PASS only if the response satisfies every item below:

- Removes all `+` concatenation and the `String.format` call from the log statements; values are passed as `{}` arguments (e.g. `paymentId={}`, `attempt={}`), not built into the string
- The long `warn` template is written as a Java text block whose lines end with a `\` line continuation, so the logged message stays a single line (no embedded newlines), with no `.formatted()` call
- Keeps the messages readable as one sentence each

FAIL if any item is missing or contradicted.
