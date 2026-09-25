---
type: llm
---

PASS only if the response satisfies every item below:

- Unit test uses @ExtendWith(MockitoExtension.class) with @Mock/@InjectMocks (no openMocks, no imperative mock())
- All assertions use AssertJ (assertThat), never JUnit's assertEquals/assertTrue
- Every test method has a method-level @DisplayName whose camelCase mirror is the method name, behavior-phrased (shouldDoXWhenY), and no class-level @DisplayName appears
- Integration test uses Testcontainers PostgreSQL (not H2), wired via @ServiceConnection on a static @Container field
- Integration test class is named *IT and/or @Tag("integration"), with Failsafe vs Surefire separation explained

FAIL if any item is missing or contradicted.
