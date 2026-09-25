---
type: llm
---

PASS only if the response satisfies every item below:

- Uses a virtual-thread-per-task executor (not parallelStream, not a fixed platform pool sized to cores)
- Submits all tasks and materializes the futures (.toList()) before joining any — no single lazy stream pipeline that submits and joins per element
- Bounds in-flight concurrency with a Semaphore (or sized executor) instead of firing 10,000 simultaneous calls
- Closes the executor (try-with-resources) 
- Join logic preserves the ExecutionException cause and restores the interrupt flag on InterruptedException

FAIL if any item is missing or contradicted.
