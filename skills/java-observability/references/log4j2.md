# Log4j2: structured output by configuration

**Docs:** [Spring Boot logging](https://docs.spring.io/spring-boot/reference/features/logging.html)
· [JSON Template Layout](https://logging.apache.org/log4j/2.x/manual/json-template-layout.html)
· [Pattern Layout](https://logging.apache.org/log4j/2.x/manual/pattern-layout.html)
· [Thread Context](https://logging.apache.org/log4j/2.x/manual/thread-context.html)
· [Configuration and arbiters](https://logging.apache.org/log4j/2.x/manual/configuration.html)
· [Async loggers](https://logging.apache.org/log4j/2.x/manual/async.html)
· [Log4j security FAQ](https://logging.apache.org/security/faq.html)

Configuration first (SKILL.md, Structured logging). Stop at the first option that fits:

1. **Spring Boot's built-in formats** (Boot 3.4+, with `spring-boot-starter-log4j2`).
2. **JSON Template Layout** (`log4j-layout-template-json`) with a bundled template. `JsonLayout`
   is deprecated, and `PatternLayout` is "not intended for structured logging" (Log4j docs).

## Contents

- How SLF4J key-values arrive
- Spring Boot structured formats
- JSON Template Layout
- Plain-text patterns
- Switching format per environment
- Production settings
- Testing

## How SLF4J key-values arrive

With `log4j-slf4j2-impl`, `addKeyValue` pairs go into the `ThreadContext` for that one call. They
are context data, exactly like MDC entries:

- Every layout or format that prints context data prints them. Nothing extra is needed.
- Values become **strings** (`String.valueOf`), so numeric types are lost. Convert or map the field
  in the log backend if you need numeric queries.
- A pair with the same key as an MDC entry silently overrides that entry for the line. Keep the
  two key sets distinct.
- **Log4j API instead of SLF4J?** The Log4j maintainers recommend their own API: its `Message`
  types carry structure instead of strings. On a Log4j2-only codebase already on the Log4j API,
  `MapMessage`/`StringMapMessage` (rendered as fields by the JSON Template Layout `message`/`map`
  resolvers) and `CloseableThreadContext.put(...)` are legitimate. Use one style per codebase; on a
  codebase using SLF4J, stay on `addKeyValue`.

## Spring Boot structured formats

The properties are the same as for Logback (`logback.md`): `logging.structured.format.console=ecs`
(or `logstash`, `gelf`), `logging.structured.json.include|exclude|rename|add`, and
`logging.structured.json.stacktrace.*` (Boot 3.5+). The formatters read the event's context data,
so MDC entries and key-values both become fields, **as strings** (`"itemCount":"3"`). ECS nests
dotted keys from Boot 3.5 (`{"order":{"id":"o-42"}}`). As on Logback, a key that is a format field
or its root, or that prefixes another key, **drops the whole line**, with only an `ERROR An
exception occurred processing Appender` status message. An MDC/key-value duplicate is not dropped:
the key-value silently wins (above). In a
custom `log4j2-spring.xml`, keep Boot's layout:
`<StructuredLogLayout format="${sys:CONSOLE_LOG_STRUCTURED_FORMAT}"/>`.

## JSON Template Layout

```xml
<Console name="CONSOLE">
  <JsonTemplateLayout eventTemplateUri="classpath:EcsLayout.json" maxStringLength="2048">
    <EventTemplateAdditionalField key="service.name" value="${env:SERVICE_NAME:-orders}"/>
  </JsonTemplateLayout>
</Console>
```

- Bundled templates: `EcsLayout.json` (the default), `LogstashJsonEventLayoutV1.json`,
  `GelfLayout.json`, `GcpLayout.json`. Pick the one your log backend ingests; don't write a
  template from scratch.
- In the ECS template, context data (MDC and key-values) becomes flat top-level fields, as
  strings, with dotted keys kept as written (`"order.id":"o-42"`); Boot's ECS format nests them
  instead. In the Logstash template, context data is nested under `mdc`.
- Add static fields with `<EventTemplateAdditionalField>`. Pick out single keys with the `mdc`
  resolver (`{"$resolver":"mdc","key":"traceId"}`). Truncate stack traces with the `exception`
  resolver's `stackTrace.stringified.truncation` options.
- `maxStringLength` caps oversized values. JSON encoding also neutralizes CR/LF log injection,
  which parameterized messages alone don't (OWASP).

## Plain-text patterns

```xml
<PatternLayout pattern="%d{ISO8601} %-5level [%t] %c{1.} - %msg %X%n"/>
```

- `%X` prints all context data, **including SLF4J key-values**, as `{k1=v1, k2=v2}`.
  `%X{traceId}` prints one key.
- `%K`/`%map` print only `MapMessage` fields, never SLF4J key-values.
- Text gets no CR/LF escaping. The Log4j security FAQ treats that as the user's job: use
  `%enc{%m}{CRLF}` (and `%enc{…}{CRLF}` around other user-influenced fields), or avoid
  `PatternLayout` in production.

## Switching format per environment

JSON in deployed environments, text locally, chosen by configuration:

- Spring Boot: the `logging.structured.format.console` property per profile, or
  `<SpringProfile name="prod | staging">` in `log4j2-spring.xml`.
- Plain Log4j2: use an arbiter (2.15+). Substitutions `${env:VAR:-default}` and `${sys:prop}`
  work everywhere.

```xml
<Console name="CONSOLE">
  <Select>
    <EnvironmentArbiter propertyName="LOG_FORMAT" propertyValue="text">
      <PatternLayout pattern="%d %-5level %c{1.} - %msg %X%n"/>
    </EnvironmentArbiter>
    <DefaultArbiter>
      <JsonTemplateLayout eventTemplateUri="classpath:EcsLayout.json"/>
    </DefaultArbiter>
  </Select>
</Console>
```

Write where the platform collects: usually the console (stdout).

## Production settings

- Location info (`%C`, `%F`, `%L`, `%M`, `%l`) is expensive. It's off by default for async
  loggers, where enabling it (`includeLocation="true"`) costs even more. Use the logger name
  (`%c`) instead.

## Testing

`log4j-core-test` provides a `ListAppender` and the `@LoggerContextSource` JUnit 5 extension. Key-values
are asserted as context data:

```java
@LoggerContextSource("log4j2-test.xml")   // declares <List name="LIST"/>
class ShippingServiceTest {
    @Test
    void logsOrderIdAsField(@Named("LIST") final ListAppender appender) {
        service.ship(order);

        final LogEvent event = appender.getEvents().get(0);
        assertThat(event.getLevel()).isEqualTo(Level.INFO);
        assertThat(event.getContextData().<String>getValue("orderId")).isEqualTo("o-42");
    }
}
```

`ListAppender`, `@LoggerContextSource` and `@Named` come from `org.apache.logging.log4j.core.test.*`.
`log4j-core-test` pulls in an old `junit-platform-launcher`, so import `org.junit:junit-bom` in
`<dependencyManagement>`. Otherwise discovery fails with "TestEngine with ID 'junit-jupiter'
failed to discover tests".

To prove the **configuration** emits the field, use Spring Boot's `OutputCaptureExtension` with the
structured format on, then parse each line as JSON and assert the field.
