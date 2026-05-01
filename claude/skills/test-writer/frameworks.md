# Framework Setup Reference

## Python — pytest

```bash
pip install pytest pytest-cov
```

`pytest.ini` or `pyproject.toml`:
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=src --cov-report=term-missing"
```

---

## JavaScript — Jest

```bash
npm install --save-dev jest @types/jest
```

`jest.config.js`:
```js
module.exports = { testEnvironment: 'node', collectCoverage: true };
```

## TypeScript — Jest + ts-jest

```bash
npm install --save-dev jest ts-jest @types/jest
npx ts-jest config:init
```

## JavaScript/TypeScript — Vitest

```bash
npm install --save-dev vitest
```

`vite.config.ts`:
```ts
import { defineConfig } from 'vite';
export default defineConfig({ test: { coverage: { provider: 'v8' } } });
```

---

## Go — stdlib + testify

```bash
go get github.com/stretchr/testify
```

Run: `go test ./... -cover`

---

## Java — JUnit 5 (Maven)

```xml
<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <version>5.10.2</version>
  <scope>test</scope>
</dependency>
```

Mockito:
```xml
<dependency>
  <groupId>org.mockito</groupId>
  <artifactId>mockito-core</artifactId>
  <version>5.11.0</version>
  <scope>test</scope>
</dependency>
```

---

## Rust — built-in

No dependencies needed. Run: `cargo test`

For integration tests create `tests/<name>.rs` at crate root.

---

## Ruby — RSpec

```bash
gem install rspec
rspec --init
```

`.rspec`:
```
--format documentation
--color
```

---

## C# — xUnit

```bash
dotnet add package xunit
dotnet add package xunit.runner.visualstudio
dotnet add package Moq
```

---

## PHP — PHPUnit

```bash
composer require --dev phpunit/phpunit
```

`phpunit.xml`:
```xml
<phpunit bootstrap="vendor/autoload.php">
  <testsuites>
    <testsuite name="Tests"><directory>tests</directory></testsuite>
  </testsuites>
</phpunit>
```

---

## Bash — bats-core

```bash
npm install --save-dev bats   # or: brew install bats-core
```

Test file template:
```bash
#!/usr/bin/env bats

@test "description of what it does" {
  run my_command arg1
  [ "$status" -eq 0 ]
  [[ "$output" == *"expected"* ]]
}
```
