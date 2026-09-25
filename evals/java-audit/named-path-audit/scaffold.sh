#!/usr/bin/env bash
# Seeds a small Maven/Java 21 repo with deliberate convention violations.
set -euo pipefail

mkdir -p src/main/java/com/acme/billing src/main/java/com/acme/shipping \
  src/test/java/com/acme/billing

cat >pom.xml <<'XML'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.acme</groupId>
  <artifactId>acme-app</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
  </properties>
</project>
XML

cat >src/main/java/com/acme/billing/InvoiceService.java <<'JAVA'
package com.acme.billing;

import java.util.*;

public class InvoiceService {
    private InvoiceRepository repository = new InvoiceRepository();

    public Invoice find(String id) {
        try {
            return repository.load(id);
        } catch (Exception e) {
            System.out.println("failed: " + e);
            return null;
        }
    }
}
JAVA

cat >src/main/java/com/acme/billing/InvoiceRepository.java <<'JAVA'
package com.acme.billing;

public class InvoiceRepository {
    public Invoice load(String id) throws Exception {
        return new Invoice(id);
    }
}
JAVA

cat >src/main/java/com/acme/billing/Invoice.java <<'JAVA'
package com.acme.billing;

public class Invoice {
    private final String id;

    public Invoice(String id) { this.id = id; }

    public String getId() { return id; }
}
JAVA

cat >src/main/java/com/acme/shipping/ShippingService.java <<'JAVA'
package com.acme.shipping;

import java.util.Date;

public class ShippingService {
    public Date eta() {
        return new Date(System.currentTimeMillis() + 86_400_000L);
    }
}
JAVA

cat >src/test/java/com/acme/billing/InvoiceServiceTest.java <<'JAVA'
package com.acme.billing;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class InvoiceServiceTest {
    @Test
    public void test1() throws Exception {
        Thread.sleep(500);
        assertTrue(new InvoiceService().find("42") != null);
    }
}
JAVA
