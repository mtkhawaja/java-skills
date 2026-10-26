---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

A reviewer wants us to quote all log placeholders as '{}' so empty values are visible. Apply that to these lines (Spring Boot 3, ECS structured logging on) and output the revised lines.

```java
log.atInfo().addKeyValue("orderId", order.id()).addKeyValue("lineCount", lines.size()).log("Order received");
log.info("Shipment cancelled shipmentId={} reason={}", shipment.id(), cancellation.reason());
```
