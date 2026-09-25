---
type: llm
---

PASS only if the response satisfies every item below:

- Uses OpenRewrite recipes (UpgradeToJava21, UpgradeSpringBoot_3_5, JUnit4to5Migration) with correct artifact coordinates instead of hand-editing
- Previews each migration with the dryRun goal / rewrite.patch before applying, and gates each step with ./mvnw verify
- Keeps migrations in separate commits/PRs
- Uses mvnup (not OpenRewrite) for the Maven 3 to 4 step, following the phased approach in the upgrade reference (3.9 baseline, -fos WARN cleanup, optional model 4.1.0)

FAIL if any item is missing or contradicted.
