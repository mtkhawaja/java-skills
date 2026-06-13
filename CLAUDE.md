# java-skills

A Claude Code plugin (and self-hosting marketplace) providing a skills library for Java development.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest
- `.claude-plugin/marketplace.json` — marketplace listing (`source: "./"`)
- `skills/` — one subdirectory per skill, each with a `SKILL.md`
- `agents/` — subagent definitions, one `.md` per agent

## Writing skills

**Always consult
[Anthropic's skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
before writing a new skill or substantially editing one**, and keep the repo conformant with it:
third-person "Use when…" descriptions (≤1024 chars), SKILL.md body well under 500 lines, reference
files linked one level deep from SKILL.md (with a `## Contents` section once they pass 100 lines),
no time-sensitive phrasing, and three scenarios per skill in `evals/` (see `evals/README.md`).

## Checks

`./scripts/check.sh` runs every repo check (shellcheck, syntax, JSON/eval validation, version
lockstep, hook behavioral tests). CI runs the same script — run it before claiming work done.

## CI workflows

**Never reference a GitHub Action version from memory — training data is always stale here.**
Before writing or editing anything under `.github/workflows/`, look up the current major of every
action used (e.g. `actions/checkout` releases page) and pin to that. The same applies to any other
externally versioned tool referenced in CI.

## Versioning

The version lives in two manifests and **must stay in sync**. Never hand-edit version fields.
`scripts/bump-version.sh` is the single source of truth — it bumps every field declared in
`.version-bump.json` in lockstep.

```bash
./scripts/bump-version.sh --check      # show versions, detect drift
./scripts/bump-version.sh --audit      # also scan repo for stray version strings
./scripts/bump-version.sh <X.Y.Z>      # bump all declared files
```

- Use semver, not commit hashes — `/plugin` relies on semver ordering for update detection.
- Bump on release, then tag the commit `vX.Y.Z`.
- Adding a new file that carries the version? Register it in `.version-bump.json`.
