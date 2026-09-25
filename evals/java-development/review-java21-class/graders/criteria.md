---
type: llm
---

PASS only if the response satisfies every item below:

- Flags the Optional field (Optional is a return type only)
- Flags the raw ArrayList type and the implementation-typed variable (program to interfaces)
- Replaces the int constants with an enum and the if-else chain with an exhaustive switch expression
- Flattens the nested conditionals into guard clauses that fail fast with specific exceptions instead of silently returning 0
- Flags equals without hashCode and the missing @Override; the fix removes or corrects the broken equals
- Adds final to parameters/locals/class per the house standard

FAIL if any item is missing or contradicted.
