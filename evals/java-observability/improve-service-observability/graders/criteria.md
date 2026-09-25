---
type: llm
---

PASS only if the response satisfies every item below:

- Replaces System.out and printStackTrace with the SLF4J facade using parameterized key={} messages, exception passed as last argument
- Uses the full level palette: INFO start/outcome with identifiers and counts, DEBUG per-line detail, WARN for skipped lines and a distinct partial-success outcome signal
- Adds orderId/requestId to MDC and removes those keys (MDC.remove, not MDC.clear) in finally, since the filter owns the traceId
- Never logs cardNumber, email, name, address, or whole request objects
- Adds a Micrometer Timer on the fulfill path and a Counter for failed lines, with low-cardinality names and no per-order tags
- Preserves the original control flow (telemetry changes no behavior)

FAIL if any item is missing or contradicted.
