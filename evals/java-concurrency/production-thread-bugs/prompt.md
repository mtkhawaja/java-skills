---
tags: [java-concurrency]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Two issues in production: (1) a metrics-flush thread reads a plain boolean field 'running' that the shutdown hook sets to false, but the loop never stops; (2) under virtual threads, throughput collapses when requests enter a synchronized block that makes a JDBC call. Diagnose and fix both.
