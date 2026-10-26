# SLF4J 2.x: fluent API, key-values, MDC, testing

**Docs:** [SLF4J manual](https://www.slf4j.org/manual.html)
· [FAQ](https://www.slf4j.org/faq.html)
· [Error codes](https://www.slf4j.org/codes.html)
· [Legacy bridges](https://www.slf4j.org/legacy.html)
· [`LoggingEventBuilder`](https://www.slf4j.org/api/org/slf4j/spi/LoggingEventBuilder.html)
· [Logback MDC](https://logback.qos.ch/manual/mdc.html)

SLF4J is the facade; **the backend decides what reaches the output**. Write code against SLF4J,
then make the backend emit fields through configuration (`logback.md`, `log4j2.md`).

## Contents

- Providers and bridges
- Fluent API
- How each backend renders key-values
- Laziness and exceptions
- MDC
- Testing

## Providers and bridges

- 2.x finds its backend with `ServiceLoader` (1.x used `StaticLoggerBinder`). Exactly **one**
  provider on the runtime classpath: none prints "No SLF4J providers were found" and silently
  drops every line (NOP); several print a warning and pick one arbitrarily. 1.x bindings next to a
  2.x API are ignored. Fix the dependency tree; don't add code. `-Dslf4j.provider=<class>` (2.0.9+)
  can force a provider.
- Route other APIs into SLF4J with bridges: `jul-to-slf4j`, `jcl-over-slf4j`, `log4j-over-slf4j`
  (log4j 1.x only). Never pair a bridge with the binding to the same API (`jul-to-slf4j` +
  `slf4j-jdk14`, `jcl-over-slf4j` + `slf4j-jcl`, `log4j-over-slf4j` + `slf4j-reload4j`): that loops
  forever. With `jul-to-slf4j` on Logback, install `LevelChangePropagator`, or disabled JUL
  statements get expensive.

## Fluent API

```java
LOGGER.atInfo()
        .addKeyValue("orderId", order.id())
        .addKeyValue("carrier", carrier)
        .log("Order shipped");

LOGGER.atError()
        .addKeyValue("paymentId", payment.id())
        .setCause(ex)                 // the fluent equivalent of a trailing Throwable
        .log("Charge failed");
```

- Methods: `addKeyValue(key, value | Supplier)`, `addArgument`, `addMarker`, `setCause`,
  `setMessage`, `log()`. Without the final `log()` nothing is logged.
- `KeyValuePair` has public final fields `key` and `value`, and `equals`.
- Keep the message template constant. `{}` placeholders still work (`.log("Retry {} of {}", n,
  max)`) for detail nobody queries.
- On a Log4j2-only codebase that already uses the Log4j API, its `MapMessage` is a legitimate
  alternative that keeps value types (`log4j2.md`). Don't mix the two styles in one codebase.

## How each backend renders key-values

| Backend                             | JSON output                                                                      | Plain-text output                     |
|-------------------------------------|----------------------------------------------------------------------------------|---------------------------------------|
| Logback                             | Own fields, types kept (Boot formats, LLE); `kvpList` of strings (`JsonEncoder`) | Dropped unless the pattern has `%kvp` |
| Log4j2 (`log4j-slf4j2-impl`)        | Context data, like MDC, **as strings**                                           | Via `%X`, not `%K`/`%map`             |
| `slf4j-simple`, `slf4j-jdk14` (JUL) | n/a                                                                              | Prefixed to the message as `k=v`      |

On Log4j2 the pairs are put into the `ThreadContext` for that one call and then removed. Key
collisions per backend: see SKILL.md (Key naming).

## Laziness and exceptions

- With the level disabled, `atDebug()` returns a no-op builder, so suppliers are never called.
  With the level enabled, a supplier runs when it is **added**, not at `log()`. Suppliers save work
  only for disabled levels.
- Parameterized calls avoid string building when the level is off. Guard with
  `isDebugEnabled()` only when computing an **argument** is expensive.
- Classic API: a `Throwable` as the **last** argument is logged with its stack trace (it needs no
  `{}`). Fluent API: use `setCause`.

## MDC

- Request-wide context only (requestId, tenantId, userId), set at the boundary. Values are strings.
  `MDC.putCloseable(key, value)` scopes a key with try-with-resources.
- Trace ids are the tracer's job: Micrometer Tracing (Spring Boot) puts `traceId`/`spanId` in MDC,
  and the OTel Java agent puts `trace_id`/`span_id`. Don't put them yourself.
- MDC is thread-local and does **not** follow work to other threads (executors, `@Async`, reactive
  operators, virtual threads you start, `StructuredTaskScope` forks). Prefer the framework's
  propagation:
  - Spring Boot 4.1+: `spring.task.execution.propagate-context=true` (`@Async`, Boot-built task
    executors). Earlier (Spring Framework 6.1+): a `ContextPropagatingTaskDecorator` bean, which
    Boot applies to the executors it builds; it needs `io.micrometer:context-propagation`.
  - Reactor (Boot 3.x and 4.x): `spring.reactor.context-propagation=auto`.
  - Micronaut: `MdcPropagationContext`.
  - Otherwise copy it by hand:

```java
final Map<String, String> context = MDC.getCopyOfContextMap();   // on the submitting thread
executor.submit(() -> {
    final Map<String, String> previous = MDC.getCopyOfContextMap();  // the worker's own context
    replaceMdc(context);
    try {
        process(item);
    } finally {
        replaceMdc(previous);    // restore, don't clear: the task may run on the caller's thread
    }
});

private static void replaceMdc(final Map<String, String> context) {
    if (context == null) {
        MDC.clear();             // no previous context on this thread: nothing to preserve
    } else {
        MDC.setContextMap(context);
    }
}
```

- `slf4j-simple` and `slf4j-nop` ignore MDC entirely.

## Testing

Assert fields (key-values, MDC, level), not exact message wording. Wording changes break such
tests without any loss of signal. Assert only the events someone relies on: operational outcomes
and audit or security events. Options, in order:

1. **Backend capture.** This tests what you ship. See the Testing section of `logback.md` or
   `log4j2.md`.
2. **Encoded output.** Spring Boot `OutputCaptureExtension` plus JSON parsing, with the structured
   format enabled in the test. This proves the config emits the field, not just that the code
   added it.
3. **Libraries:** [LogCaptor](https://github.com/Hakky54/log-captor) (Logback-backed;
   `LogEvent.getKeyValuePairs()`, `getDiagnosticContext()` for MDC) or
   [slf4j-test](https://github.com/valfirst/slf4j-test) (replaces the backend on the test classpath;
   `getKeyValuePairs()`, `getMdc()`). Add one only if the project lacks a simpler path.
