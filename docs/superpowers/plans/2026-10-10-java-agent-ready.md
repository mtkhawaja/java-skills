# java-agent-ready Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `java-agent-ready` skill that audits a Maven project for agentic-coding readiness
and applies user-picked improvements, plus the general conventions it relies on in `java-testing`
and `java-maven`.

**Architecture:** A user-invocable orchestrator skill (`skills/java-agent-ready/SKILL.md`) with one
reference file per agent-specific area. General-purpose rules (test split, quiet test output,
JaCoCo floor) live in the existing skills they belong to and are linked, not duplicated. Behaviour
is tested with `claude plugin eval` cases under `evals/`; repo structure with `./scripts/check.sh`.

**Tech Stack:** Markdown skills, YAML-frontmatter eval cases, bash scaffold scripts, `claude plugin
eval`, `./scripts/check.sh` (shellcheck, markdownlint, JSON/eval validation).

**Spec:** `docs/superpowers/specs/2026-10-10-java-agent-ready-design.md`

## Global Constraints

- Maven only; Gradle or no `pom.xml` → the skill stops and says so.
- No code formatter is ever added; generated AGENTS.md states "No formatter by design".
- Never weaken an existing check (Checkstyle, Error Prone, `-Werror`, JaCoCo floor) to pass a build.
- Fast loop: `./mvnw -q test -Pfast` (excludes `@Tag("slow")`); full: `./mvnw -q verify` runs everything.
- Test log level property: `test.log.level`, default `WARN`.
- JaCoCo floor = current line/branch coverage rounded down; no floor when there are no tests.
- Existing CLAUDE.md → merged into AGENTS.md, then `git mv CLAUDE.md AGENTS.md`; `CLAUDE.local.md` untouched.
- Nothing is committed by the skill; each applied area gets a suggested commit message.
- Versions are looked up at run time and pinned; references never hardcode a "latest" version.
- Repo rules (AGENTS.md): third-person "Use when…" description ≤1024 chars; SKILL.md body well
  under 500 lines; references one level deep, `## Contents` once past 100 lines; no
  time-sensitive phrasing; ≥3 eval cases per skill.
- Every eval case: `prompt.md` with frontmatter, `graders/skill-fired.md`, and at least one
  `type: llm` or `type: regex` grader. Graders judge the reply — never grant `Write`/`Edit`.
- Never reference external tool versions or doc formats from memory; verify against the source
  named in the task.

## Review Focus

1. **Multi-module reactor** — Failsafe/JaCoCo/wrapper config goes in the parent's
   `<pluginManagement>`/`<build>` once, not copied per module; `.editorconfig` and `mvnw` at the
   reactor root only. Pinned by: reference content check in Task 2 and Task 4, and an llm
   criterion in Task 1's `bare-project-audit` (two-module scaffold).
2. **Existing `argLine`** — JaCoCo's `prepare-agent` sets `argLine`; a project that already sets
   `<argLine>` silently drops the agent. Must use `@{argLine} <existing>`. Pinned by: Task 3
   content check and `coverage-floor` regex.
3. **Both CLAUDE.md and AGENTS.md already exist** — merge into AGENTS.md, don't overwrite either
   blindly. Pinned by: Task 6 content check.
4. **Spring Boot logging overrides** — `logging.level.*` in `application*.properties` beats
   `logback-test.xml`; quiet-output apply must check both. Pinned by: Task 2 content check.
5. **Non-Maven / red baseline build** — Gradle project or already-failing build must stop before
   any change. Pinned by: Task 8 SKILL.md content check and an llm criterion in Task 1.

---

### Task 1: Eval cases for `java-agent-ready` (red)

**Files:**
- Create: `evals/java-agent-ready/bare-project-audit/{case.yaml,prompt.md,scaffold.sh,graders/skill-fired.md,graders/criteria.md}`
- Create: `evals/java-agent-ready/apply-test-split/{case.yaml,prompt.md,scaffold.sh,graders/skill-fired.md,graders/failsafe.md,graders/renamed-it.md,graders/slow-tag.md,graders/fast-profile.md,graders/criteria.md}`
- Create: `evals/java-agent-ready/existing-claude-md/{case.yaml,prompt.md,scaffold.sh,graders/skill-fired.md,graders/git-mv.md,graders/criteria.md}`
- Create: `evals/java-agent-ready/hermetic-diagnosis/{case.yaml,prompt.md,scaffold.sh,graders/skill-fired.md,graders/criteria.md}`
- Modify: `evals/README.md` (the `case.yaml + scaffold.sh` bullet)

**Interfaces:**
- Produces: skill name `java-agent-ready` (graders match `"skill":"…java-agent-ready"`); area
  names used in criteria: project baseline, test split, quiet output, hermetic tests, feedback
  tooling, agent docs, JDTLS.

- [ ] **Step 1: `bare-project-audit`** — every `case.yaml` in this task is:

```yaml
schema_version: "1.1"
name: <case-dir-name>
context:
  scaffold_script: scaffold.sh
```

`prompt.md`:

```markdown
---
tags: [java-agent-ready]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

We're about to start using Claude Code heavily on this repo. Make it agent-ready.
```

