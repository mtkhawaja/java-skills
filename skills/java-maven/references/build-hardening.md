# Hardening a Maven build

**Docs:** [Error Prone installation](https://errorprone.info/docs/installation)
· [Error Prone flags](https://errorprone.info/docs/flags)
· [maven-checkstyle-plugin](https://maven.apache.org/plugins/maven-checkstyle-plugin/)
· [Checkstyle checks](https://checkstyle.org/checks.html)
· [Enforcer built-in rules](https://maven.apache.org/enforcer/enforcer-rules/)
· [JSpecify](https://jspecify.dev/docs/user-guide/)
· [NullAway configuration](https://github.com/uber/NullAway/wiki/Configuration)
· [JaCoCo Maven plugin](https://www.jacoco.org/jacoco/trunk/doc/maven.html)

Make the build fail on bug patterns and on house-convention violations, so reviews stop catching
them by hand. Each layer covers what the others can't:

| Layer                      | Catches                                                                 |
|----------------------------|-------------------------------------------------------------------------|
| Error Prone                | Bug patterns at compile time (plus `FieldCanBeFinal` for fields)        |
| NullAway + JSpecify        | Null dereferences in `@NullMarked` code, at compile time                |
| Checkstyle                 | House rules: `final` locals/parameters, `Optional` placement, ternaries |
| `javac -Xlint:all -Werror` | Compiler warnings (and Error Prone warnings) fail the build             |
| JaCoCo                     | Coverage regressions below a floor set at today's coverage              |
| Maven Enforcer             | Build JDK/Maven versions, unpinned plugins, dependency convergence      |

Put all versions in `<properties>`/`<pluginManagement>` per the SKILL.md conventions, always as
concrete numbers — never placeholders like `2.x`. Check them against current releases
(`./mvnw versions:display-plugin-updates`, Maven Central); if you can't, say which versions are
unverified.

## Contents

- Error Prone
- Null safety: JSpecify + NullAway
- Checkstyle house rules
- Maven Enforcer
- JaCoCo coverage floor
- Rolling out on an existing codebase

## Error Prone

Error Prone **must run on JDK 21+**; it still compiles to an older `maven.compiler.release`. It
runs as a javac plugin, so its flags go on the same `<arg>` as `-Xplugin:ErrorProne`:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <compilerArgs>
      <arg>-Xlint:all,-processing</arg> <!-- "no processor claimed" would fail -Werror -->
      <arg>-Werror</arg>
      <arg>-XDcompilePolicy=simple</arg>
      <arg>--should-stop=ifError=FLOW</arg>
      <arg>-XDaddTypeAnnotationsToSymbol=true</arg>
      <arg>-Xplugin:ErrorProne -XepDisableWarningsInGeneratedCode -Xep:FieldCanBeFinal:ERROR</arg>
    </compilerArgs>
    <annotationProcessorPaths>
      <path>
        <groupId>com.google.errorprone</groupId>
        <artifactId>error_prone_core</artifactId>
        <version>${error-prone.version}</version>
      </path>
      <!-- every other processor (Lombok, MapStruct, ...) must be listed here too:
           annotationProcessorPaths replaces classpath discovery -->
    </annotationProcessorPaths>
  </configuration>
</plugin>
```

And `.mvn/jvm.config` (javac internals Error Prone needs; if the compiler forks, pass each as a
`-J--add-exports=...` `<arg>` instead):

```text
--add-exports jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED
--add-exports jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED
--add-opens jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED
--add-opens jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED
```

- `-Werror` promotes **Error Prone warnings** as well as `-Xlint` ones — every enabled check gates
  the build.
- `FieldCanBeFinal` is off by default; enabling it at `ERROR` is how "fields are `final`" is enforced
  (Checkstyle has no equivalent). It only sees `private` fields — keep non-private ones for review.
- Silence a single false positive with `@SuppressWarnings("CheckName")` and a comment saying why;
  turn a check off project-wide with `-Xep:CheckName:OFF` only with the same justification.

## Null safety: JSpecify + NullAway

Opt packages in with JSpecify's `@NullMarked` in `package-info.java`: inside, every type is
non-null unless annotated `@Nullable`, and NullAway (an Error Prone plugin) fails the build on any
possible null dereference. `OnlyNullMarked=true` makes the annotation the switch — so a package
**without** a marked `package-info.java` is silently unchecked; the Checkstyle rules below close
that gap.

```java
@NullMarked
package com.acme.billing;

import org.jspecify.annotations.NullMarked;
```

Add the annotations as a regular dependency, NullAway next to `error_prone_core`, and its flags on
the `-Xplugin:ErrorProne` arg:

```xml
<dependency>
  <groupId>org.jspecify</groupId>
  <artifactId>jspecify</artifactId>
  <version>${jspecify.version}</version>
</dependency>

<!-- maven-compiler-plugin → annotationProcessorPaths -->
<path>
  <groupId>com.uber.nullaway</groupId>
  <artifactId>nullaway</artifactId>
  <version>${nullaway.version}</version>
</path>

<!-- maven-compiler-plugin → compilerArgs, appended to the Error Prone arg -->
<arg>-Xplugin:ErrorProne ... -Xep:NullAway:ERROR -XepOpt:NullAway:OnlyNullMarked=true</arg>
```

- For NullAway, tests in a main package inherit its `@NullMarked`; a test-only package needs its own
  `package-info.java`. Checkstyle (below) is stricter.
- Nullable values are `@Nullable` from `org.jspecify.annotations` only — not `javax.annotation`,
  JetBrains, or Spring variants. At a boundary with unannotated code, check and convert
  (`Objects.requireNonNull`, or an explicit `null` branch) rather than suppressing.
- `-XepOpt:NullAway:JSpecifyMode=true` turns on fuller JSpecify checking (e.g. generics). It
  depends on `javac` fixes, so NullAway recommends building with the newest JDK available.

## Checkstyle house rules

Copy [checkstyle.xml](checkstyle.xml) to `config/checkstyle/checkstyle.xml`. It encodes only what
Error Prone doesn't:

- **`final` by default** — `FinalLocalVariable` (locals that are never reassigned, enhanced-for
  variables) and `FinalParameters` (method, constructor, and catch parameters).
- **`Optional` is a return type only** — rejects `Optional` fields, parameters, and record
  components; an `Optional` local holding a call's result stays legal.
- **Single-line ternaries only** — a ternary that wraps at `?`/`:` is rejected; use `if`/`else` or
  extract a method. A wrap with `?`/`:` at line end reports as `OperatorWrap` ("should be on a new
  line"); moving it there then trips `NoWrappedTernary` — the fix is to unwrap, not to move the
  operator. A wrap inside an operand (e.g. a wrapped argument list) is not caught, and a text-block
  line starting with a lone `?` or `:` is a false positive.
- **Every package is `@NullMarked`** — `JavadocPackage` requires a `package-info.java` in each
  source directory (it checks per directory, so `src/test/java/...` needs its own even when main
  has one for the same package), and `NullMarkedPackage` requires it to carry `@NullMarked`.

Not mechanically enforced — keep for review: `final` classes (Checkstyle's `FinalClass` only covers
private-constructor classes) and `Optional` as a collection element or type argument.

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-checkstyle-plugin</artifactId>
  <configuration>
    <configLocation>config/checkstyle/checkstyle.xml</configLocation>
    <consoleOutput>true</consoleOutput>
    <violationSeverity>error</violationSeverity>
    <includeTestSourceDirectory>true</includeTestSourceDirectory>
  </configuration>
  <dependencies>
    <dependency> <!-- the plugin bundles an older Checkstyle; pin the engine explicitly -->
      <groupId>com.puppycrawl.tools</groupId>
      <artifactId>checkstyle</artifactId>
      <version>${checkstyle.version}</version>
    </dependency>
  </dependencies>
  <executions>
    <execution>
      <id>checkstyle</id>
      <phase>validate</phase>
      <goals><goal>check</goal></goals>
    </execution>
  </executions>
</plugin>
```

## Maven Enforcer

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-enforcer-plugin</artifactId>
  <executions>
    <execution>
      <id>enforce</id>
      <goals><goal>enforce</goal></goals>
      <configuration>
        <rules>
          <requireJavaVersion><version>[21,)</version></requireJavaVersion> <!-- Error Prone -->
          <requireMavenVersion><version>[3.9,)</version></requireMavenVersion>
          <requirePluginVersions/>
          <dependencyConvergence/>
          <banDuplicatePomDependencyVersions/>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

`requirePluginVersions` also fails on **default lifecycle plugins** (clean, resources, surefire,
jar, install, deploy, site) left at Maven's built-in versions — pin them in `<pluginManagement>`.

## JaCoCo coverage floor

Gate on a **floor at today's coverage**, not a target. A target (say 80%) fails most existing
codebases on day one and invites tests written to move the number; a floor only blocks
regressions. Raising it is a deliberate edit to the POM.

```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>${jacoco-maven-plugin.version}</version>
  <executions>
    <execution>
      <id>prepare-agent</id>
      <goals><goal>prepare-agent</goal></goals>
    </execution>
    <execution>
      <id>report</id>
      <phase>verify</phase>
      <goals><goal>report</goal></goals>
    </execution>
    <execution>
      <id>check</id>
      <phase>verify</phase>
      <goals><goal>check</goal></goals>
      <configuration>
        <rules>
          <rule>
            <element>BUNDLE</element>
            <limits>
              <limit>
                <counter>LINE</counter>
                <value>COVEREDRATIO</value>
                <minimum>${jacoco.line.floor}</minimum>
              </limit>
              <limit>
                <counter>BRANCH</counter>
                <value>COVEREDRATIO</value>
                <minimum>${jacoco.branch.floor}</minimum>
              </limit>
            </limits>
          </rule>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

- **Setting the floor:** add the plugin without `check`, run `./mvnw verify`, read
  `target/site/jacoco/index.html` (or `jacoco.csv`), and round each ratio **down** to two
  decimals (63.4% → `0.63`) into `<jacoco.line.floor>` and `<jacoco.branch.floor>` properties.
  No tests yet → keep `report`, skip `check`.
- **Existing `<argLine>`:** `prepare-agent` passes the agent through the `argLine` property. A
  literal `<argLine>-Xmx1g</argLine>` in Surefire/Failsafe replaces it and silently drops
  coverage. Use late replacement: `<argLine>@{argLine} -Xmx1g</argLine>`.
- **Integration tests:** Failsafe inherits `argLine`, so `*IT` runs also write to
  `target/jacoco.exec` and the floor (checked at `verify`) includes them. Use
  `prepare-agent-integration` / `report-integration` only for a separate IT report.
- **Multi-module:** configure the plugin once in the parent; each module sets its own
  `jacoco.line.floor` / `jacoco.branch.floor` from its own report. A combined report needs
  `report-aggregate` in a dedicated module — only when asked.

## Rolling out on an existing codebase

Turning everything on at once buries the team. Stage it, one PR per step, `./mvnw verify` green
after each:

1. Enforcer, and pin the plugins it reports.
2. JaCoCo report, then the floor at current coverage.
3. Error Prone without `-Werror`; fix the reported errors, then the warnings.
4. `-Xlint:all,-processing -Werror` once the warning count is zero.
5. NullAway: add `@NullMarked` `package-info.java` one package at a time (leaf packages first),
   fixing what NullAway reports.
6. Checkstyle (its `package-info` rules need every package marked): fix `final` mechanically first
   with OpenRewrite (`rewrite-static-analysis`: `org.openrewrite.staticanalysis.FinalizeLocalVariables`,
   `...FinalizeMethodArguments`), then turn on `check`.
