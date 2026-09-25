# Skill evaluations

Scenario-based evaluations for each skill, in the structure recommended by
[Anthropic's skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices#build-evaluations-first),
run with [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals).
Each skill has three cases under `evals/<skill>/<case>/`:

- `prompt.md` — the user request (body) plus run limits and tools (frontmatter)
- `graders/criteria.md` — `llm` rubric; every listed behavior must be present
- `graders/skill-fired.md` — `tool_used: Skill` check that the skill was invoked
- other `graders/*.md` — deterministic checks on the reply (`regex`) or on the steps
  (`tool_used`); ones that can only pass with the plugin loaded are `arm: with-only`
- `case.yaml` + `scaffold.sh` — `java-audit` only: seeds a fixture repo to audit

## Running

From the repo root:

```bash
claude plugin eval . --scaffold                              # full suite, with no-plugin baseline
claude plugin eval . --scaffold --case branch-diff-audit --allow-tools Bash   # needs git
claude plugin eval . --tag java-maven                         # one skill
claude plugin eval . --case child-pom-review --runs 1 --ablation none   # cheap iteration
```

`--scaffold` runs the audit fixtures (our own scripts). Graders judge Claude's reply, so don't
grant `Write`/`Edit`, and grant `Bash` only to `branch-diff-audit`: `--allow-tools` applies to
every case in the run, and a case that writes its answer to a file leaves the judge only a
summary. Without the grant, `branch-diff-audit` fails by design. Every run is a real model call
billed to your account; results land in `evals/results/` (gitignored).

Re-run a skill's cases after editing it. `Δ` (with-plugin minus baseline) shows what the skill
contributes; a failing `skill-fired` grader means the description isn't triggering on natural
phrasing. Test with every model the plugin targets (`--model haiku|sonnet|opus`), since they
behave differently under thin guidance.
