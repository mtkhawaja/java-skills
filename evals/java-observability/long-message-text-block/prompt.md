---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Tidy up these log statements in our Java 21 service (SLF4J + Logback, plain-text console output we search with grep). Output the revised statements.

```java
log.warn("Payment capture deferred because the issuer returned a soft decline; will retry "
        + "on the next settlement window for payment " + payment.id() + " (attempt "
        + attempt + " of " + maxAttempts + ")");
log.info(String.format("Shipment %s handed to carrier %s after %d ms in the dispatch queue",
        shipment.id(), carrier, waitedMs));
```
