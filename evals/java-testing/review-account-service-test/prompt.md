---
tags: [java-testing]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this test class and fix everything that violates our conventions:

```java
@DisplayName("Account service tests")
class AccountServiceTest {
    AccountRepository repo;
    AccountService service;

    @BeforeEach
    void setup() {
        repo = Mockito.mock(AccountRepository.class);
        service = new AccountService(repo);
    }

    @Test
    void testGet() {
        Mockito.when(repo.find(1L)).thenReturn(new Account(1L, "alice"));
        Assertions.assertEquals("alice", service.get(1L).name());
    }
}
```
