---
type: llm
---

PASS only if the response satisfies every item below:

- Replaces System.out and printStackTrace with the SLF4J facade, values as `key={}` placeholders or key-value fields (`addKeyValue`), exception passed as last argument or via `setCause`
- Uses the full level palette: INFO start/outcome with identifiers and counts, DEBUG per-line detail, WARN for skipped lines and a distinct partial-success outcome signal
- Adds orderId and requestId to MDC and removes just those keys (`MDC.remove` in finally, or `MDC.putCloseable` try-with-resources; not `MDC.clear`), since the filter owns the traceId, and does not also add `orderId`/`requestId` as `addKeyValue` fields (MDC already carries them)
- Never logs cardNumber, email, name, address, or whole request objects
- Adds a Micrometer Timer on the fulfill path and a Counter for failed lines, with low-cardinality names and no per-order tags
- Preserves the original control flow (telemetry changes no behavior)

FAIL if any item is missing or contradicted.
