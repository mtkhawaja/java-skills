---
type: llm
---

PASS only if the response satisfies every item below:

- Identifies that the ECS format drops the whole line when keys collide, with only a Logback status/internal error rather than application output
- Names the collisions: `orderId` set both in MDC and as a key-value; `message` clashing with the format's own field; `order` being a prefix of `order.id` (dotted keys nest in ECS)
- Fixes by renaming keys (distinct, non-reserved, e.g. camelCase like `orderStatus`, `note`) and dropping the duplicate `orderId` key-value since MDC already carries it, rather than switching away from ECS or writing a custom encoder

FAIL if any item is missing or contradicted.
