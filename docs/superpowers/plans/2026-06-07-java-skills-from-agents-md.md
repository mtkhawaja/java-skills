# Java Skills from AGENTS.md — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose `agent-guidelines/java/AGENTS.md` into 12 focused, individually-discoverable skills in the `java-skills` plugin, each built via writing-skills RED-GREEN-REFACTOR.

**Architecture:** One skill per topic under `skills/<name>/SKILL.md`. The centerpiece `java-version-features` carries per-LTS reference files (8/11/17/21/25) plus JDK-version detection. Every skill is built test-first: a subagent attempts a realistic Java task at baseline (RED), the SKILL.md is authored to close the observed gaps (GREEN), then loopholes/gaps are closed (REFACTOR). Skills are tested by pasting SKILL.md into a fresh subagent's context (plugin isn't installed during dev).

**Tech Stack:** Claude Code plugin (skills), Markdown SKILL.md + YAML frontmatter, subagents as test harness, `scripts/bump-version.sh` for versioning.

---

## Conventions for every skill task

Each skill = one Task following this identical 5-step shape. Code/prose for the SKILL.md is authored in Step 3 (the GREEN step) from the **content checklist** given in that task, per writing-skills (prose is inherently authored here, not pre-baked in this plan).

- **Step 1 (RED):** Dispatch a subagent with the task's baseline scenario, WITHOUT the skill. Record verbatim what conventions it omits/violates.
- **Step 2 (verify RED):** Confirm the baseline genuinely misses the target rules (if it already complies, the scenario is too easy — harden it).
- **Step 3 (GREEN):** Write `skills/<name>/SKILL.md`. Frontmatter rules (ALL skills): `name` hyphen-only; `description` third-person, starts "Use when…", names that it's Java-specific, no workflow summary, keywords for search; one excellent example (not multi-language); cover the content checklist.
- **Step 4 (verify GREEN):** Re-run the scenario WITH the SKILL.md pasted into the subagent's context. Confirm it now complies.
- **Step 5 (REFACTOR + commit):** Capture new rationalizations/gaps → add counters (discipline skills get a rationalization table + red-flags list) → re-test until clean. Then `git add skills/<name> && git commit`.

Frontmatter description style (apply per skill):
`description: Use when writing or reviewing Java <topic> — <symptoms/triggers>`

---

## Task 0: Setup

**Files:** Remove `skills/.gitkeep` (folded into first skill commit).

---

## Task 1: java-version-features (pattern-setter — build first, then CHECKPOINT)

**Files:**
- Create: `skills/java-version-features/SKILL.md`
- Create: `skills/java-version-features/references/java-8.md`, `java-11.md`, `java-17.md`, `java-21.md`, `java-25.md`
- Source: AGENTS.md:320–431

**RED scenario:** Ask subagent to "add a feature to this Maven project (pom sets `<source>17</source>`)" and watch whether it (a) checks the configured Java version at all, (b) avoids features beyond 17, (c) uses version-appropriate idioms. Baseline likely ignores version gating.

**Content checklist — SKILL.md:**
- Rule: only use language/library features ≤ the project's configured Java version. **Never use preview/incubator features unless the project already enables `--enable-preview`** — even on the matching version.
- Detection: Maven (`maven-compiler-plugin` source/target/`release`, or `java.version` property); Gradle (toolchain, or `sourceCompatibility`/`targetCompatibility`). Fallback: lowest LTS the project mentions, else Java 8.
- Instruct: detect version → read the matching `references/java-<N>.md` (each is cumulative — read the highest LTS ≤ project version).
- Keep SKILL.md lean; push feature catalogs into reference files.

**Accuracy discipline (applies to ALL reference files):** Every feature must cite its JEP number and be tagged **final/standard** vs **preview/incubator**. NEVER recommend a preview/incubator feature as a default idiom — call it out explicitly as requiring `--enable-preview` and "use only if the project already opts in." Verify each claim against the JEP page (`openjdk.org/jeps/<N>`) and the release's JEP list before writing; facts below are already cross-checked against JDK release notes / InfoQ release summaries (see Sources).

**Content checklist — reference files (cumulative-aware; each opens with "Includes everything from prior LTS"):**
- `java-8.md`: lambdas + streams (simple pipelines; note `Collectors.toList()` → `Stream.toList()` only on 16+), Optional **as return type only** (never fields/params/collections), `java.time` over Date/Calendar. (AGENTS.md:332–356)
- `java-11.md`: `java.net.http.HttpClient` (final, JEP 321); `String` helpers (`isBlank`, `lines`, `strip`), `Files.readString`/`writeString`; `var` in lambda params (JEP 323); single-file source launch (`java Foo.java`, JEP 330). (358–374)
- `java-17.md`: records (final since 16, JEP 395), sealed classes (final, JEP 409), `instanceof` pattern matching (final since 16, JEP 394), text blocks (final since 15, JEP 378). **Note:** pattern matching for `switch` is only *preview* in 17 — do not recommend until 21. (376–405)
- `java-21.md`: virtual threads (final, JEP 444), pattern matching for `switch` (final, JEP 441), record patterns (final, JEP 440), sequenced collections (final, JEP 431). **Preview in 21 — flag, don't default:** structured concurrency (JEP 453), scoped values (JEP 446). (407–431)
- `java-25.md`: **NEW (original stops at 21).** Finalized in 25: scoped values (JEP 506), module import declarations (JEP 511), flexible constructor bodies (JEP 513), compact source files & instance main methods (JEP 512 — good for scripts/learning), KDF API (JEP 510). **Still preview in 25 — flag, don't default:** structured concurrency (JEP 505, fifth preview), primitive types in patterns (JEP 507). Confirm each against its JEP page before writing.

