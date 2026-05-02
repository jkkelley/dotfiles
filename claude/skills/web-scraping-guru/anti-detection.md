# Anti-Detection Deep Dive

## Cloudflare

### Challenge types and how to beat them

| Challenge type | What it does | Solution |
|---|---|---|
| JS Challenge (old) | Evaluates JS, sets `cf_clearance` cookie | Playwright one-shot → extract cookie |
| Managed Challenge | Invisible ML scoring | `patchright` or `camoufox` + residential proxy |
| Turnstile (widget) | CAPTCHA widget in page | CAPTCHA service (CapSolver, NopeCHA) |
| Bot Fight Mode | Aggressive fingerprinting | Residential proxy + real Chrome channel |
| WAF block (1020) | IP/ASN reputation | Rotate to residential, warm session |

### Cloudflare cookie harvest pattern

```python
from patchright.async_api import async_playwright
import httpx

async def get_cf_clearance(url: str) -> dict:
    async with async_playwright() as p:
        ctx = await p.chromium.launch_persistent_context(
            user_data_dir="/tmp/cf-profile",
            channel="chrome",
            headless=False,   # headless often fails CF Managed Challenge
            args=["--disable-blink-features=AutomationControlled"],
        )
        page = await ctx.new_page()
        await page.goto(url, wait_until="networkidle")
        await page.wait_for_timeout(3000)
        cookies = {c["name"]: c["value"] for c in await ctx.cookies()}
        await ctx.close()
        return cookies

# Reuse in httpx for all subsequent requests
cookies = await get_cf_clearance("https://target.com")
async with httpx.AsyncClient(cookies=cookies, ...) as client:
    r = await client.get("https://target.com/api/data")
```

### Cloudflare + curl_cffi (no JS challenge, just TLS/H2)

```python
from curl_cffi.requests import AsyncSession

async with AsyncSession(impersonate="chrome124") as s:
    r = await s.get("https://target.com", headers=headers)
```

---

## DataDome

- Heavy ML behavioral scoring — click patterns, mouse entropy, typing cadence.
- Fingerprints: canvas hash, WebGL vendor, font enumeration, timing APIs.
- Residential proxy is mandatory; datacenter IPs instant-blocked.
- Playwright with `playwright-stealth` + 3–5s human-like delay between actions.
- CAPTCHA service integration required when challenge is served.

```python
# Playwright stealth (JS ecosystem)
from playwright_stealth import stealth_async
page = await browser.new_page()
await stealth_async(page)
```

---

## PerimeterX / HUMAN

- Similar to DataDome but heavier on timing analysis.
- Warmup matters: visit the homepage, scroll, hover over elements, then navigate to target.
- Mobile user agents + mobile viewport sometimes bypasses desktop-targeted detection.
- Rotate full browser profiles (user data dirs), not just cookies.

---

## CAPTCHA solving services

| Service | Best for | Notes |
|---|---|---|
| **CapSolver** | reCAPTCHA v2/v3, Turnstile, FunCAPTCHA | Fastest, cheapest |
| **2captcha** | Wide support, good API | Slower workers |
| **NopeCHA** | Turnstile, hCaptcha | Good Cloudflare support |
| **AntiCaptcha** | reCAPTCHA enterprise | Solid reliability |

```python
import capsolver

capsolver.api_key = "YOUR_KEY"

solution = capsolver.solve({
    "type": "ReCaptchaV2Task",     # or TurnstileTask, HCaptchaTask
    "websiteURL": "https://target.com",
    "websiteKey": "6Le...",
    "proxyType": "http",
    "proxyAddress": "proxy.example.com",
    "proxyPort": 8080,
    "proxyLogin": "user",
    "proxyPassword": "pass",
})
token = solution["gRecaptchaResponse"]
```

Finding the `websiteKey`: in page source, search for `sitekey` or `data-sitekey`.

---

## Proxy strategy

### Proxy type comparison

| Type | Detection risk | Speed | Cost | Use case |
|---|---|---|---|---|
| Datacenter | High | Fast | Cheap | Non-protected sites, internal tools |
| Residential | Low | Medium | Expensive | Cloudflare, DataDome, e-commerce |
| Mobile (4G/5G) | Very low | Slow | Very expensive | Maximum stealth, finance/travel |
| ISP (static residential) | Low | Fast | Medium | Best balance |

### Providers (as of 2025–2026)
- **Oxylabs** — large pool, reliable, expensive
- **Bright Data** — most features, complex pricing
- **Smartproxy** — good balance of cost/quality
- **IPRoyal** — budget residential
- **Webshare** — datacenter, great for dev/testing

### Proxy rotation patterns

```python
import itertools, random

proxies = [
    "http://user:pass@residential1.proxy.com:8080",
    "http://user:pass@residential2.proxy.com:8080",
]

# Round-robin
proxy_cycle = itertools.cycle(proxies)

# Sticky per domain (same IP for session consistency)
domain_proxy: dict[str, str] = {}
def get_proxy(domain: str) -> str:
    if domain not in domain_proxy:
        domain_proxy[domain] = random.choice(proxies)
    return domain_proxy[domain]
```

### Backconnect proxies (rotating gateway)

Single endpoint that rotates IPs automatically:
```
http://user:pass@gate.brightdata.com:22225
```
Good for fire-and-forget; bad for session consistency (add `session=SESSION_ID` param to stick).

---

## Browser profile management

Reusing profiles avoids re-solving challenges and builds "trust history".

```
profiles/
├── profile-001/   ← user data dir for Playwright
├── profile-002/
└── profile-003/
```

```python
import random, pathlib

PROFILES = list(pathlib.Path("profiles").iterdir())

async def get_browser():
    profile = random.choice(PROFILES)
    ctx = await p.chromium.launch_persistent_context(
        user_data_dir=str(profile),
        channel="chrome",
        viewport={"width": 1280, "height": 900},
        locale="en-US",
        timezone_id="America/New_York",
    )
    return ctx
```

Match timezone, locale, and proxy geolocation — a US locale with a German IP is a detection signal.

---

## Fingerprint consistency checklist

When using a headless browser, verify these all match:

- [ ] IP geolocation matches `navigator.language` and `Intl.DateTimeFormat().resolvedOptions().timeZone`
- [ ] Screen resolution is realistic (not 0x0 or 800x600)
- [ ] `navigator.hardwareConcurrency` > 1
- [ ] `navigator.webdriver` is `undefined` (not `true`)
- [ ] `window.chrome.runtime` exists
- [ ] Canvas fingerprint is non-trivial and consistent across requests
- [ ] WebGL vendor/renderer is a real GPU string
- [ ] Plugin list is non-empty (Chrome has built-in PDF viewer etc.)
- [ ] Font list matches expected OS fonts

Test your fingerprint at: `abrahamjuliot.github.io/creepjs` or `bot.sannysoft.com`
