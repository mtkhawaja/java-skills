---
type: llm
---

PASS only if the response satisfies every item below:

- Flags the child re-declaring (and silently downgrading) the managed commons-lang3 version
- Flags the duplicate commons-lang3 declaration (Maven 4 fails on it)
- Flags <scope>system</scope> and replaces it with a repository-managed artifact
- Flags the prefixless ${artifactId} and ${pom.version} expressions (use ${project.*})
- Adds the explicit plugin <groupId> and pins the plugin version in the parent's <pluginManagement>, not in the child

FAIL if any item is missing or contradicted.
