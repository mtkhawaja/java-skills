---
tags: [java-concurrency]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Java 21 service: implement enrichAll(List<Item> items) which calls enrichmentClient.enrich(item) — a blocking HTTP call taking ~200ms — for up to 10,000 items and returns the enriched results. Make it fast.
