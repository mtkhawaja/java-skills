---
type: llm
---

PASS only if the response satisfies this:

- Flags all four causes with file references: real clock in InvoiceDueDateTest, fixed port 8089 in PaymentClientTest, shared static map in RateCacheTest, external dev-db datasource in application-test.properties

FAIL if it is missing or contradicted.
