---
type: llm
---

PASS only if the response satisfies every item below:

- Any manual duration log or Timer.Sample.stop is placed in a finally block (or Timer.record is used) — never a duration statement after the call that an exception would skip
- Also logs the duration (e.g. `durationMs`), from a `finally` block or equivalent, since the user asked for logs too
- Uses Micrometer (Timer) rather than a hand-rolled duration metric
- Metric name is stable and low-cardinality (no per-customer/per-payment tags)

FAIL if any item is missing or contradicted.
