---
type: llm
---

PASS only if the response satisfies this:

- Reports a status (present / partial / missing; JDTLS may be marked as user-machine or n/a) for each area: project baseline (wrapper, pinned JDK, maven.config, .editorconfig), test split, quiet output, hermetic tests, feedback tooling, agent docs, JDTLS

FAIL if it is missing or contradicted.
