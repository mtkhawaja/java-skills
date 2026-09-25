---
type: llm
---

PASS only if the response satisfies every item below:

- Parent is pom-packaged aggregator with <modules>, <dependencyManagement> (or an imported BOM) and <pluginManagement> pinning every version; children declare dependencies without versions
- Recommends the Maven Wrapper so builds don't depend on the machine's Maven
- Inter-module dependencies use ${project.version} (or ${revision} CI-friendly versioning)
- Recommends mvn verify as the default full check rather than clean install

FAIL if any item is missing or contradicted.
