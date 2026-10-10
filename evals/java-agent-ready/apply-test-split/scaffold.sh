#!/usr/bin/env bash
# Seeds a single-module repo whose slow tests all run under Surefire.
set -euo pipefail

mkdir -p src/test/java/com/acme/orders

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>orders</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.0</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>postgresql</artifactId>
      <version>1.20.1</version>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.3.1</version>
      </plugin>
    </plugins>
  </build>
</project>
XML

cat >src/test/java/com/acme/orders/CustomerRepositoryTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;

class CustomerRepositoryTest {
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Test
    void savesCustomer() {
        POSTGRES.start();
    }
}
JAVA

cat >src/test/java/com/acme/orders/PricingSimulationTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;

class PricingSimulationTest {
    // Monte Carlo over 50M quotes; ~40s on a laptop.
    @Test
    void convergesOnExpectedMargin() {
        double sum = 0;
        for (long i = 0; i < 50_000_000L; i++) {
            sum += Math.sqrt(i);
        }
    }
}
JAVA

cat >src/test/java/com/acme/orders/OrderTotalTest.java <<'JAVA'
package com.acme.orders;

import org.junit.jupiter.api.Test;

class OrderTotalTest {
    @Test
    void sumsLines() {
    }
}
JAVA