- [ ] Steps 1–5 per the conventions above.
- [ ] **CHECKPOINT:** stop after this task; confirm SKILL.md template + reference-file format with the user before mass-producing the rest.

---

## Task 2: java-conventions

**Files:** Create `skills/java-conventions/SKILL.md`. Source: AGENTS.md:39–49 ("Java Guidelines" block). Type: discipline.

**RED scenario:** Subagent adds a small class + method to a plain Java project; watch for missing `final`, setter/field injection instead of constructor, brace-less single-line `if`, and member/static imports.

**Content checklist:** final-by-default for vars/params/fields unless mutation is justified; constructor-based init, mandatory deps via constructor; never omit braces on single-line if/for/while/else; class-level imports only, no member/static imports unless strictly required. Include rationalization table + red-flags (discipline skill).

- [ ] Steps 1–5.

---

## Task 3: java-exceptions

**Files:** Create `skills/java-exceptions/SKILL.md`. Source: AGENTS.md:142–158. Type: discipline.

**RED scenario:** Subagent writes a method calling something that throws checked + a blocking call (so `InterruptedException` is in play); watch for `catch (Exception)`, swallowing, lost cause, missing interrupt restore.

**Content checklist:** exceptions for exceptional conditions only (not control flow); catch most specific type; never swallow (handle / wrap+rethrow with context / translate); preserve cause chain; actionable context, no secrets/PII; domain-specific exceptions where clearer; on `InterruptedException` restore interrupt flag and propagate; cleanup/`finally` must not mask original. Rationalization table + red-flags.

- [ ] Steps 1–5.

---

## Task 4: java-time

**Files:** Create `skills/java-time/SKILL.md`. Source: AGENTS.md:247–260. Type: discipline.

**RED scenario:** Subagent writes a method that timestamps an event and formats it; watch for `Instant.now()`/`LocalDateTime`/system default zone instead of injected `Clock` + UTC.

**Content checklist:** UTC internally (`Instant` preferred, or `OffsetDateTime` +00:00); inject `java.time.Clock` for any "now" (testable: `Clock.fixed`/`offset`; prod `Clock.systemUTC()`); never persist `LocalDateTime` without offset; explicit `ZoneId` only at presentation; ISO-8601 default format. Rationalization table + red-flags.

- [ ] Steps 1–5.

---

## Task 5: java-testing

**Files:** Create `skills/java-testing/SKILL.md`. Source: AGENTS.md:179–207. Type: discipline.

**RED scenario:** Subagent writes a JUnit test for a small service; watch for JUnit assertions instead of AssertJ, missing/class-level `@DisplayName`, method name not mirroring DisplayName, implementation-focused names, shared mutable state.

**Content checklist:** JUnit Jupiter (5+) default; AssertJ for assertions; method-level `@DisplayName` (natural language) on every test, never class-level; method name mirrors DisplayName in camelCase; behavior naming `shouldDoXWhenY`; order-independent & parallel-safe; one behavior per test; `@ParameterizedTest` for matrices; never skip/disable tests. Include the `NotificationServiceTest` example. Rationalization table + red-flags.

- [ ] Steps 1–5.

---

## Task 6: java-mockito

**Files:** Create `skills/java-mockito/SKILL.md`. Source: AGENTS.md:209–245. Type: technique.

**RED scenario:** Subagent writes a Mockito test for a service with one collaborator; watch for `MockitoAnnotations.openMocks`, imperative `mock()`, deep stubbing, missing `@ExtendWith(MockitoExtension.class)`.

**Content checklist:** `@ExtendWith(MockitoExtension.class)`; annotation mocks (`@Mock`/`@Spy`/`@Captor`/`@InjectMocks`), no imperative mock creation / no `openMocks`; avoid deep stubs / mock-heavy setups (prefer fakes/real collaborators); stub only inside the test that needs it, no global stubbing; `@MockitoBean` (prefer over `@MockBean`) for Spring beans. Include both code examples.

- [ ] Steps 1–5.

---

## Task 7: java-logging

**Files:** Create `skills/java-logging/SKILL.md`. Source: AGENTS.md:51–105. Type: technique.

**RED scenario:** Subagent adds logging to a method that processes a user object and can fail; watch for `System.out`, string concatenation in log calls, logging `e.getMessage()` only, logging sensitive fields.

