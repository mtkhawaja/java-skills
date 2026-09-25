---
tags: [java-testing]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our integration suite is slow and flaky: every IT class declares its own non-static @Container PostgreSQLContainer, several tests pass only when run in order because earlier tests insert rows they rely on, and someone proposed switching the suite to H2 to speed it up. What do you change?
