# Hermetic tests

**Docs:** [JUnit parallel execution](https://docs.junit.org/current/writing-tests/parallel-execution.html)
· [Testcontainers](https://java.testcontainers.org/)

A hermetic suite passes on any machine, in any order, in parallel, with no setup beyond `./mvnw`.
That is what lets an agent trust a red build: red means its change broke something.

## Contents

- Diagnosis catalogue
- What gets fixed, what gets reported
- Parallel execution

## Diagnosis catalogue

Search the test sources and test resources for each cause. Report every hit as `file:line`.

| Cause | Detect | Class | Fix |
| --- | --- | --- | --- |
| External DB/broker | non-localhost `jdbc:`, `spring.*.url`, broker/cache hosts in `src/test/resources` | infra | Testcontainers + `@ServiceConnection` (the `java-testing` skill's `references/testcontainers-patterns.md`) |
| Fixed ports | `localhost:<port>`, `server.port=<n>`, hardcoded WireMock/mock-server ports | infra | random port: `webEnvironment = RANDOM_PORT`, port `0`, WireMock `dynamicPort()` |
| Env/host-dependent config | `System.getenv`, `user.home`, absolute paths, hostnames in tests | infra | test properties; `@TempDir` for files |
| Internet access | real external URLs/hostnames called from tests | infra | WireMock or a Testcontainers service |
| Real clock | `LocalDate.now()`, `Instant.now()`, `System.currentTimeMillis()` in code under test or assertions | test code | inject a `Clock`; `Clock.fixed(...)` in tests |
| Shared mutable static state | mutable `static` state (final or not): collections, caches, singletons touched by tests | test code | per-test instances; reset in `@BeforeEach` |
| Sleeps | `Thread.sleep` | test code | Awaitility, or a deterministic hook |
| Order dependence | `@TestMethodOrder`, `@Order`, tests reading data another test wrote | test code | each test sets up its own data |

A credential or internal hostname found here goes in the report as `file:line` only — never copy
its value into AGENTS.md or any other generated file.

## What gets fixed, what gets reported

- **Infra causes** are fixed when the user picks the hermetic area: they change config and test
  wiring, not test logic.
- **Test-code causes** are reported with `file:line` and a one-line proposed fix. Change only the
  ones the user picks; each fix keeps the test's assertion intent. A real clock in production code
  needs a constructor-injected `Clock`, which touches main code — say so in the proposal.
- After any fix, run the affected tests and then `./mvnw -q verify`.

## Parallel execution

Turn it on only after the fixes, and only if the suite proves it can take it.

1. Add the `parallel.*` keys to `src/test/resources/junit-platform.properties` (per module with
   tests), creating the file only if it doesn't exist:

   ```properties
   junit.jupiter.execution.parallel.enabled=true
   junit.jupiter.execution.parallel.mode.default=concurrent
   junit.jupiter.execution.parallel.mode.classes.default=concurrent
   ```

2. Run the full suite **twice**: `./mvnw -q verify`, then again.
3. Any failure, or a test that passes once and fails once → remove the `parallel.*` keys again
   (parallel stays off; any other keys stay) and report the tests that interfered. Where a shared resource is legitimate, propose
   `@ResourceLock("<resource>")` or `@Isolated` on those classes instead of turning parallel off
   for everyone — as a proposal, not an applied change.
