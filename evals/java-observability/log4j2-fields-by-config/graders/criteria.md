---
type: llm
---

PASS only if the response satisfies every item below:

- Advises against the custom appender, in favour of changing the output format by configuration (e.g. `logging.structured.format.console=ecs`, or Log4j2 JSON Template Layout with `EcsLayout.json`)
- Moves the payment id and order id into SLF4J key-value fields (`addKeyValue`) with a constant message, rather than parsing them out of the message text
- Notes that on Log4j2 the key-values arrive as context data (ThreadContext/MDC), so the structured format emits them as fields, and/or that their values become strings
- Suggests keeping readable text locally (e.g. by profile or environment)

FAIL if any item is missing or contradicted.
