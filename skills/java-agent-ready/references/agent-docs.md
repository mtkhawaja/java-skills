# Agent docs: AGENTS.md and .claude/rules

**Docs:** [Claude Code memory — AGENTS.md and rules](https://code.claude.com/docs/en/memory)

AGENTS.md is the one instruction file every coding agent reads. Claude Code reads it when there is
no `CLAUDE.md`, `.claude/CLAUDE.md`, or `CLAUDE.local.md` in the working directory or above.
`.claude/rules/` files load alongside it either way.

## Contents

- What goes in AGENTS.md
- Skeleton
- Existing instruction files
- .claude/rules
- After writing

## What goes in AGENTS.md

Only what an agent can't infer from the code, in 60–100 lines:

- **Commands that exist after the applied areas** — never one the project doesn't have yet. If
  the test split wasn't applied, there is no `-Pfast`; if JaCoCo wasn't, no coverage line.
- **Project-specific rules backed by audit evidence** — frameworks, layering, generated code,
  migrations. Every such line must trace to something the audit found (`file:line` in the report).
- **Two mandatory lines:** no formatter by design (match surrounding style), and never weaken
  checks to pass a build.
- **No secrets** — no URLs with credentials, tokens, or internal hostnames.

## Skeleton

```markdown
# <project>

<One paragraph: what it is. Module map if multi-module: module → responsibility.>

## Build & test

./mvnw -q test -Pfast          # inner loop
./mvnw -q verify               # full; run before handing back
./mvnw -q test -Dtest=Foo#bar -Dtest.log.level=DEBUG   # re-run a failure loudly
                                                       # (reactor: add -pl <module>)

Failures: target/surefire-reports/ (unit), target/failsafe-reports/ (IT)
Coverage: target/site/jacoco/index.html; floor enforced by jacoco:check

## Conventions

- No formatter by design; match the surrounding style. .editorconfig sets whitespace.
- Tests: *Test fast, *IT integration (Failsafe), @Tag("slow") for slow unit tests.
- <project-specific rules from the audit>

## Don'ts

- Never weaken checks (Checkstyle, Error Prone, JaCoCo floor) to pass a build.
- <generated dirs not to edit, applied migrations not to change, …>

## Code intelligence

jdtls-lsp plugin — see https://code.claude.com/docs/en/plugins/code-intelligence
IntelliJ users: run `/ide` to share IntelliJ inspections with Claude.
```

## Existing instruction files

| Found | Do |
| --- | --- |
| Neither | Write AGENTS.md. |
| `CLAUDE.md` only | Merge its content into the skeleton, then `git mv CLAUDE.md AGENTS.md` and write the merged content over it, so history follows the file. |
| `AGENTS.md` only | Extend it in place; keep its existing rules. |
| Both | Claude currently reads only CLAUDE.md. Merge CLAUDE.md's unique content into AGENTS.md, show the user the merged result, then `git rm CLAUDE.md`. |
| `.claude/CLAUDE.md` | Same as `CLAUDE.md`. |

Carry every rule over; drop only commands the merge replaces with verified ones. Never touch
`CLAUDE.local.md`. If one exists, tell the user: a `CLAUDE.local.md` stops Claude reading
AGENTS.md for them. Their fix is an `@AGENTS.md` line at the top of their `CLAUDE.local.md`.

Claude Code versions before v2.1.277, or sessions with the built-in AGENTS.md plugin disabled,
read only CLAUDE.md. If the user needs those, keep a one-line `CLAUDE.md` containing `@AGENTS.md`
instead of removing it.

## .claude/rules

Rules every agent must follow (never edit generated sources, never change applied migrations) go
in AGENTS.md — other agents don't read `.claude/rules/`. Add a rule file only for **path-specific
detail found in the audit** that is too long or too narrow for AGENTS.md. No boilerplate rules,
and never the same rule in both places.

```markdown
---
paths:
  - "src/main/resources/db/migration/**"
---

# Flyway migrations

Name new files `V<yyyyMMddHHmm>__<snake_case>.sql`. One schema change per file; every
`CREATE INDEX` on a large table uses `CONCURRENTLY` in its own migration.
```

Typical candidates: migration naming and authoring conventions, how a generator is configured,
test-tree conventions that differ from main code. A rule without `paths` loads for every file —
put that content in AGENTS.md instead.

## After writing

If the `claude-md-management` plugin is installed, offer to run its `claude-md-improver` skill on
the new AGENTS.md. Otherwise skip it without comment.
