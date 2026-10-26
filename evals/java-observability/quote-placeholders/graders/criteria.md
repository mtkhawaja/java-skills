---
type: llm
---

PASS only if the response satisfies every item below:

- Does not apply the reviewer's request wholesale: no quotes are added around the `orderId`, `lineCount` or `shipmentId` values
- Gives the reason for declining in a single sentence, and that reason is that structured (ECS/JSON) output already delimits and escapes each value (the rest of the reply may cover other fixes)
- For the free-text `reason`: moves it into a key-value field or leaves it unquoted; adds no quotes, brackets or single quotes to the ECS-bound lines (logfmt `reason="{}"` may be mentioned only for a plain-text profile)

FAIL if any item is missing or contradicted.
