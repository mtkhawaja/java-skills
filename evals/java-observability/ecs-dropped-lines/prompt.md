---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

We switched our Spring Boot 4 service (Logback) to `logging.structured.format.console=ecs`. Some log lines never show up anymore, with no error in the app's output. A filter puts `orderId` into the MDC for every request. These are the lines that go missing:

```java
log.atInfo().addKeyValue("orderId", order.id()).addKeyValue("message", note).log("Order updated");
log.atInfo().addKeyValue("order", order.status()).addKeyValue("order.id", order.id()).log("Order status");
```

What's wrong and how do we fix it?
