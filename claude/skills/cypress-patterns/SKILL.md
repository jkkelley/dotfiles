---
name: cypress-patterns
description: Cypress command reference, selector patterns, flaky test fixes, and CI configuration. Preloaded into the cypress-tester agent.
---

# Cypress Patterns

## Selector Priority (best → worst)

```js
// 1. data-testid — stable, decoupled, explicit
cy.get('[data-testid="submit-button"]')

// 2. ARIA role + name — accessibility-driven
cy.findByRole('button', { name: /submit order/i })      // @testing-library/cypress
cy.findByLabelText('Email address')
cy.findByPlaceholderText('Search...')

// 3. Semantic HTML
cy.get('form').find('input[name="email"]')
cy.get('nav a[href="/dashboard"]')

// Never — breaks on refactor
cy.get('.btn.btn-primary.mt-2')
cy.get('#root > div > div:nth-child(3)')
```

## Core Command Patterns

```js
// Assertions — chain them
cy.get('[data-testid="card"]')
  .should('be.visible')
  .and('contain.text', 'Order #1234')
  .and('not.have.class', 'loading')

// Wait for element with custom timeout
cy.get('[data-testid="notification"]', { timeout: 10000 })
  .should('be.visible')

// Text content
cy.get('[data-testid="count"]').should('have.text', '42')
cy.get('[data-testid="msg"]').should('contain.text', 'Success')

// Form interaction
cy.get('input[name="email"]').clear().type('alice@example.com')
cy.get('select[name="role"]').select('admin')
cy.get('input[type="checkbox"]').check()

// Wait for intercept before acting
cy.intercept('GET', '/api/users').as('getUsers')
cy.visit('/users')
cy.wait('@getUsers')
cy.get('[data-testid="user-list"]').should('be.visible')
```

## Intercept Patterns

```js
// Stub full response
cy.intercept('GET', '/api/users', { fixture: 'users.json' }).as('getUsers')

// Dynamic stub
cy.intercept('POST', '/api/orders', (req) => {
  req.reply({ statusCode: 201, body: { id: 'order-123' } })
}).as('createOrder')

// Simulate error
cy.intercept('GET', '/api/profile', { statusCode: 500 }).as('profileError')

// Spy without stubbing (real request)
cy.intercept('POST', '/api/events').as('trackEvent')

// Assert on request/response
cy.wait('@createOrder').then(({ request, response }) => {
  expect(request.body.amount).to.equal(5000)
  expect(response.statusCode).to.equal(201)
})

// URL pattern matching
cy.intercept('GET', '/api/users/*').as('getUser')
cy.intercept('GET', '/api/search?q=*').as('search')
```

## cy.session() Login Pattern

```js
// commands.js
Cypress.Commands.add('login', (email = 'alice@example.com', password = 'pass123') => {
  cy.session(
    [email, password],
    () => {
      cy.request('POST', '/api/auth/login', { email, password })
        .then(({ body }) => {
          window.localStorage.setItem('auth_token', body.token)
        })
    },
    {
      validate: () => {
        cy.request({ url: '/api/me', failOnStatusCode: false })
          .its('status').should('eq', 200)
      },
      cacheAcrossSets: true,
    }
  )
})

// In tests — session restored from cache (fast!)
beforeEach(() => {
  cy.login()
  cy.visit('/dashboard')
})
```

## Custom Commands

```js
// cypress/support/commands.js
Cypress.Commands.add('getByTestId', (id, options = {}) =>
  cy.get(`[data-testid="${id}"]`, options)
)

Cypress.Commands.add('typeInto', (selector, value) =>
  cy.get(selector).clear().type(value)
)

Cypress.Commands.add('selectOption', (selector, value) =>
  cy.get(selector).select(value)
)

// Usage
cy.getByTestId('email-input').type('alice@example.com')
cy.typeInto('[name="search"]', 'terraform')
```

## Flaky Test Diagnosis & Fixes

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| `cy.get()` timeout | Element not in DOM yet | Intercept + `cy.wait('@alias')` before asserting |
| Passes locally, fails CI | Timing / slower machine | Increase `defaultCommandTimeout` or use deterministic waits |
| Intermittent wrong element | Race on async state update | Assert loading indicator gone before asserting content |
| `cy.type()` types in wrong field | Focus not set | Add `.click()` before `.type()` |
| Session not restored | Validate callback failing | Debug validate; check cookie/localStorage actually set |
| Screenshot shows blank page | App not started | Increase `wait-on-timeout` in CI, check `baseUrl` |

```js
// WRONG — hardcoded wait
cy.wait(3000)
cy.get('[data-testid="result"]').should('contain', 'Done')

// RIGHT — wait for network request to complete
cy.intercept('POST', '/api/process').as('process')
cy.get('[data-testid="start"]').click()
cy.wait('@process')
cy.get('[data-testid="result"]').should('contain', 'Done')

// RIGHT — wait for loading state to clear
cy.get('[data-testid="start"]').click()
cy.get('[data-testid="spinner"]').should('not.exist')
cy.get('[data-testid="result"]').should('contain', 'Done')
```

## Page Object Model

```js
// cypress/pages/LoginPage.js
export class LoginPage {
  visit()              { cy.visit('/login'); return this }
  fillEmail(v)         { cy.getByTestId('email').clear().type(v); return this }
  fillPassword(v)      { cy.getByTestId('password').clear().type(v); return this }
  submit()             { cy.getByTestId('login-btn').click(); return this }
  assertError(msg)     { cy.getByTestId('error').should('contain.text', msg); return this }
  assertLoggedIn()     { cy.url().should('include', '/dashboard'); return this }
}

// In test
import { LoginPage } from '../pages/LoginPage'
const login = new LoginPage()

it('rejects invalid credentials', () => {
  login.visit().fillEmail('bad@example.com').fillPassword('wrong').submit()
      .assertError('Invalid credentials')
})
```

## CI Configuration

```yaml
# .github/workflows/e2e.yml
- uses: cypress-io/github-action@v6
  with:
    build: npm run build
    start: npm run start:ci
    wait-on: 'http://localhost:3000'
    wait-on-timeout: 60
    browser: chrome
    record: true
    parallel: true
    group: 'E2E'
  env:
    CYPRESS_RECORD_KEY: ${{ secrets.CYPRESS_RECORD_KEY }}
```

```js
// cypress.config.js
export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3000',
    defaultCommandTimeout: 6000,
    retries: { runMode: 2, openMode: 0 },
    video: false,
    screenshotOnRunFailure: true,
    experimentalMemoryManagement: true,
    numTestsKeptInMemory: 1,
  },
})
```

## Anti-Patterns

```
❌ cy.wait(2000) — use intercept aliases + cy.wait('@alias')
❌ .btn-primary selector — use data-testid
❌ No beforeEach cleanup — tests leak state to each other
❌ cy.login() via UI every test — use cy.session() + cy.request()
❌ Testing third-party services — mock/stub external deps
❌ index as list key in React + cy.get('.item').eq(2) — order-dependent, fragile
❌ Skipped tests left in codebase — fix or delete
❌ it.only() committed — blocks all other tests in CI
```
