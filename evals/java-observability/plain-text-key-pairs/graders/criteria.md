---
type: llm
---

PASS only if the response satisfies every item below:

- Replaces the concatenation with `{}` placeholders
- Every logged value is written as a `key={}` pair rather than a bare placeholder in prose, and the keys follow one naming style across all three statements (e.g. all camelCase; short keys like `status` or `attempts` are fine)
- The revised statements do not use the SLF4J fluent `addKeyValue` API (mentioning it is fine)
- Does not propose switching the output to JSON, since the prompt rules that out

FAIL if any item is missing or contradicted.
