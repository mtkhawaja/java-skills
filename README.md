# java-skills

A [Claude Code](https://claude.com/claude-code) plugin providing a skills library for Java
development. The repo doubles as its own plugin marketplace.

## Install

```
/plugin marketplace add mtkhawaja/java-skills
/plugin install java-skills@java-skills
```

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # marketplace listing (source: ./)
skills/              # skills, one subdirectory each with a SKILL.md
```

## License

MIT