**Content checklist:** add SLF4J logger (`LoggerFactory.getLogger`) or project Log4j2, no new frameworks; never `System.out/err`; parameterized logging (`{}`) not concatenation; level guide (TRACE/DEBUG/INFO/WARN/ERROR); no noise in tight loops/getters; log context (IDs/counts) not whole objects; never log secrets/PII; log once at the right boundary; pass exception as parameter (preserve stack trace). Include SLF4J + parameterized examples.

- [ ] Steps 1–5.

---

## Task 8: java-strings

**Files:** Create `skills/java-strings/SKILL.md`. Source: AGENTS.md:107–140. Type: technique.

**RED scenario:** Subagent builds a path and a message and concatenates in a loop; watch for `+` concatenation where literal/`formatted`/`String.join`/`StringBuilder` is better.

**Content checklist:** literals/templates over `+`; `String.format`/`"%s".formatted(...)` for interpolation; `String.join` for joining known elements; `StringBuilder`/`StringJoiner` in loops, never `+` in a loop. Include the four contrast examples.

- [ ] Steps 1–5.

---

## Task 9: java-validation

**Files:** Create `skills/java-validation/SKILL.md`. Source: AGENTS.md:168–177. Type: technique.

**RED scenario:** Subagent writes a public method taking an id + name from outside; watch whether it validates at the boundary (null/blank) and fails fast with clear errors.

**Content checklist:** validate early/fail fast at boundaries (treat external input as untrusted); `Objects.requireNonNull` for null checks; blank checks for strings (`StringUtils.isBlank/isNotBlank` when available); clear specific errors without leaking sensitive data; don't defer validation.

- [ ] Steps 1–5.

---

## Task 10: java-resource-management

**Files:** Create `skills/java-resource-management/SKILL.md`. Source: AGENTS.md:160–166. Type: technique.

**RED scenario:** Subagent reads a file / opens a stream; watch for `try`/`finally` close instead of try-with-resources.

**Content checklist:** always try-with-resources over try-finally; multiple resources in one statement; `final var` resources. Include the `Files.newBufferedReader` example.

- [ ] Steps 1–5.

---

## Task 11: java-comments

**Files:** Create `skills/java-comments/SKILL.md`. Source: AGENTS.md:275–318. Type: pattern.

**RED scenario:** Subagent documents a public record/method; watch for mechanics-restating comments, missing exception/edge-case docs, or plain `//` where Javadoc fits.

**Content checklist:** comment intent not mechanics; Javadoc for public APIs (description, usage, behavior); document exception scenarios + edge cases/invariants; avoid redundant/stale comments; prefer Javadoc to inline; Markdown Javadoc (JEP 467) for new docs on **Java 23+** only, don't convert existing standard Javadoc. Include the `Money` record example. Cross-reference java-version-features for the 23+ gate.

- [ ] Steps 1–5.

---

## Task 12: java-jshell

**Files:** Create `skills/java-jshell/SKILL.md`. Source: AGENTS.md:262–273. Type: reference.

**RED scenario:** Ask subagent to quickly validate a small API behavior; watch whether it knows JShell exists (9+) and that JShell output isn't production code.

**Content checklist:** JShell is Java 9+; use for quick experimentation/validation of snippets/APIs; validated logic must become real source + tests (JShell output is not production code). Include the `echo … | jshell` example.

- [ ] Steps 1–5.

---

## Task 13: Finalize

- [ ] Confirm `skills/.gitkeep` removed (folded into first skill commit).
- [ ] Run `plugin-dev:plugin-validator` over the plugin; fix any structural issues.
- [ ] `wc -w` sanity on each SKILL.md; verify frontmatter (`name` hyphen-only, `description` "Use when…", third person).
- [ ] Bump version: `./scripts/bump-version.sh 0.2.0` (adding skills = feature), then `--check`.
- [ ] Commit the bump.

## Self-review checklist (run after drafting each SKILL.md)
- Spec coverage: every AGENTS.md line range above maps to a created skill.
- No placeholder prose in shipped SKILL.md files.
- Cross-references use skill-name only (no `@` links): java-comments → java-version-features.

## Sources (fact-checking — verified during planning)
- JDK 25 JEP set & finalized/preview status: InfoQ "Java 25 … Delivers Finalized Features" (Sept 2025); JEPs 505/506/507/510/511/512/513.
- JDK 8/11 features: Wikipedia "Java version history" (lambdas/streams/java.time; HttpClient JEP 321, single-file JEP 330, var-in-lambda JEP 323).
- JDK 17/21 final vs preview (records JEP 395, sealed 409, instanceof 394, text blocks 378; virtual threads 444, switch patterns 441, record patterns 440, sequenced collections 431; structured concurrency preview 453/505, scoped values 446→506).
- During execution, each reference file's claims are re-checked against `openjdk.org/jeps/<N>` before writing (openjdk.org blocks WebFetch with 403 — fetch JEP text via search cache or an MCP fetch tool).

## Out of scope (follow-ups)
- `using-java-skills` router skill + `SessionStart` hook (superpowers-style auto-surfacing).
- Porting Angular/Python sibling AGENTS.md files.
