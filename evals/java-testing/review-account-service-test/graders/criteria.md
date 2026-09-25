---
type: llm
---

PASS only if the response satisfies every item below:

- Removes the class-level @DisplayName and adds a method-level one in natural language
- Renames testGet to a behavior-focused name mirroring the @DisplayName (no test prefix)
- Replaces imperative Mockito.mock + @BeforeEach with @ExtendWith(MockitoExtension.class) and @Mock/@InjectMocks
- Replaces Assertions.assertEquals with AssertJ assertThat

FAIL if any item is missing or contradicted.
