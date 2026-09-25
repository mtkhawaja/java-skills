---
type: llm
---

PASS only if the response satisfies every item below:

- Places a single .gitignore at the repo root, trimmed to Maven (no Gradle-only build entries)
- Covers secrets/local config (*.env, application-local.*, keystores, credentials*), build output (target/, *.class), IDE files, OS cruft, and logs/crash dumps
- Keeps wrapper files trackable (negation for gradle-wrapper.jar where relevant; .mvn/wrapper/maven-wrapper.properties stays committed)

FAIL if any item is missing or contradicted.