`scaffold.sh` (two-module reactor, no wrapper, noisy logging, no Failsafe, no AGENTS.md):

```bash
#!/usr/bin/env bash
# Seeds a two-module Maven repo with none of the agent-ready pieces in place.
set -euo pipefail

mkdir -p api/src/main/java/com/acme/api api/src/test/java/com/acme/api \
  api/src/test/resources core/src/main/java/com/acme/core

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>acme-parent</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <modules>
    <module>core</module>
    <module>api</module>
  </modules>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

for m in core api; do
  cat >"${m}/pom.xml" <<XML
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.acme</groupId>
    <artifactId>acme-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
  </parent>
  <artifactId>acme-${m}</artifactId>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.0</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>ch.qos.logback</groupId>
      <artifactId>logback-classic</artifactId>
      <version>1.5.6</version>
    </dependency>
  </dependencies>
</project>
XML
done

cat >api/src/test/resources/logback-test.xml <<'XML'
<configuration>
  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder><pattern>%d %-5level %logger - %msg%n</pattern></encoder>
  </appender>
  <root level="DEBUG"><appender-ref ref="CONSOLE"/></root>
</configuration>
XML

cat >api/src/test/java/com/acme/api/OrderControllerTest.java <<'JAVA'
package com.acme.api;

import org.junit.jupiter.api.Test;

class OrderControllerTest {
    @Test
    void createsOrder() throws Exception {
        Thread.sleep(2000);
    }
}
JAVA
```

`graders/skill-fired.md`:

```markdown
---
type: tool_used
tool: Skill
input_match: '"skill"\s*:\s*"(?:[\w-]+:)?java-agent-ready"'
---
```

`graders/criteria.md`:

```markdown
---
type: llm
---

PASS only if the response satisfies every item below:

- Reports a status (present / partial / missing) for each area: project baseline (wrapper, pinned JDK, maven.config, .editorconfig), test split, quiet output, hermetic tests, feedback tooling, agent docs, JDTLS
- Cites evidence from this repo: no mvnw, root logger DEBUG in api's logback-test.xml, Thread.sleep in OrderControllerTest, no Failsafe, no AGENTS.md
- Treats it as a two-module reactor: wrapper, .editorconfig and shared plugin config at the root/parent, not per module
- Asks which areas to apply before changing anything, and does not claim to have changed files
- Runs (or asks to run) the existing build before proposing changes, and says it would stop to ask if that build is already failing

FAIL if any item is missing or contradicted.
```

- [ ] **Step 2: `apply-test-split`** — `prompt.md`:

```markdown
---
tags: [java-agent-ready]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

We already ran the agent-ready audit on this repo. Apply only the test split area: show the pom.xml changes and every test file you'd rename or annotate.
```

`scaffold.sh`:

```bash
#!/usr/bin/env bash
# Seeds a single-module repo whose slow tests all run under Surefire.
set -euo pipefail

mkdir -p src/test/java/com/acme/orders

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>orders</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.0</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>postgresql</artifactId>
      <version>1.20.1</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.3.1</version>
      </plugin>
    </plugins>
  </build>
</project>
XML

cat >src/test/java/com/acme/orders/CustomerRepositoryTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;

class CustomerRepositoryTest {
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Test
    void savesCustomer() {
        POSTGRES.start();
    }
}
JAVA

cat >src/test/java/com/acme/orders/PricingSimulationTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;

class PricingSimulationTest {
    // Monte Carlo over 50M quotes; ~40s on a laptop.
    @Test
    void convergesOnExpectedMargin() {
        double sum = 0;
        for (long i = 0; i < 50_000_000L; i++) {
            sum += Math.sqrt(i);
        }
    }
}
JAVA

cat >src/test/java/com/acme/orders/OrderTotalTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;

class OrderTotalTest {
    @Test
    void sumsLines() {
    }
}
JAVA
```

Graders (`skill-fired.md` as in Step 1, plus):

```markdown
<!-- graders/failsafe.md -->
---
type: regex
pattern: 'maven-failsafe-plugin[\s\S]*<goal>integration-test</goal>[\s\S]*<goal>verify</goal>'
---
```

```markdown
<!-- graders/renamed-it.md -->
---
type: regex
pattern: 'CustomerRepositoryIT'
---
```

```markdown
<!-- graders/slow-tag.md -->
---
type: regex
pattern: '@Tag\("slow"\)[\s\S]{0,200}PricingSimulationTest|PricingSimulationTest[\s\S]{0,400}@Tag\("slow"\)'
---
```

```markdown
<!-- graders/fast-profile.md -->
---
type: regex
pattern: '<id>fast</id>[\s\S]*<excludedGroups>slow</excludedGroups>'
---
```

(Each grader file contains only the frontmatter block; the HTML comment above names the file.)

`graders/criteria.md`:

```markdown
---
type: llm
---

PASS only if the response satisfies every item below:

- Plain `./mvnw verify` still runs every test, including the slow-tagged one; slow tests are excluded only under the `fast` profile
- OrderTotalTest is left alone (fast unit test)
- Applies only the test split area — no wrapper, JaCoCo, logging, or AGENTS.md changes
- Gives the fast and full commands and a suggested commit message, without claiming to have committed

FAIL if any item is missing or contradicted.
```

