---
name: java-observability
description: Use when adding, reviewing, or retrofitting logging, metrics, tracing, or diagnostics in Java — including "improve the logging/observability of this code" requests, structured/JSON log output (Spring Boot structured logging, Logback, Log4j2, ECS/logstash), log fields that can't be queried or log lines that go missing, and log message style (placeholders, quoting, long messages). Covers the logging facade with parameterized messages and queryable key-value fields, the full level palette (DEBUG/INFO/WARN/ERROR) across a unit of work, correlation IDs / MDC, never logging secrets/PII, preserving stack traces, and Micrometer / OpenTelemetry. Catches string-concatenated logs, System.out, sensitive-data logging, and missing correlation/telemetry.
---

# Java Observability

## Overview

Make a running system diagnosable. Three pillars: **logs** (what happened), **metrics**
(how much/how often), **traces** (where time went).

## Logging

- **Use the project's facade** — prefer **SLF4J**; else the project standard (Log4j2). Never
  introduce a new framework (including `java.util.logging`). Never use `System.out`/`System.err`.
  Keep the project's logger field name (`log`, `LOGGER`); rules below apply to any logging call.
- **Parameterized, not concatenated:** never `"created order " + id`. Placeholders and
  key-value fields defer string building until the level is enabled. Values someone will query
  go in **key-value fields** (see [Structured logging](#structured-logging)).
- **Templates longer than the project's line limit → a text block, never `+`** (Java 15+). End every line except the last with `\`
  so the template stays **one line**. Without it, the line breaks go into the log entry and split
  it in text output. Put the closing `"""` on the last line, keep a space before each `\`, and
  pass values as arguments; never `.formatted()` or `String.format`, which build the string even
  when the level is off. Before Java 15, use one long literal.

```java
// ❌ concatenation: easy to slip a value in, and the template no longer reads as one sentence
LOGGER.warn("Shipment rescheduled after carrier rejection "
        + "shipmentId={} carrier={} attempt={}", shipment.id(), carrier, attempt);

// ✅ one-line template, values stay arguments (text output; see Structured logging for fields)
LOGGER.warn("""
        Shipment rescheduled after carrier rejection \
        shipmentId={} carrier={} attempt={}""", shipment.id(), carrier, attempt);
```

- **Levels deliberately:** TRACE (rare low-level), DEBUG (diagnostics), INFO (major events),
  WARN (recoverable/unexpected), ERROR (failures needing investigation).
- **Preserve stack traces:** pass the exception as the last arg (`LOGGER.error("Charge failed paymentId={}", id, ex)`;
  fluent API: `setCause(ex)`), never just `ex.getMessage()`.
- **Log once** at the boundary where the error is best understood; not in tight loops/getters.
- **Never log sensitive data:** no passwords, tokens, card numbers, PII, or full request/response
  payloads. Log **identifiers and counts** (IDs, status, sizes), not whole objects.

```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class PaymentProcessor {
    private static final Logger LOGGER = LoggerFactory.getLogger(PaymentProcessor.class);

    public Receipt process(final Payment payment) {
        LOGGER.atInfo()
                .addKeyValue("paymentId", payment.id())
                .addKeyValue("amountMinor", payment.amountMinor())
                .log("Processing payment");
        // never log cardNumber/cvv/tokens
        ...
    }
}
```

## Structured logging

**Output format is configuration, not code.** Choose JSON or text in config: Spring Boot
`logging.structured.format.console=ecs|logstash|gelf` (3.4+), Quarkus `quarkus-logging-json`, else
the backend's JSON layout (Micronaut: Logback + logstash-logback-encoder). Add, rename, mask and
truncate fields with the format's options. A documented extension point (Boot's
`StructuredLoggingJsonMembersCustomizer`) comes only after the options run out, and never a custom
appender or wrapper logger that parses or rewrites messages. Write where the platform collects
(usually stdout). Use JSON wherever logs are shipped: OWASP advises against unstructured text, and
JSON escapes CR/LF injection, which placeholders alone don't. Keep readable text locally, switched
per profile or environment.

**Before writing logging config, a test of log output, or advice specific to one backend, read the
project backend's reference:**

| Backend / topic                                                     | Read                    |
|---------------------------------------------------------------------|-------------------------|
| Fluent API, how each backend renders key-values, MDC, bridges       | `references/slf4j.md`   |
| Logback: Boot formats, logstash-logback-encoder, `%kvp`, testing    | `references/logback.md` |
| Log4j2: Boot formats, JSON Template Layout, `%X`, arbiters, testing | `references/log4j2.md`  |

A structured format turns the **MDC and key-value pairs** into fields. It does **not** parse the
message: an id in `"Order {} shipped"` stays free text, so a query can't filter `orderId = …`.
Switching the format on is not enough.

**Queried values → key-value fields** (SLF4J 2.x fluent API): anything someone will filter, group
or alert on (entity ids, outcomes, counts, durations). Keep the message template constant; OWASP
asks for this, and it lets identical events group. Constant means nothing is concatenated or
formatted in; in structured output a `{}` value also makes the rendered `message` vary per event.

```java
// ❌ the order id is only searchable as text, even with an ECS format
LOGGER.info("Order {} shipped via {}", order.id(), carrier);

// ✅ fields for the values; the message is constant and groupable
LOGGER.atInfo()
        .addKeyValue("orderId", order.id())
        .addKeyValue("carrier", carrier)
        .log("Order shipped");
```

- **Cost:** more verbose than one line. Reserve it for values that will be queried; human-only
  detail can stay a `{}` placeholder.
- **MDC vs key-values:** MDC holds **request-wide** context (request, tenant, user) set once at the
  boundary; key-values hold **this line's** values. A per-line `MDC.put` leaks into later lines
  unless removed, and MDC values are strings only.
- **High cardinality is fine in a field** (ids are the point). It is not fine as a log label or
  index key (e.g. Loki labels) or a metric tag.
- **Plain-text output** renders key-values only if the pattern includes them (Logback `%kvp`,
  Log4j2 `%X`; see the references). Add them to the pattern rather than dropping fields. `%kvp`
  double-quotes every value (`orderId="o-42"`), which logfmt parsers accept; the quoting rule
  below is for `key={}` text you write yourself.
- **On Log4j2,** SLF4J key-values arrive as context data (like MDC) and **as strings**, so every
  format that prints MDC prints them.

**Text-only output** (the pipeline only takes text, and config can't be changed): use consistent
`key={}` pairs, not prose. This is the logfmt style that Datadog, Loki and New Relic parse, and a
text search can anchor on the key. Don't introduce the fluent API there.

```java
// ❌ prose: the id has no key to search on
LOGGER.info("Order {} shipped via {}", order.id(), carrier);

// ✅ grep 'orderId=o-42'
LOGGER.info("Order shipped orderId={} carrier={}", order.id(), carrier);
```

**Key naming:** one convention per codebase, documented once and shared by key-values, `key={}`
pairs and MDC. The existing convention wins; for new code use **compound camelCase**
(`orderId`, `orderStatus`, `durationMs`, `itemCount`). No vendor convention is universal: OTel uses `trace_id`,
ECS uses `trace.id`, Datadog uses `dd.trace_id`. Compound keys stay clear of the formats' own
lowercase fields and stay flat in every format (ECS nests dotted keys from Boot 3.5). Rules that
keep lines from being dropped:

- **Never** a key that a format writes itself or the root of one (`message`, `log`, `service`,
  `process`, `ecs`, `log.level`, `service.name`), or a key that prefixes another (`order` beside
  `order.id`; clashes from Boot 3.5, where ECS nests dotted keys). Boot's ECS format drops the
  whole line. The only trace is the backend's internal
  status error, which stops after the first couple of failures; later drops are silent.
- **Never** the same key in MDC and in key-values: drop the key-value when MDC already carries it
  (on Logback, ECS drops the line; on Log4j2, the key-value silently wins).
- **Don't hand-set trace ids.** The tracer injects them (Boot + Micrometer Tracing: `traceId`/`spanId`;
  OTel agent: `trace_id`/`span_id`).
- **Map to a platform schema** (ECS `event.duration`, Datadog `usr.id`) with format config
  (`logging.structured.json.rename`) or the platform's pipeline remapper, not in code.
- **Never reuse a key with a different meaning** (`id` for an order here, a shipment there breaks
  every query). Values follow the sensitive-data rule: never PII or secrets.

**Quoting placeholders: never in structured output, and only for free text in text output.** House
rule; no standard covers it. Asked to quote everything? Decline in one line: "JSON already
delimits and escapes each field, so quotes would only add literal quote characters to the data."
In text-only output, put logfmt double quotes around **free-text**
values that may be empty or contain spaces (`reason="{}"`), so logfmt parsers keep the pair; ids,
counts and enums stay unquoted. This doesn't escape a `"` inside the value; if free text can carry
quotes and must be parsed, that's a reason to ship JSON.
Brackets (`[{}]`) and single quotes aren't logfmt.

**Test the fields, not the text.** Assert the key-values on the captured event (`ListAppender`
for each backend) rather than the exact message wording. To prove the config emits them,
capture the encoded JSON and assert the field (see the backend reference).

## Correlation

- **Trace ids come from the tracer** (see Key naming). Put your own request-wide context
  (requestId, tenantId, userId) in **MDC** at the entry boundary (filter/interceptor) and **remove
  exactly the keys you put** in `finally` (or scope them with `MDC.putCloseable`) to avoid
  thread-pool leakage. Put only keys no outer layer owns: removal, including `putCloseable`'s,
  deletes the key and does not restore an earlier value. Never `MDC.clear()` in request code:
  the tracer's `traceId`/`spanId` share the map and are still needed by outer filters and error
  handlers. The one exception is restoring an empty context after a thread handoff
  (`references/slf4j.md`).
- MDC is thread-local: it does not follow work onto executors, `@Async`, reactive operators or
  `StructuredTaskScope` forks. Use the framework's propagation (Spring: a `TaskDecorator`, Reactor
  context propagation; see `references/slf4j.md`) or copy it by hand.

```java
try (MDC.MDCCloseable ignored = MDC.putCloseable("requestId", requestId)) {
    handle(request);      // removes requestId on exit; the tracer's keys stay
}
```

## Metrics & tracing

- **Metrics:** use the project's metrics facade — **Micrometer** (`MeterRegistry`) in Spring — for
  counters/timers/gauges; don't hand-roll. Name consistently (`orders.placed`), tag with low
  cardinality (avoid user ids as tags). Time critical paths with a `Timer`.
- **Tracing:** prefer **OpenTelemetry** (or the project's tracer). Don't manually thread span/trace
  ids through method signatures — propagate via context (the tracer or agent mirrors the trace id
  into MDC so logs correlate with spans). Instrument at boundaries (HTTP, messaging, DB), not every method.
- Emit telemetry as a side concern: it must not change control flow or behavior.

```java
public final class PaymentProcessor {
    private final Timer chargeTimer;

    public PaymentProcessor(final MeterRegistry registry) {
        this.chargeTimer = registry.timer("payments.charge");   // stable name, no per-user tags
    }

    public Receipt charge(final Payment payment) {
        return chargeTimer.record(() -> gateway.charge(payment));
    }
}
```

**Time in `finally`.** Manual timing (elapsed-time logs, `Timer.Sample`) must stop/log in a
**`finally`** block — placed after the call, an exception skips it, losing timing for exactly the
calls you care about. `Timer.record(...)` does this for you.

```java
// ❌ skipped when charge() throws
final long start = System.nanoTime();
final Receipt receipt = gateway.charge(payment);
LOGGER.debug("charge durationMs={}", (System.nanoTime() - start) / 1_000_000);

// ✅ recorded on success and failure alike
final Timer.Sample sample = Timer.start(registry);
try {
    return gateway.charge(payment);
} finally {
    sample.stop(chargeTimer);
}
```

## Retrofitting existing code

Asked to "improve the logging/observability" of existing code? Work per **unit of work**
(request/message/job), not per statement:

1. **Correlate first:** MDC ids at the entry boundary, removed in `finally` (`MDC.remove` or
   `putCloseable`, never `MDC.clear()`).
2. **Replace offenders:** `System.out` / `printStackTrace()` / concatenation / ids in prose → facade with
   key-value fields, or `key={}` pairs for text-only output, per
   [Structured logging](#structured-logging).
3. **Narrate the unit of work with the full level palette:**
    - **INFO** — start and outcome: identifiers + counts, one line each, never per item
    - **DEBUG** — per-item / per-step detail inside loops and branches
    - **WARN** — recoverable anomalies: retries, fallbacks, skipped items, **partial success**
      (a WARN `Order partially fulfilled` with `fulfilledCount`/`lineCount` fields beats an INFO
      that hides the mismatch in two numbers)
    - **ERROR** — the unit of work failed; exception as last arg, once, at the boundary
4. **Measure rates/latency with metrics:** a `Timer` on the critical path, `Counter`s for
   failure/skip events. Log a duration only when someone needs it per event, from `finally`.
5. **Sweep before finishing:** no PII/secrets/payloads crept in; values that will be queried are
   key-value fields, not only message text; telemetry changed no behavior.

## Common mistakes

| Rationalization                                   | Reality                                                                          |
|---------------------------------------------------|----------------------------------------------------------------------------------|
| "`"user: " + name`"                               | Use `{}` placeholders — concatenation allocates even when the level is off.      |
| "`java.util.logging` is built in"                 | Use the project facade (SLF4J/Log4j2); don't add a framework.                    |
| "Split the long message with `+`"                 | Use a text block ending each line with `\`; values stay `{}` arguments.          |
| "Log the whole request to debug"                  | Never log secrets/PII/full payloads; log identifiers.                            |
| "`log.error(e.getMessage())`"                     | Drops the stack trace — pass the exception.                                      |
| "I'll pass the traceId as a parameter everywhere" | The tracer puts it in MDC; propagate context, remove your MDC keys in `finally`. |
| "A `userId` tag on the metric is handy"           | High-cardinality tags blow up metrics storage; tag low-cardinality only.         |
| "Log the duration after the call returns"         | An exception skips it — stop/log timing in `finally`, or use `Timer.record`.     |
| "The ECS format makes `{}` ids queryable"         | It only fields MDC and key-values — queried ids go in `addKeyValue`.             |
| "A custom appender will add the fields we need"   | Configure the format (fields, rename, mask); code hooks only as a last resort.   |
| "Quote every `{}` to be safe"                     | JSON already delimits values; in text, logfmt-quote free text only.              |

## Red flags — stop

- `+` inside a logging call (including between literals); `System.out`/`System.err`; a new logging
  framework
- A multi-line text block in a logging call without `\` line continuations, or with `.formatted()`
- A queried value (entity id, outcome) only in message text — not a key-value field / `key={}` pair
- A custom appender/encoder/layout or wrapper logger where configuration would do
- A log key that is a format field or its root (`message`, `log`, `service`), prefixes another key, or
  is also in MDC
- A secret/token/card number/PII or whole payload in a logging call; logging `e.getMessage()` instead
  of the exception
- `MDC.put` without a matching `MDC.remove()` in `finally` (or `putCloseable`); `MDC.clear()` in
  request code
- Hand-rolled counters/timers instead of Micrometer; high-cardinality metric tags
- A duration log or `Timer.Sample.stop` that isn't in a `finally` block
- Telemetry that alters control flow
