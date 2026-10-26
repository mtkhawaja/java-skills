---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Clean up these log statements. The service uses Logback with a plain-text console pattern. Our log pipeline only accepts plain text and we search it with grep, so the output format can't change. Output the revised statements.

```java
log.info("Payment " + payment.id() + " captured for " + payment.amountMinor());
log.warn("Retrying shipment {} after {} attempts", shipment.id(), attempts);
log.info("Refund done: {} / {}", refund.id(), refund.status());
```
