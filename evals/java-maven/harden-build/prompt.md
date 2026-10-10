---
tags: [java-maven]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our single-module Maven service compiles with <maven.compiler.release>17</maven.compiler.release>; CI builds it on JDK 21. Code review keeps catching the same things: Optional used as a parameter or field, locals and parameters missing final, ternaries wrapped across several lines, plus the occasional real bug and NullPointerException. We want to adopt JSpecify, opting packages in through package-info.java. Harden the build so all of that fails automatically. Show the pom.xml changes and any config files.
