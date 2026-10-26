---
type: llm
---

PASS only if the response satisfies every item below:

- Moves the order id into a key-value field via the SLF4J fluent API (e.g. `atInfo().addKeyValue("orderId", ...)`), not only as a `{}` placeholder in the message text
- Keeps a readable, constant message (e.g. "Order shipped") rather than a message built from the values
- Removes the customer's address from the log entirely (not moved to a field, not masked into the message); no name or email logged either
- Explains that the ECS encoder only turns MDC and key-value pairs into fields, not values inside the message text
- Does not put the per-line order id into MDC as the fix

FAIL if any item is missing or contradicted.
