#!/usr/bin/env bash
# Seeds a two-module Maven repo with none of the agent-ready pieces in place.
set -euo pipefail

mkdir -p api/src/main/java/com/acme/api api/src/test/java/com/acme/api \
  api/src/test/resources core/src/main/java/com/acme/core

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>acme-parent</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <modules>
    <module>core</module>
    <module>api</module>
  </modules>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

for m in core api; do
  cat >"${m}/pom.xml" <<XML
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.acme</groupId>
    <artifactId>acme-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
  </parent>
  <artifactId>acme-${m}</artifactId>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.0</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>ch.qos.logback</groupId>
      <artifactId>logback-classic</artifactId>
      <version>1.5.6</version>
    </dependency>
  </dependencies>
</project>
XML
done

cat >api/src/test/resources/logback-test.xml <<'XML'
<configuration>
  <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <encoder><pattern>%d %-5level %logger - %msg%n</pattern></encoder>
  </appender>
  <root level="DEBUG"><appender-ref ref="CONSOLE"/></root>
</configuration>
XML

cat >api/src/test/java/com/acme/api/OrderControllerTest.java <<'JAVA'
package com.acme.api;

import org.junit.jupiter.api.Test;

class OrderControllerTest {
    @Test
    void createsOrder() throws Exception {
        Thread.sleep(2000);
    }
}
JAVA
