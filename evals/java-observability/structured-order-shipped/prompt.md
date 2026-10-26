---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our Spring Boot 3 service logs JSON with `logging.structured.format.console=ecs` (SLF4J 2 + Logback). We can't filter logs by order in our log search. Fix the logging in this method and output the revised method.

```java
public void ship(Order order, Customer customer) {
    Shipment shipment = carrier.book(order, customer.address());
    log.info("Order {} shipped to {}", order.id(), customer.address());
    log.debug("Shipment {} booked with carrier {}", shipment.id(), shipment.carrier());
}
// record Customer(String id, String name, String email, String address)
```
