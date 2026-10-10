---
tags: [java-testing]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our Maven build's `mvn test` takes six minutes because a few simulation tests and our Testcontainers tests all run under Surefire, and every run prints thousands of DEBUG log lines. I want a fast inner loop for day-to-day work, the full suite before merging, and quiet test output that I can turn up when one test fails. Show the pom.xml and logging config.
