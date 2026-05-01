---
name: test-writer
description: Write test suites for any programming language by analyzing code structure, public API surface, side effects, and edge cases. Use when the user asks to write tests, generate test cases, add unit or integration tests, improve test coverage, or says "write me a test" for code in any language (Python, JavaScript, TypeScript, Go, Java, Rust, Ruby, C#, PHP, Bash, and more).
---

# Test Writer

## Workflow

1. **Read the source** — read every file the user provides or that's relevant to the code under test.
2. **Identify what to test** — public functions/methods/endpoints, side effects, error paths, and non-obvious behaviors.
3. **Detect language and framework** — see the table below; default to the first listed framework unless the project already uses another.
4. **Write the tests** — cover happy path, edge cases, error/exception paths, and boundary values.
5. **Place the file correctly** — follow the convention for that language (co-located, `__tests__/`, `_test.go`, etc.).

---

## Framework defaults by language

| Language | Default framework | Alternatives |
|---|---|---|
| Python | `pytest` | `unittest` |
| JavaScript | `Jest` | `Vitest`, `Mocha + Chai` |
| TypeScript | `Jest` + `ts-jest` | `Vitest` |
| Go | `testing` (stdlib) | `testify` |
| Java | `JUnit 5` | `TestNG` |
| Kotlin | `JUnit 5` + `kotlin.test` | `Kotest` |
| Rust | built-in `#[test]` | — |
| Ruby | `RSpec` | `minitest` |
| C# | `xUnit` | `NUnit`, `MSTest` |
| PHP | `PHPUnit` | — |
| Bash | `bats-core` | — |
| Swift | `XCTest` | `Swift Testing` |

If the project has an existing test framework (check `package.json`, `Cargo.toml`, `pom.xml`, `Gemfile`, etc.), always match it.

---

## Test structure

For each unit or function write:

```
describe/class: <thing under test>
  - <happy path: expected behavior>
  - <edge case: empty input, zero, nil, empty string, etc.>
  - <error case: invalid input, throws/panics/returns error>
  - <boundary: max/min values, concurrent calls if relevant>
```

For HTTP handlers or service layers, also add:
- Mock external dependencies (DB, network, filesystem)
- Assert status codes and response shapes, not just "no error"

---

## Language-specific conventions

**Python (pytest)**
- File: `test_<module>.py` or `tests/<module>/test_<file>.py`
- Use `pytest.raises` for exceptions, `monkeypatch` for patches, `@pytest.fixture` for shared setup.

**JavaScript/TypeScript (Jest)**
- File: `__tests__/<module>.test.ts` or co-located `<module>.test.ts`
- Use `jest.fn()` / `jest.spyOn()` for mocks; `beforeEach`/`afterEach` for lifecycle.

**Go**
- File: `<package>_test.go` in same package (white-box) or `<package>_test` package (black-box)
- Use `t.Errorf` / `t.Fatalf`; `testify/assert` for readable assertions; table-driven tests with `t.Run`.

**Java (JUnit 5)**
- File: `src/test/java/.../<Class>Test.java`
- Use `@Test`, `@BeforeEach`, `@ParameterizedTest`; Mockito for mocks.

**Rust**
- Tests in same file under `#[cfg(test)] mod tests { ... }` for unit; separate `tests/` for integration.
- Use `#[test]`, `assert_eq!`, `#[should_panic]`.

**Ruby (RSpec)**
- File: `spec/<module>_spec.rb`
- Use `describe`, `context`, `it`, `let`, `before`; `allow(...).to receive` for stubs.

---

## Output format

- Write complete, runnable test files — no pseudocode, no placeholders.
- Add a one-line comment above each test group explaining *why* it matters, not *what* it does.
- If mocks/fixtures are needed, include them in the same file or a companion `fixtures/` file.
- After writing, list any untested behaviors and briefly explain why (e.g., "network timeout path skipped — requires integration setup").

---

## For additional reference
- See [frameworks.md](frameworks.md) for install commands and config snippets per framework.
