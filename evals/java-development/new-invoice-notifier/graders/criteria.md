---
type: llm
---

PASS only if the response satisfies every item below:

- Injects both mandatory dependencies through the constructor with Objects.requireNonNull checks (no field/setter injection)
- Declares fields, parameters, and locals final; uses braces on every control statement
- Validates the id at the boundary (null/blank) and fails fast with a specific exception
- Catches only specific exception types if it catches at all, preserving the cause when wrapping
- Uses interface types in declarations and formatted()/String.format rather than + concatenation for the summary

FAIL if any item is missing or contradicted.
