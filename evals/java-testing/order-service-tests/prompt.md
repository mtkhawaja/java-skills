---
tags: [java-testing]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

A Spring Boot 3.4 service (Java 21, Maven, Spring Data JDBC, PostgreSQL in production) has an OrderService with a DiscountPolicy collaborator and an OrderRepository. Write (1) a unit test class verifying the discount is applied before saving, with no real database, and (2) an integration test class verifying an order can be persisted and read back through the real repository. Also state how the integration tests are kept out of the fast mvn test run.
