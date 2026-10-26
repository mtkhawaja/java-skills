# Logback: structured output by configuration

**Docs:** [Spring Boot logging](https://docs.spring.io/spring-boot/reference/features/logging.html)
· [Logback layouts](https://logback.qos.ch/manual/layouts.html)
· [Logback encoders](https://logback.qos.ch/manual/encoders.html)
· [Conditional configuration](https://logback.qos.ch/manual/configuration-conditional.html)
· [Async appender](https://logback.qos.ch/manual/appenders-async-sift.html)
· [logstash-logback-encoder](https://github.com/logfellow/logstash-logback-encoder)

Configuration first (SKILL.md, Structured logging). Stop at the first option that fits:

1. **Spring Boot's built-in formats** (Boot 3.4+). No dependency, no XML.
2. **logstash-logback-encoder (LLE)** for apps outside Spring Boot, or when you need masking or
   per-field control Boot doesn't offer.
3. **Logback `JsonEncoder`** (1.3.8+) only when no dependency can be added. It can't rename,
   mask or shorten anything, and it writes key-values as a `kvpList` array of single-entry objects with string values
   (`[{"orderId":"o-42"},{"itemCount":"3"}]`) that's awkward to query.

## Contents

- Spring Boot structured formats
- logstash-logback-encoder
- Plain-text patterns
- Switching format per environment
- Production settings
- Testing

## Spring Boot structured formats

```properties
# ecs, logstash or gelf
logging.structured.format.console=ecs
# defaults to spring.application.name
logging.structured.ecs.service.name=orders
logging.structured.json.exclude=process.thread.name
logging.structured.json.rename.process.pid=procid
logging.structured.json.add.environment=prod
# stacktrace.* needs Boot 3.5+
logging.structured.json.stacktrace.max-length=4096
logging.structured.json.stacktrace.include-common-frames=false
```

- All three formats emit **every MDC entry and every `addKeyValue` pair** as fields, with numbers
  kept as numbers (placement per format, next bullet). Values that are only in the message text are not fields.
- **ECS nests dotted keys** from Boot 3.5 (`order.id` → `{"order":{"id":…}}`; Boot 3.4 writes
  them flat); `logstash` keeps them flat; `gelf` prefixes `_`. In ECS, the key collisions listed in
  SKILL.md (Key naming) make the appender **drop the whole line**. The only trace is a Logback
  status error (`Duplicate nested pairs added under …`, `The name '…' has already been written`)
  for the first couple of failures; later drops are silent. Distinct compound keys (`orderStatus`)
  that aren't also in MDC avoid it.
- `json.include`/`exclude`/`rename` take the full ECS path (`process.pid`). `include` must list
  parent paths too, and excluding a leaf can leave an empty parent object.
- `logging.structured.format.file` does the same for the file appender.
- In a custom `logback-spring.xml`, keep Boot's encoder:
  `<encoder class="org.springframework.boot.logging.logback.StructuredLogEncoder">` with
  `<format>${CONSOLE_LOG_STRUCTURED_FORMAT}</format>`.
- `StructuredLoggingJsonMembersCustomizer` (`logging.structured.json.customizer`) is the documented
  code hook. Use it only when the properties can't express the change.

## logstash-logback-encoder

LLE 9.x needs Jackson 3 (Spring Boot 4). On Jackson 2, use the 8.x line, where the masking
element is `<jsonGeneratorDecorator class="…MaskingJsonGeneratorDecorator">` instead of
`<decorator>`. Logback ignores an unknown element with only a status error, so on 8.x the snippet
below would log passwords unmasked.

```xml
<appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
  <encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <customFields>{"service":"orders"}</customFields>
    <excludeMdcKeyName>sessionToken</excludeMdcKeyName>
    <throwableConverter class="net.logstash.logback.stacktrace.ShortenedThrowableConverter">
      <maxDepthPerThrowable>30</maxDepthPerThrowable>
      <rootCauseFirst>true</rootCauseFirst>
    </throwableConverter>
    <decorator class="net.logstash.logback.mask.MaskingJsonGeneratorDecorator">
      <path>password</path>
    </decorator>
  </encoder>
</appender>
```

- MDC entries, SLF4J key-values (types kept) and context properties become flat top-level fields
  by default. Collisions: see SKILL.md (Key naming).
  Filter them with `<includeMdcKeyName>`/`<excludeMdcKeyName>` and
  `<includeKeyValueKeyName>`/`<excludeKeyValueKeyName>`; you can't use include and exclude
  together.
- Rename fields with `<fieldNames>` (`[ignore]` drops one). Masking is a safety net, not
  permission to log sensitive data.
- Prefer `addKeyValue` to LLE's `StructuredArguments` and `Markers`. The LLE README recommends
  this too, and it keeps the code on the facade.

## Plain-text patterns

Key-values are **dropped** unless the pattern includes them:

```properties
# Spring Boot: a text pattern that keeps key-values and MDC
logging.pattern.console=%d{ISO8601} %-5level [%thread] %logger{36} - %msg %kvp %X%n
```

- `%kvp` prints key-values as `k="v"`. Double quotes are the default; `%kvp{NONE}` and
  `%kvp{SINGLE}` change that. `%maskedKvp{password}` (1.5.7+) prints `XXX` for the listed keys.
- `%X` prints the whole MDC; `%X{traceId:-none}` prints one key with a default.
- Text gets no CR/LF escaping. A value containing a newline forges a second log line (OWASP, CWE-117).
  Strip line breaks with `%replace(%msg){'[\r\n]+', ' '}` for any message that can carry user input.

## Switching format per environment

Use JSON in deployed environments and readable text locally, chosen by configuration:

- Spring Boot: set `logging.structured.format.console` in `application-prod.properties` (or with
  an env var such as `LOGGING_STRUCTURED_FORMAT_CONSOLE=ecs`). `<springProfile name="prod | staging">`
  works only in `logback-spring.xml`.
- Plain Logback: from 1.5.37, Janino `<if condition="…">` is **no longer evaluated**, even with
  Janino on the classpath. Neither branch runs and the only status message is a deprecation WARN,
  so the appenders it guarded are silently lost. Use `<condition>` (1.5.20+) at top level, with a
  `<root>` in each branch; its property lookup falls back to environment variables:

```xml
<condition class="ch.qos.logback.core.boolex.PropertyEqualityCondition">
  <key>LOG_FORMAT</key>
  <value>json</value>
</condition>
<if>
  <then><root level="INFO"><appender-ref ref="JSON"/></root></then>
  <else><root level="INFO"><appender-ref ref="TEXT"/></root></else>
</if>
```

Write where the platform collects: usually the console (stdout). Use a file appender only where
the platform's agent tails files (e.g. Datadog's recommended setup) or nothing collects stdout.

## Production settings

- Caller data (`%C`, `%F`, `%L`, `%M`, `%caller`, `includeCallerData`) is slow. Leave it off; the
  logger name already identifies the class.
- `AsyncAppender` defaults: `queueSize` 256, and TRACE/DEBUG/INFO events are **discarded** when
  less than 20% of the queue is free. Set `discardingThreshold` to 0 if INFO must not be lost.
  Stop the `LoggerContext` on shutdown (Spring Boot does this) or queued events are lost.

## Testing

Assert the key-values on the captured event, not the message wording:

```java
import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;          // Logback's Logger, not org.slf4j.Logger
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.slf4j.LoggerFactory;
import org.slf4j.event.KeyValuePair;

final Logger logger = (Logger) LoggerFactory.getLogger(ShippingService.class);
final ListAppender<ILoggingEvent> appender = new ListAppender<>();
appender.start();
logger.addAppender(appender);
try {
    service.ship(order);

    final ILoggingEvent event = appender.list.get(0);
    assertThat(event.getLevel()).isEqualTo(Level.INFO);
    assertThat(event.getKeyValuePairs())                 // null when none were added
            .isNotNull()
            .contains(new KeyValuePair("orderId", order.id()));   // equals compares the typed value
} finally {
    logger.detachAppender(appender);
}
```

To prove the **configuration** emits the field, enable the structured format in the test, capture
stdout with Spring Boot's `OutputCaptureExtension` (`CapturedOutput.getOut()`), parse each line
as JSON and assert the field.
