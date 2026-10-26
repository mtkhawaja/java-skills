---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our Spring Boot 3.5 service uses spring-boot-starter-log4j2 and writes plain-text logs to the console; they are shipped to Elasticsearch. We want to filter by order id and payment id there. I was going to write a custom Log4j2 appender that parses ids out of the message and adds them as JSON fields. Here's a typical line:

```java
log.info("Payment {} captured for order {}", payment.id(), order.id());
```

How should we do this?
