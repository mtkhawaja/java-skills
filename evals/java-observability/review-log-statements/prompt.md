---
tags: [java-observability]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Review these log statements:

```java
log.info("user: " + user);
System.out.println("request handled");
log.error(e.getMessage());
java.util.logging.Logger.getLogger("app").info("fallback path");
log.debug("token=" + authToken + " body=" + requestBody);
```
