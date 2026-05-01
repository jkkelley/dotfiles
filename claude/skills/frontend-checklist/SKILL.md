---
name: frontend-checklist
description: Frontend development checklist covering performance, accessibility, component patterns, and browser compatibility. Preloaded into the frontend-guru agent.
---

# Frontend Checklist

## Performance (Core Web Vitals)

| Metric | Target | Measure |
|--------|--------|---------|
| LCP (Largest Contentful Paint) | < 2.5s | Largest visible element load time |
| INP (Interaction to Next Paint) | < 200ms | Response to user interaction |
| CLS (Cumulative Layout Shift) | < 0.1 | Unexpected layout movement |

**Quick wins:**
```html
<!-- Preload LCP image -->
<link rel="preload" href="/hero.webp" as="image" fetchpriority="high" />

<!-- Preload critical fonts -->
<link rel="preload" href="/fonts/brand.woff2" as="font" type="font/woff2" crossorigin />

<!-- Lazy load below-fold images -->
<img src="card.webp" loading="lazy" decoding="async" alt="..." />

<!-- Avoid layout shift: always set width/height -->
<img src="avatar.jpg" width="64" height="64" alt="..." />
```

```tsx
// Code split heavy components
const HeavyChart = lazy(() => import('./HeavyChart'))
<Suspense fallback={<ChartSkeleton />}><HeavyChart /></Suspense>

// Virtualize long lists
import { useVirtualizer } from '@tanstack/react-virtual'
```

## Accessibility (WCAG 2.1 AA)

**Semantic HTML first:**
```html
<!-- Navigation -->
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/" aria-current="page">Home</a></li>
  </ul>
</nav>

<!-- Buttons vs links -->
<button type="button" onclick="...">Action</button>   <!-- triggers action -->
<a href="/page">Navigation</a>                         <!-- goes somewhere -->

<!-- Form labels — always associated -->
<label for="email">Email address</label>
<input id="email" type="email" required autocomplete="email" />

<!-- Icons — accessible label -->
<button aria-label="Close dialog">
  <svg aria-hidden="true">...</svg>
</button>
```

**ARIA — only when HTML isn't enough:**
```html
<!-- Dynamic content announcements -->
<div role="status" aria-live="polite">3 results found</div>
<div role="alert" aria-live="assertive">Error: form submission failed</div>

<!-- Modal dialog -->
<dialog aria-labelledby="modal-title" aria-describedby="modal-desc">
  <h2 id="modal-title">Confirm Delete</h2>
  <p id="modal-desc">This cannot be undone.</p>
</dialog>

<!-- Custom widget state -->
<button aria-expanded="false" aria-controls="menu">Menu</button>
<ul id="menu" hidden>...</ul>
```

**Color contrast:**
- Normal text (< 18px): 4.5:1 minimum
- Large text (≥ 18px or 14px bold): 3:1 minimum
- UI components and icons: 3:1 minimum
- Don't rely on color alone to convey information

## Component Patterns

**Selector priority (best → worst):**
```tsx
// Best — explicit, decoupled from style
cy.get('[data-testid="submit"]')

// Good — accessibility-driven
screen.getByRole('button', { name: /submit/i })

// OK — semantic HTML
document.querySelector('form button[type="submit"]')

// Avoid — brittle
document.querySelector('.btn.btn-primary.mt-2')
```

**React anti-patterns to avoid:**
```tsx
// Don't: useEffect for derived state
const [fullName, setFullName] = useState('')
useEffect(() => {
  setFullName(`${firstName} ${lastName}`)
}, [firstName, lastName])

// Do: compute during render
const fullName = `${firstName} ${lastName}`

// Don't: mutation of state
state.items.push(newItem)  // won't trigger re-render

// Do: produce new reference
setState(prev => ({ ...prev, items: [...prev.items, newItem] }))

// Don't: index as key when list reorders
items.map((item, i) => <Item key={i} {...item} />)

// Do: stable unique ID
items.map(item => <Item key={item.id} {...item} />)
```

## CSS Patterns

```css
/* Fluid typography — no media queries needed */
h1 { font-size: clamp(1.75rem, 4vw + 1rem, 3rem); }

/* Intrinsically responsive grid */
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: clamp(1rem, 3vw, 2rem);
}

/* Container queries — component-level responsiveness */
.card-container { container-type: inline-size; }
@container (min-width: 400px) {
  .card { display: grid; grid-template-columns: auto 1fr; }
}

/* Always respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: oklch(15% 0.02 250);
    --color-text: oklch(92% 0.02 250);
  }
}
```

## State Management Decision Tree

```
Is state used by one component?
  → useState / useReducer

Is state shared across a few nearby components?
  → Lift up + prop drilling, or Context

Is state server data (fetched from API)?
  → TanStack Query (React Query)

Is state in the URL (bookmarkable)?
  → URL search params / router state

Is state global app state (complex, many consumers)?
  → Zustand (simple) | Jotai (atomic) | Redux Toolkit (team/complex)
```

## Pre-Ship Checklist

```
Performance
[ ] Lighthouse score ≥ 90 on mobile (throttled)
[ ] LCP image has fetchpriority="high" and preload
[ ] No render-blocking scripts (defer/async/module)
[ ] Bundle analyzed — no unexpected large deps
[ ] Images: WebP/AVIF format, width/height set, lazy loaded

Accessibility
[ ] Keyboard-only navigation works for all interactions
[ ] VoiceOver/NVDA tested on critical user flows
[ ] No color-only information (icons + labels)
[ ] axe DevTools: zero violations
[ ] Focus management correct for modals/drawers/toasts

Code Quality
[ ] TypeScript strict mode, zero any types
[ ] No console.log left in
[ ] No commented-out code
[ ] ESLint passing, Prettier formatted
[ ] useEffect cleanup functions in place

Browser / Device
[ ] Chrome, Firefox, Safari tested
[ ] Mobile (375px) and tablet (768px) viewport tested
[ ] Touch targets ≥ 44×44px
[ ] Tested with slow 3G (Chrome DevTools throttle)
```
