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
   No shell to run it? Say so, and that a red build would stop the run before any change.
2. **Audit** — read-only. Delegate to a subagent with this file's area table so file dumps stay
   out of the main context. Per area: status — exactly present / partial / missing (JDTLS:
   user machine) — evidence as `file:line`, proposed change.
3. **Report and pick** — one gap table, then ask which areas to apply:

   ```text
   | Area | Status (present / partial / missing) | Evidence (file:line) | Proposed change (where) |
   ```

   One row per area in the table below, JDTLS included.

   Change nothing before the answer. In a reactor, say where each change lands: wrapper,
   `.mvn/` and `.editorconfig` at the root; shared plugin config in the parent POM; per-module
   files only where they must be.
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
| Code intelligence (`jdtls`) | n/a — user machine (jdtls plugin; `/ide` for IntelliJ users) | `references/jdtls.md` |

Hermetic tests: apply infrastructure fixes; report test-code causes with `file:line` and fix only
the ones the user picks. JUnit parallel execution goes on only after the fixes and stays only if
the full suite passes twice; otherwise turn it back off and report the interfering tests
(`@ResourceLock` / `@Isolated` are proposals, not a substitute). Tooling on an existing codebase follows build-hardening's staged rollout,
never everything at once. Multi-module: shared config in the parent, wrapper and `.editorconfig`
at the reactor root.

## Commands this skill sets up

```text
./mvnw -q test -Pfast                                   # inner loop
./mvnw -q verify                                        # everything; before handing back
./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG    # re-run one failure loudly (reactor: -pl <module>)
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
