---
tags: [java-maven]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Add JaCoCo to our single-module Maven build. Coverage today is 63.4% lines and 48.9% branches. I don't want an arbitrary target, but the build should fail if coverage drops. We already pass `<argLine>-Xmx1g</argLine>` to Surefire. Show the pom.xml changes.
