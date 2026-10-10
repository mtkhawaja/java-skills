#!/usr/bin/env bash
# Seeds tests with clock, port, shared-state, and external-DB hermeticity bugs.
set -euo pipefail

mkdir -p src/test/java/com/acme/billing src/test/resources

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>billing</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

cat >src/test/resources/application-test.properties <<'PROPS'
spring.datasource.url=jdbc:postgresql://dev-db.acme.internal:5432/billing
spring.datasource.username=billing
PROPS

cat >src/test/java/com/acme/billing/InvoiceDueDateTest.java <<'JAVA'
package com.acme.billing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class InvoiceDueDateTest {
    @Test
    void dueThirtyDaysOut() {
        assertEquals(LocalDate.now().plusDays(30), new Invoice().dueDate());
    }
}
JAVA

cat >src/test/java/com/acme/billing/PaymentClientTest.java <<'JAVA'
package com.acme.billing;

import org.junit.jupiter.api.Test;

class PaymentClientTest {
    private final PaymentClient client = new PaymentClient("http://localhost:8089");

    @Test
    void charges() {
        client.charge("inv-1");
    }
}
JAVA

cat >src/test/java/com/acme/billing/RateCacheTest.java <<'JAVA'
package com.acme.billing;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class RateCacheTest {
    static final Map<String, Integer> RATES = new HashMap<>();

    @Test
    void storesRate() {
        RATES.put("USD", 1);
        assertEquals(1, RATES.size());
    }

    @Test
    void storesSecondRate() {
        RATES.put("EUR", 2);
        assertEquals(1, RATES.size());
    }
}
JAVA
