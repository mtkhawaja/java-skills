---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Add timing to this method so we can see how long the gateway call takes, in both logs and metrics:

```java
public Receipt charge(Payment payment) {
    return gateway.charge(payment);
}
```
