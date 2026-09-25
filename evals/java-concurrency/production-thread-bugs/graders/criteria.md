---
type: llm
---

PASS only if the response satisfies every item below:

- Explains the visibility problem — without volatile/synchronization the reader may never see the write — and fixes it with volatile (or an atomic)
- Explains carrier-thread pinning: blocking inside synchronized pins the carrier under virtual threads
- Replaces synchronized around the blocking call with a ReentrantLock

FAIL if any item is missing or contradicted.
