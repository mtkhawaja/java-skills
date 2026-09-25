---
type: llm
---

PASS only if the response satisfies every item below:

- Identifies that parallelStream runs on the shared common ForkJoinPool sized to cores — near-zero parallelism for blocking I/O and starves everything else using that pool
- Replaces it with an explicit executor (virtual threads for blocking I/O) using submit-all-then-join
- Adds a concurrency bound for the downstream service

FAIL if any item is missing or contradicted.
