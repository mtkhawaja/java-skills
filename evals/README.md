# Skill evaluations

Scenario-based evaluations for each skill, in the structure recommended by
[Anthropic's skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#build-evaluations-first).
One JSON file per skill; each file holds three scenarios.

There is no built-in runner. To execute an evaluation:

1. Dispatch a **fresh** agent (no conversation history) that reads the skill's `SKILL.md`
   (and only the reference files the SKILL.md routes it to) as its binding convention document.
2. Give it the scenario's `query` verbatim.
3. Grade the output against every item in `expected_behavior` — each item must be satisfied.

Re-run the relevant file after editing a skill, and run a **baseline** (same query, no skill)
when adding a new rule to confirm the rule actually changes behavior. Test with every model
the plugin targets (Haiku/Sonnet/Opus behave differently under thin guidance).
