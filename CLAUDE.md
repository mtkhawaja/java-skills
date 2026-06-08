# java-skills

A Claude Code plugin (and self-hosting marketplace) providing a skills library for Java
development.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest
- `.claude-plugin/marketplace.json` — marketplace listing (`source: "./"`)
- `skills/` — one subdirectory per skill, each with a `SKILL.md`

## Versioning

The version lives in two manifests and **must stay in sync**. Never hand-edit version fields.
`scripts/bump-version.sh` is the single source of truth — it bumps every field declared in
`.version-bump.json` in lockstep.

```
./scripts/bump-version.sh --check      # show versions, detect drift
./scripts/bump-version.sh --audit      # also scan repo for stray version strings
./scripts/bump-version.sh <X.Y.Z>      # bump all declared files
```

- Use semver, not commit hashes — `/plugin` relies on semver ordering for update detection.
- Bump on release, then tag the commit `vX.Y.Z`.
- Adding a new file that carries the version? Register it in `.version-bump.json`.
