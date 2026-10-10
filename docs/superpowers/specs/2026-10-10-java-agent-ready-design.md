# java-agent-ready — design

Make an existing Maven project ready for agentic coding: audit what it lacks, let the user pick,
then apply targeted improvements one area at a time.

## Intent

The user repeats the same setup on every new Java project. Success: after a run, an agent can
work in the project with a no-config build (`./mvnw`, pinned JDK), a fast inner-loop command and
a full pre-handoff command, quiet test output, checks that fail loudly, and an AGENTS.md that says
all of this.

## Decisions

- **Maven only.** Gradle or no build file → stop and say so.
- **No code formatter**, deliberately (Java has no standard format; IDE conflicts aren't worth it).
  Generated AGENTS.md says so, so agents don't add one. Checkstyle keeps its wrapping rules.
- **Audit → pick → apply.** Read-only audit first; user chooses areas; apply one area at a time
  with a build after each.
- **Hermetic tests:** fix infrastructure causes; report test-code causes and fix only if picked.
- **Test split:** `*IT` → Failsafe; slow unit tests `@Tag("slow")`. Plain `./mvnw verify` runs
  everything; the fast loop is opt-in `./mvnw -q test -Pfast` (excludes `slow`).
- **JaCoCo:** `jacoco:check` minimums (line, branch) set to current coverage rounded down.
- **Existing CLAUDE.md:** merge into AGENTS.md, `git mv` the file (Claude Code reads AGENTS.md
  only when no CLAUDE.md exists). `CLAUDE.local.md` is untouched.
- **Out of scope:** read-only database skill (usql) — a separate, later skill.

## Structure (approach A + C)

New skill with per-area references; general rules go to the skills they belong in.

```text
skills/java-agent-ready/
  SKILL.md                     # workflow + area table
  references/
    project-baseline.md        # mvnw, pinned JDK, .mvn/maven.config, .editorconfig
    hermetic-tests.md          # diagnosis catalogue + infra fixes
    agent-docs.md              # AGENTS.md skeleton, .claude/rules, CLAUDE.md migration
    jdtls.md                   # per-platform setup, enabledPlugins
evals/java-agent-ready/        # ≥3 cases
```

Changes to existing skills:

- `java-maven/references/build-hardening.md` — JaCoCo section (floor at current coverage).
- `java-testing/SKILL.md` — `*IT` + `@Tag("slow")` convention, fast/full commands, quiet test
  output; overflow to `references/test-split-and-output.md` if the body grows too long.

Invocation: `/java-skills:java-agent-ready [area…]` (no args = all areas). Also triggers on
"make this project agent-ready", "set this repo up for Claude/agents".

## Workflow

1. **Detect** — Maven? Modules, logging backend (logback/log4j2), DB/broker dependencies,
   existing CLAUDE.md / AGENTS.md / `.claude/`. Run the existing build once; if it's red, report
   and ask before continuing.
2. **Audit** — read-only, delegated to a subagent to keep file dumps out of the main context.
   Per area: present / partial / missing, evidence (`file:line`), proposed change.
3. **Report & pick** — gap table; ask which areas to apply.
4. **Apply** in order, building after each:
   project baseline → test split + quiet output → hermetic infra → feedback tooling → agent
   docs → JDTLS. A red build stops the run with that area's changes left uncommitted.
5. **Agent docs last**, so AGENTS.md lists only commands that exist. Offer `claude-md-improver`
   if installed.
6. **Hand back** — per-area summary with a suggested commit message each. Nothing is committed.

## Areas

| Area | Present when | Apply |
| --- | --- | --- |
| Project baseline | `mvnw` + `.mvn/wrapper/`; JDK pinned (`maven.compiler.release`, Enforcer `requireJavaVersion`, `.sdkmanrc` or toolchains); `.mvn/maven.config`; `.editorconfig` | `mvn wrapper:wrapper` with pinned Maven; `.sdkmanrc`; Enforcer rule; `-ntp` in `maven.config`; `.editorconfig` |
| Test split | Failsafe configured, `*IT` exist, slow tests excludable | Add Failsafe; rename tests that boot Spring/containers/network to `*IT`; `@Tag("slow")` slow unit tests; `fast` profile excludes `slow` |
| Quiet output | Test log level ≤ WARN; output redirected; `-ntp` | `logback-test.xml` (or log4j2) with `${test.log.level:-WARN}`; `redirectTestOutputToFile` in Surefire/Failsafe; quiet Spring/Testcontainers loggers |
| Hermetic tests | Diagnosis catalogue finds nothing | Infra: external DB/broker → Testcontainers, fixed ports → random, env/host config → test properties; JUnit parallel only if the suite passes twice in parallel. Test code (static state, real clock, `Thread.sleep`, order dependence): report `file:line`, fix only if picked |
| Feedback tooling | build-hardening pieces + JaCoCo | build-hardening staged rollout; JaCoCo floor |
| Agent docs | AGENTS.md with build/test commands; `.claude/rules` where warranted | Write AGENTS.md, path-scoped rules, migrate CLAUDE.md |
| JDTLS | n/a (user machine) | Setup note; optional `enabledPlugins` in `.claude/settings.json` |

### .editorconfig

Whitespace basics only — never a formatter by another name:

- `root = true`; `charset = utf-8`, `end_of_line = lf`, `insert_final_newline`,
  `trim_trailing_whitespace`; `indent_style = space`.
- `indent_size` per type (`*.java`, `pom.xml`/`*.xml`, `*.{yml,yaml,json}`, `*.properties`),
  **inferred from existing files**, not imposed.
- `*.md`: `trim_trailing_whitespace = false`. Makefiles: tabs. `*.{bat,cmd}`: CRLF.
- No `ij_java_*` IntelliJ properties. Existing violations are reported, not mass-fixed.

### SDKMAN nudge

`.sdkmanrc` pins the JDK (and Maven, if not wrapper-only) via `sdk env init`. If the user doesn't
have [SDKMAN](https://sdkman.io/) (no `~/.sdkman` / `$SDKMAN_DIR` — `sdk` is a shell function, so
`command -v` misses it), recommend it in the hand-back with the install command from sdkman.io,
`sdk env install` to fetch the pinned JDK, and `sdkman_auto_env=true` in
`~/.sdkman/etc/config` to switch on `cd`. Never install it for them (it edits shell profiles).
Windows: SDKMAN needs WSL or Git Bash — say so rather than suggest it for native PowerShell.

### AGENTS.md

~60–100 lines; only what an agent can't infer from the code. Every project-specific line cites
audit evidence. Skeleton:

```text
# <project>
<purpose; module map if multi-module>

## Build & test
./mvnw -q test -Pfast          # inner loop
./mvnw -q verify               # full; run before handing back
./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG   # re-run a failure loudly
Failures: target/surefire-reports/ (unit), target/failsafe-reports/ (IT)
Coverage: target/site/jacoco/index.html; floor enforced by jacoco:check

## Conventions
- No formatter by design; match surrounding style. .editorconfig sets whitespace.
- Tests: *Test fast, *IT integration (Failsafe), @Tag("slow") for slow unit tests.
- <project-specific rules from the audit>

## Don'ts
- Never weaken checks (Checkstyle, Error Prone, JaCoCo floor) to pass a build.
- <generated dirs not to edit, etc.>

## Code intelligence
jdtls-lsp plugin — see <link>
```

`.claude/rules/*.md` are written only for real path-specific rules found in the audit (e.g.
`src/test/**`, migrations dir, generated sources). No boilerplate rules.

### JDTLS (`jdtls.md`)

Source: <https://code.claude.com/docs/en/plugins/code-intelligence#install-a-code-intelligence-plugin>
and the `jdtls-lsp` plugin README.

1. JDK 17+ (a JDK, not a JRE) for jdtls itself, independent of the project's JDK.
2. Install the `jdtls` binary: macOS `brew install jdtls`; Arch `yay -S jdtls`; other Linux and
   Windows: Eclipse JDT.LS download, extract (e.g. `~/.local/share/jdtls`), put a `jdtls`
   launcher on `PATH`.
3. Verify on the `PATH` of the shell that starts `claude`: `which jdtls` /
   `Get-Command jdtls`.
4. `/plugin install jdtls-lsp@claude-plugins-official`, then `/reload-plugins` or a new session.
5. Confirm: after Claude edits a `.java` file a "Found N new diagnostic issues" line appears;
   otherwise `/plugin` → Errors shows `Executable not found in $PATH`. Not available in cloud
   sessions.

Project side: with the user's OK, `.claude/settings.json` gets
`"enabledPlugins": {"jdtls-lsp@claude-plugins-official": true}`.

## Failure handling

- Non-Maven → stop. Baseline build red → report, ask before continuing.
- Area build red → stop, show the failure, leave that area's diff for review; never weaken a check.
- Parallel trial fails or flakes → leave parallel off, report the interfering tests.
- No tests → JaCoCo report only, no floor.
- Offline / resolution failure → report and skip the step; never guess versions.
- Versions are looked up at run time (Maven Central, release pages) and pinned; references show
  config shape only, never a hardcoded "latest".
- No secrets written; DB URLs/credentials found during detection stay out of AGENTS.md.

## Evals (`evals/java-agent-ready/`)

1. `bare-project-audit` — scaffolded minimal Maven project, no wrapper/Failsafe, noisy logging.
   Graders: skill fired; gap report covers every area; no files modified before the pick.
2. `apply-test-split` — Spring-context test named `*Test` plus a slow unit test. Regex: Failsafe
   config and `*IT` rename; llm: full suite stays the default.
3. `existing-claude-md` — CLAUDE.md with build commands. Graders: AGENTS.md merges the content;
   CLAUDE.md is `git mv`'d.
4. `hermetic-diagnosis` — `LocalDateTime.now()`, fixed port, static cache in tests. Graders:
   each reported with `file:line`; test code not rewritten.

Prefer reply/file-content graders; cases needing Bash in the sandbox may only run in CI (local
`~/.ssh` symlink blocks them).

## To verify while implementing

- SDKMAN commands (`sdk env init`, `sdkman_auto_env`) against sdkman.io.
- Windows jdtls install route (`jdtls.bat` needs Python; Scoop or other package availability).
- `enabledPlugins` key format in project `.claude/settings.json`.
- `.claude/rules` frontmatter (path globs) format.
- Current versions of Maven Wrapper, Failsafe, JaCoCo — looked up, not recalled.
- Whether `java-testing` / `build-hardening` changes need new eval cases.
