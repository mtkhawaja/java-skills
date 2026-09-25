---
type: llm
---

PASS only if the response satisfies every item below:

- Targets Java 17, the release the pom is stated to set
- Uses no language or library feature newer than Java 17 and no preview features (no virtual threads, no pattern-matching switch as default idiom)
- Never leaks a file handle: any Files.lines stream or reader is opened in try-with-resources (Files.readAllLines, which closes the file itself, is also acceptable)
- Works in UTC with java.time types and does not call Instant.now()/LocalDateTime.now() for any 'now' logic (injects Clock if needed)
- Validates input at the boundary and throws specific exceptions rather than returning silently

FAIL if any item is missing or contradicted.