- [ ] **Step 3: `existing-claude-md`** — `prompt.md`:

```markdown
---
tags: [java-agent-ready]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

Set up the agent docs for this repo so any coding agent, not just Claude, picks them up. Show the files and any commands I should run.
```

`scaffold.sh`:

```bash
#!/usr/bin/env bash
# Seeds a repo with an existing CLAUDE.md and no AGENTS.md or fast profile.
set -euo pipefail

mkdir -p src/main/java/com/acme/billing src/main/generated/com/acme/billing/api

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>billing</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

touch mvnw && chmod +x mvnw

cat >CLAUDE.md <<'MD'
# billing

- Run tests with `./mvnw test`.
- `src/main/generated/` is produced by the OpenAPI generator — never edit it; regenerate with `./mvnw generate-sources`.
- Money is always `BigDecimal` with scale 2; never `double`.
MD
```

`graders/git-mv.md`:

```markdown
---
type: regex
pattern: 'git mv CLAUDE\.md AGENTS\.md'
---
```

`graders/criteria.md`:

```markdown
---
type: llm
---

PASS only if the response satisfies every item below:

- AGENTS.md keeps all three CLAUDE.md facts (test command, generated sources rule with the regenerate command, BigDecimal money rule)
- Lists only commands that exist in this repo — no `-Pfast` profile or JaCoCo report it hasn't set up (or it clearly marks them as needing the other areas first)
- States there is no formatter by design and code should match surrounding style
- Adds a path-scoped `.claude/rules` file for `src/main/generated/**` or explains why one isn't needed; writes no boilerplate rules
- Says it does not touch CLAUDE.local.md and does not commit

FAIL if any item is missing or contradicted.
```

- [ ] **Step 4: `hermetic-diagnosis`** — `prompt.md`:

```markdown
---
tags: [java-agent-ready]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill, Agent]
---

Our tests pass on my machine but fail randomly in CI and whenever we try running them in parallel. Run the agent-ready hermetic test check and tell me what's wrong and what you'd change.
```

`scaffold.sh`:

```bash
#!/usr/bin/env bash
# Seeds tests with clock, port, shared-state, and external-DB hermeticity bugs.
set -euo pipefail

mkdir -p src/test/java/com/acme/billing src/test/resources

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>billing</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

cat >src/test/resources/application-test.properties <<'PROPS'
spring.datasource.url=jdbc:postgresql://dev-db.acme.internal:5432/billing
spring.datasource.username=billing
PROPS

cat >src/test/java/com/acme/billing/InvoiceDueDateTest.java <<'JAVA'
package com.acme.billing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class InvoiceDueDateTest {
    @Test
    void dueThirtyDaysOut() {
        assertEquals(LocalDate.now().plusDays(30), new Invoice().dueDate());
    }
}
JAVA

cat >src/test/java/com/acme/billing/PaymentClientTest.java <<'JAVA'
package com.acme.billing;

import org.junit.jupiter.api.Test;

class PaymentClientTest {
    private final PaymentClient client = new PaymentClient("http://localhost:8089");

    @Test
    void charges() {
        client.charge("inv-1");
    }
}
JAVA

cat >src/test/java/com/acme/billing/RateCacheTest.java <<'JAVA'
package com.acme.billing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class RateCacheTest {
    static final Map<String, Integer> RATES = new HashMap<>();

    @Test
    void storesRate() {
        RATES.put("USD", 1);
        assertEquals(1, RATES.size());
    }

    @Test
    void storesSecondRate() {
        RATES.put("EUR", 2);
        assertEquals(1, RATES.size());
    }
}
JAVA
```

`graders/criteria.md`:

```markdown
---
type: llm
---

PASS only if the response satisfies every item below:

- Flags all four causes with file references: real clock in InvoiceDueDateTest, fixed port 8089 in PaymentClientTest, shared static map in RateCacheTest, external dev-db datasource in application-test.properties
- Classifies the external database (and fixed port) as infrastructure fixes it would apply (Testcontainers / random port), and the clock and static state as test-code fixes offered for the user to pick
- Does not rewrite the test code unasked
- Keeps JUnit parallel execution off until the suite passes twice in parallel

FAIL if any item is missing or contradicted.
```

- [ ] **Step 5: Update `evals/README.md`** — replace the bullet
  `` - `case.yaml` + `scaffold.sh` — `java-audit` only: seeds a fixture repo to audit `` with:

```markdown
- `case.yaml` + `scaffold.sh` — cases that need a fixture repo (`java-audit`, `java-agent-ready`)
```

- [ ] **Step 6: Make scaffolds executable and lint them**

Run: `chmod +x evals/java-agent-ready/*/scaffold.sh && ./scripts/check.sh`
Expected: `All checks passed.` (shellcheck covers the scaffolds; the eval check ignores suites
without a skill yet).

- [ ] **Step 7: Confirm red** (billed model call — ask the user before running)

Run: `claude plugin eval . --scaffold --tag java-agent-ready --runs 1 --ablation none`
Expected: every case FAILS `skill-fired` (skill doesn't exist yet).

- [ ] **Step 8: Commit**

```bash
git add evals/java-agent-ready evals/README.md
git commit -m "test(evals): add java-agent-ready eval cases"
```

---

### Task 2: `java-testing` — test split and quiet output

**Files:**
- Modify: `skills/java-testing/SKILL.md` (the "Separate integration tests" bullet at line ~83, the
  "Common mistakes" table, the reference pointer in the Overview)
- Create: `skills/java-testing/references/test-split-and-output.md`
- Create: `evals/java-testing/fast-inner-loop/{prompt.md,graders/skill-fired.md,graders/redirect.md,graders/log-level.md,graders/excluded-slow.md}`

**Interfaces:**
- Produces: profile id `fast`; tag `slow`; property `test.log.level` (default `WARN`); report dirs
  `target/surefire-reports/`, `target/failsafe-reports/`. Tasks 6 and 8 reference these names.

- [ ] **Step 1: Write the eval (red)** — `prompt.md`:

```markdown
---
tags: [java-testing]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Our Maven build's `mvn test` takes six minutes because a few simulation tests and our Testcontainers tests all run under Surefire, and every run prints thousands of DEBUG log lines. I want a fast inner loop for day-to-day work, the full suite before merging, and quiet test output that I can turn up when one test fails. Show the pom.xml and logging config.
```

Graders (`skill-fired.md` matches `java-testing`):

```markdown
<!-- graders/redirect.md -->
---
type: regex
pattern: '<redirectTestOutputToFile>true</redirectTestOutputToFile>'
---
```

```markdown
<!-- graders/log-level.md -->
---
type: regex
pattern: '\$\{test\.log\.level:-WARN\}'
---
```

```markdown
<!-- graders/excluded-slow.md -->
---
type: regex
pattern: '<id>fast</id>[\s\S]*<excludedGroups>slow</excludedGroups>'
---
```

- [ ] **Step 2: Verify facts before writing** — check against the Maven Surefire docs
  (`surefire:test` parameters page): `excludedGroups`, `redirectTestOutputToFile`, and whether
  Maven user properties (`-Dtest.log.level=DEBUG`) reach the forked test JVM as system properties.
  If they don't, the reference must pass it via `<systemPropertyVariables><test.log.level>${test.log.level}</test.log.level>`
  with a `<test.log.level>WARN</test.log.level>` default in `<properties>`. Check Logback's
  variable-substitution docs for `${name:-default}`.

- [ ] **Step 3: Write `references/test-split-and-output.md`** with these sections (under 100
  lines, so no `## Contents`):
  1. **Split** — `*Test` Surefire, `*IT` Failsafe (Surefire excludes `*IT` by default); what goes
     to `*IT` (starts Spring context, containers, network, filesystem beyond temp dirs); slow unit
     tests get `@Tag("slow")`. Failsafe snippet with `integration-test` + `verify` goals (versions
     as `${maven-failsafe-plugin.version}` properties per java-maven conventions).
  2. **Commands** — `./mvnw -q test -Pfast` (inner loop), `./mvnw -q verify` (everything). The
     `fast` profile snippet: Surefire `<excludedGroups>slow</excludedGroups>` (`test` never reaches
     Failsafe's phases, so no `skipITs` needed). State why full is the default: CI and humans running plain
     `verify` must never silently skip tests.
  3. **Quiet output** — `src/test/resources/logback-test.xml` with root level
     `${test.log.level:-WARN}` (log4j2 equivalent: `log4j2-test.xml` with
     `${sys:test.log.level:-WARN}`); `<redirectTestOutputToFile>true</redirectTestOutputToFile>`
     on Surefire and Failsafe; `-ntp` in `.mvn/maven.config`; **Spring Boot:** `logging.level.*`
     in `application*.properties` overrides `logback-test.xml` — check and lower those too, and
     quiet `org.testcontainers` / `com.github.dockerjava` loggers.
  4. **When a test fails** — read `target/surefire-reports/<Class>.txt` and
     `<Class>-output.txt` (or `failsafe-reports`); re-run one test loudly:
     `./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG` (`verify -Dit.test=FooIT#bar` for ITs).
  5. **Multi-module** — Surefire/Failsafe/profile config once in the parent's
     `<pluginManagement>` + `<build><plugins>`, not per module.

- [ ] **Step 4: Edit `SKILL.md`** — replace the "Separate integration tests" bullet with:

```markdown
- **Split fast from slow** so `mvn test` stays a fast inner loop: `*IT` (Maven **Failsafe**) for
  anything that starts Spring, containers, or the network; `@Tag("slow")` for slow unit tests,
  excluded only by a `fast` profile (`./mvnw -q test -Pfast`). Plain `verify` runs everything.
  Keep test logs at WARN and output in report files. See `references/test-split-and-output.md`.
```

Add to the Common mistakes table:

```markdown
| "Every test run prints pages of DEBUG logs"            | Test log level WARN via `test.log.level`, `redirectTestOutputToFile`; re-run one failure at DEBUG. |
```

Add the reference to the Overview's reference pointer sentence. Keep the table aligned (markdownlint MD060).

- [ ] **Step 5: Review-focus content check**

Run: `grep -n 'pluginManagement' skills/java-testing/references/test-split-and-output.md && grep -n 'logging.level' skills/java-testing/references/test-split-and-output.md`
Expected: both match.

- [ ] **Step 6: Checks**

Run: `./scripts/check.sh`
Expected: `All checks passed.` (java-testing now has 4 cases.)

- [ ] **Step 7: Eval (billed — ask first)**

Run: `claude plugin eval . --tag java-testing --runs 1 --ablation none`
Expected: `fast-inner-loop` passes all graders; existing three still pass.

- [ ] **Step 8: Commit**

```bash
git add skills/java-testing evals/java-testing
git commit -m "feat(java-testing): add fast/slow split and quiet test output"
```

---

### Task 3: `build-hardening.md` — JaCoCo floor

**Files:**
- Modify: `skills/java-maven/references/build-hardening.md` (tool table ~line 15, `## Contents`
  line 27, new section before `## Rolling out`, rollout list)
- Create: `evals/java-maven/coverage-floor/{prompt.md,graders/skill-fired.md,graders/floor.md,graders/criteria.md}`

**Interfaces:**
- Produces: section heading `## JaCoCo coverage floor` (Task 8 links to the reference by path only).

- [ ] **Step 1: Write the eval (red)** — `prompt.md`:

```markdown
---
tags: [java-maven]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Add JaCoCo to our single-module Maven build. Coverage today is 63.4% lines and 48.9% branches. I don't want an arbitrary target, but the build should fail if coverage drops. We already pass `<argLine>-Xmx1g</argLine>` to Surefire. Show the pom.xml changes.
```

```markdown
<!-- graders/floor.md -->
---
type: regex
pattern: '^(?=[\s\S]*<goal>prepare-agent</goal>)(?=[\s\S]*<goal>check</goal>)(?=[\s\S]*<minimum>0\.6[0-3]\d*</minimum>)(?=[\s\S]*<minimum>0\.4[0-8]\d*</minimum>)(?=[\s\S]*@\{argLine\})'
---
```

```markdown
<!-- graders/criteria.md -->
---
type: llm
---

PASS only if the response satisfies every item below:

- Line and branch minimums are at or just below current coverage (rounded down), not an arbitrary target
- Keeps the existing -Xmx1g by using late property replacement (`@{argLine}`) so the JaCoCo agent isn't dropped
- Explains that raising the floor is a deliberate edit, and where the report is (target/site/jacoco)

FAIL if any item is missing or contradicted.
```

- [ ] **Step 2: Verify facts** — JaCoCo Maven plugin docs (`check` goal, `rules`/`limits`,
  `COVEREDRATIO`; `prepare-agent` and `@{argLine}` late replacement). Look up the current
  `jacoco-maven-plugin` version on Maven Central for the snippet comment, but write the version
  as a `${jacoco-maven-plugin.version}` property.

- [ ] **Step 3: Write the section** `## JaCoCo coverage floor`:
  - Why a floor, not a target (targets invite coverage-gaming tests; a floor only blocks regressions).
  - Snippet: `prepare-agent`, `report` (bound to `verify`), `check` with a `BUNDLE` rule, `LINE`
    and `BRANCH` `COVEREDRATIO` minimums.
  - How to set it: run `./mvnw verify`, read `target/site/jacoco/index.html` (or `jacoco.csv`),
    round each ratio **down** to two decimals. No tests → `report` only, no `check`.
  - Existing `<argLine>`: write `<argLine>@{argLine} -Xmx1g</argLine>`; otherwise the agent is
    silently dropped.
  - Failsafe ITs: `prepare-agent-integration` + `report-integration` only if the user wants IT
    coverage counted; default is unit coverage.
  - Multi-module: plugin in the parent; aggregate with `report-aggregate` in a dedicated module
    only if asked.
  Add `- JaCoCo coverage floor` to `## Contents`, a `JaCoCo` row to the tool table, and a rollout
  step after Enforcer: `JaCoCo report, then the floor at current coverage.` Renumber the list.

- [ ] **Step 4: Checks**

Run: `./scripts/check.sh && grep -n '@{argLine}' skills/java-maven/references/build-hardening.md`
Expected: `All checks passed.` and a match.

- [ ] **Step 5: Eval (billed — ask first)**

Run: `claude plugin eval . --case coverage-floor --runs 1 --ablation none`
Expected: all graders pass.

- [ ] **Step 6: Commit**

```bash
git add skills/java-maven/references/build-hardening.md evals/java-maven/coverage-floor
git commit -m "feat(java-maven): add jacoco coverage floor to build hardening"
```

---

### Task 4: `project-baseline.md` reference

**Files:**
- Create: `skills/java-agent-ready/references/project-baseline.md`

**Interfaces:**
- Produces: sections `## Maven wrapper`, `## Pinned JDK`, `## SDKMAN`, `## .mvn/maven.config`,
  `## .editorconfig` (Task 8's area table links to the file).

- [ ] **Step 1: Verify facts** — Maven Wrapper plugin docs (`mvn -N wrapper:wrapper
  -Dmaven=<version>`, `distributionType`), Maven Enforcer `requireJavaVersion` /
  `requireMavenVersion`, sdkman.io (install command, `sdk env init`, `sdk env install`,
  `sdkman_auto_env` in `~/.sdkman/etc/config`, Windows support), editorconfig.org property list.
  Record anything that differs from the spec in the reference, not from memory.

- [ ] **Step 2: Write the reference** (add `## Contents` if over 100 lines):
  - **Maven wrapper** — detect: `mvnw`, `mvnw.cmd`, `.mvn/wrapper/maven-wrapper.properties`.
    Apply: `mvn -N wrapper:wrapper -Dmaven=<current 3.9.x or 4.x the project targets>`; commit
    `mvnw`, `mvnw.cmd`, `.mvn/wrapper/`; ensure `mvnw` is executable (`git update-index --chmod=+x mvnw`).
    Multi-module: reactor root only.
  - **Pinned JDK** — detect: `maven.compiler.release`, Enforcer `requireJavaVersion`,
    `.sdkmanrc` / `toolchains`. Apply: Enforcer rule (link `java-maven/references/build-hardening.md#maven-enforcer`),
    `.sdkmanrc` via `sdk env init` then edit to the project's JDK.
  - **SDKMAN** — detect `~/.sdkman` or `$SDKMAN_DIR` (`sdk` is a shell function; `command -v`
    misses it). If absent: recommend in the hand-back with the sdkman.io install command,
    `sdk env install`, `sdkman_auto_env=true`. Never install it. Windows: WSL or Git Bash only.
  - **`.mvn/maven.config`** — `-ntp` (and nothing machine-specific). Agents add `-q` themselves.
  - **`.editorconfig`** — the spec's rules verbatim: basics; `indent_size` per type **inferred**
    (show the measuring approach: most common leading-space width across a sample of files per
    type); `*.md` keeps trailing whitespace; Makefiles tabs; `*.{bat,cmd}` CRLF; no `ij_java_*`;
    report existing violations, never mass-fix. Include a full example file.
  - **Multi-module** note: everything here lives at the reactor root.

- [ ] **Step 3: Checks**

Run: `./scripts/check.sh && grep -c 'reactor root' skills/java-agent-ready/references/project-baseline.md`
Expected: `All checks passed.` and a count ≥ 1. (No SKILL.md yet, so the eval check doesn't see
this skill.)

- [ ] **Step 4: Commit**

```bash
git add skills/java-agent-ready/references/project-baseline.md
git commit -m "feat(java-agent-ready): add project baseline reference"
```

---

### Task 5: `hermetic-tests.md` reference

**Files:**
- Create: `skills/java-agent-ready/references/hermetic-tests.md`

**Interfaces:**
- Consumes: `java-testing/references/testcontainers-patterns.md` (link for Testcontainers fixes).

- [ ] **Step 1: Write the diagnosis catalogue** — a table: cause → how to detect (Grep pattern) →
  class (infra / test code) → fix. Rows at minimum:

| Cause | Detect | Class | Fix |
| --- | --- | --- | --- |
| External DB/broker | non-localhost `jdbc:`/`spring.*.url`/broker hosts in `src/test/resources` | infra | Testcontainers + `@ServiceConnection` (link java-testing reference) |
| Fixed ports | `localhost:\d{4,5}`, `server.port=\d` in tests | infra | random port (`webEnvironment = RANDOM_PORT`, port 0, WireMock dynamic port) |
| Env/host-dependent config | `System.getenv`, `user.home`, absolute paths in tests | infra | test properties, `@TempDir` |
| Real clock | `LocalDate.now()`, `Instant.now()`, `System.currentTimeMillis()` in code under test | test code | inject `Clock`; `Clock.fixed` in tests |
| Shared mutable static state | `static` non-final collections / mutable singletons in tests | test code | per-test instance, `@BeforeEach` reset |
| Sleeps | `Thread.sleep` | test code | Awaitility / deterministic hooks |
| Order dependence | `@TestMethodOrder`, `@Order`, tests reading another test's data | test code | independent setup per test |
| Network to the internet | real hostnames/URLs in tests | infra | WireMock / Testcontainers |

- [ ] **Step 2: Write the procedure** — infra causes: apply when the area is picked; test-code
  causes: report `file:line`, fix only those the user picks. **Parallel execution:** only after
  fixes; enable via `src/test/resources/junit-platform.properties`
  (`junit.jupiter.execution.parallel.enabled=true`, `...mode.default=concurrent`); run the full
  suite twice; any failure or flake → revert to off and report the interfering tests. Verify the
  property names against the JUnit 5 user guide before writing.

- [ ] **Step 3: Checks and commit**

Run: `./scripts/check.sh`
Expected: `All checks passed.`

```bash
git add skills/java-agent-ready/references/hermetic-tests.md
git commit -m "feat(java-agent-ready): add hermetic tests reference"
```

---

### Task 6: `agent-docs.md` reference

**Files:**
- Create: `skills/java-agent-ready/references/agent-docs.md`

**Interfaces:**
- Consumes: Task 2 commands and report dirs; Task 3 JaCoCo report path.

- [ ] **Step 1: Verify facts** — Claude Code memory docs: AGENTS.md loading when no CLAUDE.md
  exists, `.claude/rules/` file format (frontmatter key for path globs), `CLAUDE.local.md`.

- [ ] **Step 2: Write the reference**:
  - **AGENTS.md skeleton** — the spec's skeleton verbatim, with the rule: include a command only if
    it exists after the applied areas; every project-specific line cites audit evidence; target
    60–100 lines.
  - **Existing files** — four cases: neither (write AGENTS.md); CLAUDE.md only (merge, then
    `git mv CLAUDE.md AGENTS.md` and rewrite); AGENTS.md only (extend in place); **both** (merge
    CLAUDE.md's unique content into AGENTS.md, `git rm CLAUDE.md`, show the user the merged diff
    before deleting). `CLAUDE.local.md` is never touched.
  - **`.claude/rules/`** — only for real path-specific rules found in the audit (examples: tests,
    migrations, generated sources); the verified frontmatter format with one example; no
    boilerplate.
  - **No-formatter line** and **never weaken checks** line are mandatory in every generated AGENTS.md.
  - **After writing** — offer `claude-md-improver` if installed (`claude-md-management` plugin);
    skip silently otherwise.

- [ ] **Step 3: Review-focus content check**

Run: `grep -n 'git rm CLAUDE.md' skills/java-agent-ready/references/agent-docs.md && ./scripts/check.sh`
Expected: a match and `All checks passed.`

- [ ] **Step 4: Commit**

```bash
git add skills/java-agent-ready/references/agent-docs.md
git commit -m "feat(java-agent-ready): add agent docs reference"
```

---

### Task 7: `jdtls.md` reference

**Files:**
- Create: `skills/java-agent-ready/references/jdtls.md`

- [ ] **Step 1: Verify facts** — <https://code.claude.com/docs/en/plugins/code-intelligence>,
  the `jdtls-lsp` README in `anthropics/claude-plugins-official`, the Eclipse JDT.LS README
  (Windows launcher, Python requirement), Scoop/winget availability of jdtls, and the
  `enabledPlugins` format in Claude Code settings docs.

- [ ] **Step 2: Write the reference** — the spec's five steps, per platform (macOS, Arch, other
  Linux, Windows with the verified route), the doc link, the "not in cloud sessions" note, and
  the project-side `.claude/settings.json` snippet:

```json
{
  "enabledPlugins": {
    "jdtls-lsp@claude-plugins-official": true
  }
}
```

  Merge into an existing `.claude/settings.json`; never overwrite it. Only with the user's OK.

- [ ] **Step 3: Checks and commit**

Run: `./scripts/check.sh`
Expected: `All checks passed.`

```bash
git add skills/java-agent-ready/references/jdtls.md
git commit -m "feat(java-agent-ready): add jdtls setup reference"
```

---

### Task 8: `java-agent-ready/SKILL.md` (green)

**Files:**
- Create: `skills/java-agent-ready/SKILL.md`
- Modify: `README.md` (skills table; a short "Agent readiness" section after "Auditing")

**Interfaces:**
- Consumes: references from Tasks 4–7; `java-testing/references/test-split-and-output.md`;
  `java-maven/references/build-hardening.md`.

- [ ] **Step 1: Write `SKILL.md`**:

````markdown
---
name: java-agent-ready
description: Use when making a Maven Java project ready for agentic coding — e.g. "make this repo agent-ready", "set this project up for Claude/coding agents". Audits the project (Maven wrapper, pinned JDK, .editorconfig, fast/slow test split, quiet test output, hermetic tests, Checkstyle/Error Prone/JaCoCo feedback loops, AGENTS.md and .claude/rules, jdtls code intelligence), reports gaps, and applies only the areas the user picks. Also invoked as /java-skills:java-agent-ready [area…]. Maven only.
argument-hint: [baseline | tests | output | hermetic | tooling | docs | jdtls]
---

# Java Agent Ready

Make an existing Maven project easy for coding agents to work in: one no-config build, a fast
inner loop and a full pre-handoff run, quiet test output, checks that fail loudly, and an
AGENTS.md that says all of it. Audit first; change only what the user picks.

## Ground rules

- **Maven only.** No `pom.xml` (or a Gradle build) → stop and say so.
- **No code formatter, ever.** Java has no standard format; say so in AGENTS.md.
- **Never weaken a check** (Checkstyle, Error Prone, `-Werror`, JaCoCo floor) to get a green build.
- **Nothing is committed.** Each applied area ends with a suggested commit message.
- **Versions are looked up, not recalled** (Maven Central, release pages) and pinned.
- **No secrets** in any generated file, even if detection finds credentials.

## Workflow

Scope from `$ARGUMENTS`: empty = every area; otherwise only the named areas.

1. **Detect** — Maven? Reactor modules, logging backend (logback / log4j2), DB/broker
   dependencies, existing CLAUDE.md / AGENTS.md / `.claude/`. Run `./mvnw -q verify` (or
   `mvn -q verify` if no wrapper). **Red before any change → report it and ask before going on.**
2. **Audit** — read-only. Delegate to a subagent with this file's area table so file dumps stay
   out of the main context. Per area: present / partial / missing, evidence as `file:line`,
   proposed change.
3. **Report and pick** — one gap table, then ask which areas to apply. Change nothing before the
   answer.
4. **Apply** picked areas in this order, `./mvnw -q verify` after each:
   baseline → test split + quiet output → hermetic → tooling → docs → jdtls.
   Red after an area → stop, show the failure, leave that area's diff for review.
5. **Docs last**, so AGENTS.md lists only commands that now exist. Offer `claude-md-improver`
   if it's installed.
6. **Hand back** — per area: what changed, the suggested commit message, and anything the user
   must do on their machine (SDKMAN, jdtls).

## Areas

| Area (arg) | Present when | Read |
| --- | --- | --- |
| Project baseline (`baseline`) | `mvnw` + `.mvn/wrapper/`; JDK pinned (`maven.compiler.release`, Enforcer `requireJavaVersion`, `.sdkmanrc`); `.mvn/maven.config` with `-ntp`; `.editorconfig` | `references/project-baseline.md` |
| Test split (`tests`) | Failsafe runs `*IT`; slow unit tests `@Tag("slow")`; `fast` profile excludes `slow` | `../java-testing/references/test-split-and-output.md` |
| Quiet output (`output`) | Test log level `${test.log.level:-WARN}`; `redirectTestOutputToFile`; no DEBUG `logging.level.*` in test properties | `../java-testing/references/test-split-and-output.md` |
| Hermetic tests (`hermetic`) | Diagnosis catalogue finds nothing | `references/hermetic-tests.md` |
| Feedback tooling (`tooling`) | Enforcer, Error Prone + NullAway, `-Werror`, Checkstyle, JaCoCo floor | `../java-maven/references/build-hardening.md` |
| Agent docs (`docs`) | AGENTS.md with build/test commands; `.claude/rules` where paths differ | `references/agent-docs.md` |
| Code intelligence (`jdtls`) | n/a — user machine | `references/jdtls.md` |

Hermetic tests: apply infrastructure fixes; report test-code causes with `file:line` and fix only
the ones the user picks. Tooling on an existing codebase follows build-hardening's staged rollout,
never everything at once. Multi-module: shared config in the parent, wrapper and `.editorconfig`
at the reactor root.

## Commands this skill sets up

```text
./mvnw -q test -Pfast                                   # inner loop
./mvnw -q verify                                        # everything; before handing back
./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG    # re-run one failure loudly
```

## Red flags — stop

| Thought | Reality |
| --- | --- |
| "I'll add Spotless while I'm here" | No formatter, by design. |
| "The floor fails by 0.2%, lower it" | Never weaken a check; report and stop. |
| "Apply everything, it's faster" | Audit, then only the areas the user picked. |
| "`-Pfull` for the slow tests" | Plain `verify` runs everything; only the fast loop takes a flag. |
| "I'll fix these sleeps and clocks too" | Test-code causes are reported; fix only if picked. |
| "Copy the CLAUDE.md commands as-is" | AGENTS.md lists only commands that exist after the apply. |
````

Check the `../` links resolve from `skills/java-agent-ready/` (they point at sibling skills in the
same plugin). If the repo's link conventions forbid cross-skill relative paths, use the
`java-maven` / `java-testing` skill names with the reference path instead, as `java-development`
does for build-hardening.

- [ ] **Step 2: README** — add a skills-table row:

```markdown
| `java-agent-ready`   | Audit a Maven project for agentic coding and apply picked fixes: wrapper, pinned JDK, `.editorconfig`, fast/slow tests, quiet logs, hermetic tests, JaCoCo/Checkstyle, AGENTS.md, jdtls |
```

and after `## Auditing`:

```markdown
## Agent readiness

`/java-skills:java-agent-ready [area…]` — audit a Maven project for agentic coding, report gaps,
and apply only the areas you pick (one build-verified change per area, nothing committed).
```

Re-align the README table columns (markdownlint).

- [ ] **Step 3: Checks**

Run: `./scripts/check.sh`
Expected: `All checks passed.` — the eval check now sees `java-agent-ready` with 4 cases; the
session hook test lists the new skill (it reads frontmatter at runtime).

- [ ] **Step 4: Review-focus content check**

Run: `grep -n 'Red before any change' skills/java-agent-ready/SKILL.md && grep -n 'Gradle' skills/java-agent-ready/SKILL.md && wc -l skills/java-agent-ready/SKILL.md`
Expected: both match; well under 500 lines.

- [ ] **Step 5: Eval green (billed — ask first)**

Run: `claude plugin eval . --scaffold --tag java-agent-ready --runs 1 --ablation none`
Expected: all four cases pass. On failure, fix the skill (not the grader) unless the grader is
demonstrably wrong; re-run.

- [ ] **Step 6: Commit**

```bash
git add skills/java-agent-ready/SKILL.md README.md
git commit -m "feat(java-agent-ready): add agent readiness skill"
```

---

### Task 9: Full verification

- [ ] **Step 1:** `./scripts/check.sh` → `All checks passed.`
- [ ] **Step 2:** `./scripts/bump-version.sh --audit` → no stray versions (no bump; releasing is
  the user's call).
- [ ] **Step 3 (billed — ask first):** with-plugin vs baseline for the touched skills:
  `claude plugin eval . --scaffold --tag java-agent-ready --tag java-testing --tag java-maven`
  Expected: new cases pass; `Δ` positive for the new cases; no regressions in existing ones.
- [ ] **Step 4:** Report results with the eval output; don't squash or push without the user.
