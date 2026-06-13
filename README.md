# java-skills

A [Claude Code](https://claude.com/claude-code) plugin providing a skills library for Java
development. The repo doubles as its own plugin marketplace.

## Install

```
/plugin marketplace add mtkhawaja/java-skills
/plugin install java-skills@java-skills
```

## Skills

| Skill                | Use for                                                                                                                                                                |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `java-development`   | Everyday Java craft — immutability, DI, exceptions, resources, validation, date/time, comments — gated to the project's JDK version (per-LTS feature references, 8–25) |
| `java-testing`       | JUnit Jupiter + AssertJ + Mockito conventions, and Testcontainers integration testing with `@ServiceConnection`                                                        |
| `java-concurrency`   | Executors and virtual threads, bounded fan-out, executor lifecycle, shared-state visibility                                                                            |
| `java-observability` | SLF4J structured logging, MDC correlation, Micrometer metrics, OpenTelemetry tracing                                                                                   |
| `java-maven`         | `pom.xml` conventions, multi-module reactors, Maven 3 → 4 migration                                                                                                    |
| `java-gitignore`     | Initialize or audit a Java `.gitignore`; un-track mistakenly committed files; secrets-in-history caveats                                                               |

A `SessionStart` hook detects Maven/Gradle projects and surfaces this skill list automatically.

## Agents

| Agent                 | Use for                                                                                                  |
|-----------------------|----------------------------------------------------------------------------------------------------------|
| `java-reviewer`       | Read-only review of a diff, class, or package against every skill's conventions and red-flag lists      |
| `java-upgrade-advisor`| Ordered migration plans — Java version / Spring Boot / JUnit 4 → 5 (OpenRewrite), Maven 3 → 4 (`mvnup`) |

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # marketplace listing (source: ./)
skills/              # skills, one subdirectory each with a SKILL.md
agents/              # subagents: java-reviewer, java-upgrade-advisor
hooks/               # SessionStart hook: surface skills in Java projects
evals/               # per-skill evaluation scenarios (see evals/README.md)
.github/workflows/   # ci: shellcheck, hook regression tests, manifest checks
```

## License

MIT
