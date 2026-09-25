---
tags: [java-concurrency]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Code review: what is wrong with this and how do you fix it?

```java
List<Report> reports = accounts.parallelStream()
    .map(account -> reportClient.fetch(account.id()))   // remote HTTP call
    .toList();
```
