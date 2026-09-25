---
tags: [java-maven]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this child pom.xml from a Maven 3.9 multi-module build. The parent's <dependencyManagement> already manages commons-lang3 at 3.17.0 and the parent has a <pluginManagement> section. List every problem and show the corrected POM.

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.acme</groupId><artifactId>acme-parent</artifactId><version>2.0.0</version>
  </parent>
  <artifactId>acme-billing</artifactId>
  <dependencies>
    <dependency>
      <groupId>org.apache.commons</groupId><artifactId>commons-lang3</artifactId>
      <version>3.14.0</version>
    </dependency>
    <dependency>
      <groupId>com.oracle</groupId><artifactId>ojdbc8</artifactId><version>19.3</version>
      <scope>system</scope>
      <systemPath>${basedir}/lib/ojdbc8.jar</systemPath>
    </dependency>
    <dependency>
      <groupId>org.apache.commons</groupId><artifactId>commons-lang3</artifactId>
    </dependency>
  </dependencies>
  <build>
    <finalName>${artifactId}-${pom.version}</finalName>
    <plugins>
      <plugin>
        <artifactId>maven-shade-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
```
