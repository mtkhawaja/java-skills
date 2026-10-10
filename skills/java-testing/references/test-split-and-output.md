# Test split and quiet output

**Docs:** [Surefire `test`](https://maven.apache.org/surefire/maven-surefire-plugin/test-mojo.html)
· [Failsafe](https://maven.apache.org/surefire/maven-failsafe-plugin/)
· [JUnit 5 tags](https://junit.org/junit5/docs/current/user-guide/#writing-tests-tagging-and-filtering)
· [Logback variable substitution](https://logback.qos.ch/manual/configuration.html#variableSubstitution)

Goal: a fast inner loop for day-to-day work, the full suite before handing back, and test output
small enough to read.

## Contents

- Split
- Commands
- Quiet output
- When a test fails
- Multi-module

## Split

- `*Test` runs under **Surefire** (`test` phase). Surefire's default includes skip `*IT`.
- `*IT` runs under **Failsafe** (`integration-test` + `verify`). Anything that starts a Spring
  context, a container, or touches the network or the real filesystem (beyond `@TempDir`) is an
  `*IT`.
- A unit test that is merely slow (simulations, large data sets) stays a `*Test` and gets
  `@Tag("slow")` on the class or method.

```xml
<plugin>
  <artifactId>maven-failsafe-plugin</artifactId>
  <version>${maven-failsafe-plugin.version}</version>
  <executions>
    <execution>
      <goals>
        <goal>integration-test</goal>
        <goal>verify</goal>
      </goals>
    </execution>
  </executions>
</plugin>
```

## Commands

```text
./mvnw -q test -Pfast     # inner loop: *Test minus @Tag("slow")
./mvnw -q verify          # everything: all *Test, then *IT
```

The `fast` profile only narrows Surefire; `test` never reaches Failsafe's phases:

```xml
<profile>
  <id>fast</id>
  <build>
    <plugins>
      <plugin>
        <artifactId>maven-surefire-plugin</artifactId>
        <configuration>
          <excludedGroups>slow</excludedGroups>
        </configuration>
      </plugin>
    </plugins>
  </build>
</profile>
```

**Full is the default on purpose.** CI and people run plain `verify`; it must never silently skip
tests. Only the inner loop takes a flag.

## Quiet output

- **Log level from a property, WARN by default.** `src/test/resources/logback-test.xml`:

  ```xml
  <configuration>
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
      <encoder><pattern>%d{HH:mm:ss.SSS} %-5level %logger{36} - %msg%n</pattern></encoder>
    </appender>
    <root level="${test.log.level:-WARN}">
      <appender-ref ref="CONSOLE"/>
    </root>
  </configuration>
  ```

  Log4j2: `log4j2-test.xml` with `<Root level="${sys:test.log.level:-WARN}">`.
- **Spring Boot:** `logging.level.*` in `application*.properties` / `.yml` (including test
  profiles) overrides `logback-test.xml` — lower or remove those too. Quiet `org.testcontainers`
  and `com.github.dockerjava` explicitly; they are chatty at INFO.
- **Test stdout to files:** `<redirectTestOutputToFile>true</redirectTestOutputToFile>` on both
  Surefire and Failsafe; output lands in `target/surefire-reports/<Class>-output.txt` (or
  `failsafe-reports`). Failure summaries still print.
- **No download progress:** `-ntp` in `.mvn/maven.config`. Agents add `-q` on the command line.

## When a test fails

1. Read `target/surefire-reports/<Class>.txt` (assertion + stack) and `<Class>-output.txt` (its
   output); `target/failsafe-reports/` for `*IT`.
2. Re-run just that test, loudly:

   ```text
   ./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG
   ./mvnw -q verify -Dit.test=FooIT#bar -Dtest=skip -Dsurefire.failIfNoSpecifiedTests=false \
     -Dtest.log.level=DEBUG
   ```

   Multi-module: add `-pl <module>` (or `-Dsurefire.failIfNoSpecifiedTests=false`), otherwise
   every module without a matching test fails the run.

Surefire and Failsafe 3.x pass `-D` user properties to the tests as system properties. On older
versions, wire it explicitly: a `<test.log.level>WARN</test.log.level>` property plus
`<systemPropertyVariables><test.log.level>${test.log.level}</test.log.level></systemPropertyVariables>`.

## Multi-module

Configure Surefire, Failsafe, and the `fast` profile once in the parent POM
(`<pluginManagement>` for versions and configuration, `<build><plugins>` to activate Failsafe),
not per module. Each module with tests keeps its own `logback-test.xml`, or share one from a
test-support module.
