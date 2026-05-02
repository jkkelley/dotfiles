---
name: web-scraping-guru
description: Expert web scraping advisor covering the full stack — HTTP clients, HTML parsing, headless browsers, anti-bot evasion, proxy strategy, TLS fingerprinting, CAPTCHA handling, pagination, infinite scroll, hidden API discovery, distributed crawling, and data normalization. Use when scraping any website, dealing with bot detection, choosing between a plain HTTP client vs headless browser, handling rate limits or bans, extracting data from JS-rendered pages, reverse-engineering undocumented APIs, or building a scraper that needs to survive long-term.
---

# Web Scraping Guru

## First decision: do you actually need a browser?

Most scrapers start with Playwright when they should start with `requests`. Always try the cheapest tool first.

```
Static HTML (server-rendered)?  → HTTP client + HTML parser
API calls visible in DevTools?  → Call the API directly (JSON, no parsing)
JS-rendered, no visible API?    → Headless browser
Behind login/CAPTCHA/heavy bot? → Headless browser + anti-detect stack
```

Finding the hidden API is almost always faster than scraping rendered HTML. Open DevTools → Network → XHR/Fetch → reload the page. Look for JSON responses. Copy as cURL. Done.

---

## Tool selection by language

| Need | Python | JavaScript | Go |
|---|---|---|---|
| HTTP client | `httpx` (async) / `requests` | `axios` / `got` | `net/http` / `resty` |
| HTML parsing | `lxml` + `cssselect`, `parsel` | `cheerio` | `goquery` |
| Full browser | `playwright-python` | `playwright` / `puppeteer` | `chromedp` |
| Anti-detect browser | `playwright` + `patchright` or `camoufox` | `rebrowser-patches` / `puppeteer-extra-stealth` | — |
| Crawl framework | `scrapy` | `crawlee` | `colly` |
| CAPTCHA solve | `2captcha`, `capsolver`, `nopecha` | same APIs | same APIs |

**Defaults**: `httpx` + `parsel` for static; `playwright` + stealth for dynamic; `scrapy` for large-scale crawls.

---

## HTTP client fundamentals

### Headers that matter

Every request needs a believable header set. Missing or bot-ordered headers get you flagged fast.

```python
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://www.google.com/",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "cross-site",
    "Upgrade-Insecure-Requests": "1",
}
```

Header order matters — `httpx` preserves insertion order, `requests` does not. Use `httpx`.

### TLS fingerprinting (JA3/JA3S)

Python's `requests` uses a distinctive TLS handshake. Cloudflare, Akamai, and DataDome fingerprint it.

Solutions ranked by effectiveness:
1. **`curl_cffi`** — impersonates Chrome/Firefox TLS at the C level. Best drop-in replacement.
2. **`tls-client`** — similar, Go-backed.
3. **Playwright** — real Chrome, real TLS.

```python
from curl_cffi import requests
resp = requests.get(url, impersonate="chrome124", headers=headers)
```

---

## Anti-bot evasion layers

Think of detection as layers — you need to beat all of them, not just one.

### Layer 1: IP reputation
- Datacenter IPs (AWS, GCP, DigitalOcean) are flagged immediately on serious targets.
- Residential proxies > mobile proxies > datacenter. Cost scales the same way.
- Rotate proxies per domain, not per request — session consistency matters.
- Sticky sessions for sites that use IP-bound cookies.

### Layer 2: TLS fingerprint
- Use `curl_cffi` or a real browser. Never raw `requests` on hardened targets.

### Layer 3: HTTP/2 fingerprinting (AKAMAI H2)
- Header frame order, SETTINGS frame values, WINDOW_UPDATE — all fingerprinted.
- `curl_cffi` handles this. Raw `httpx` does not.

### Layer 4: Browser fingerprint (JS challenges)
- Headless Chrome is detectable via: `navigator.webdriver`, missing plugins, wrong screen dimensions, `chrome.runtime` being undefined, Canvas/WebGL hash.
- Fix with **`playwright-stealth`** (JS) or **`patchright`** / **`camoufox`** (Python). Never roll your own stealth patches — they go stale.

```python
from patchright.async_api import async_playwright

async with async_playwright() as p:
    browser = await p.chromium.launch_persistent_context(
        user_data_dir="/tmp/profile",
        channel="chrome",   # use real installed Chrome, not bundled Chromium
    )
```

### Layer 5: Behavioral signals
- Mouse moves, scroll events, time-on-page — ML models watch these.
- Randomize delays: `time.sleep(random.uniform(1.5, 4.0))` between requests.
- Don't request at fixed intervals. Add jitter.
- Warm up sessions: visit homepage, wait, follow a link, then target.

### Layer 6: Cookie / token freshness
- Some anti-bots (Cloudflare Challenge) set a `cf_clearance` cookie after JS evaluation.
- Solve once with Playwright, extract cookie, reuse in httpx session for subsequent requests.

---

## Pagination patterns

```python
# Offset pagination
page = 1
while True:
    r = session.get(url, params={"page": page, "per_page": 100})
    items = r.json()["items"]
    if not items:
        break
    yield from items
    page += 1

# Cursor pagination
cursor = None
while True:
    params = {"cursor": cursor} if cursor else {}
    r = session.get(url, params=params).json()
    yield from r["data"]
    cursor = r.get("next_cursor")
    if not cursor:
        break

# Infinite scroll (browser)
while True:
    prev_count = await page.locator(".item").count()
    await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
    await page.wait_for_timeout(2000)
    new_count = await page.locator(".item").count()
    if new_count == prev_count:
        break
```

---

## Data extraction

### CSS selectors vs XPath

- CSS: simpler, faster, use for most cases.
- XPath: use when you need text contains, parent traversal, or `following-sibling`.

```python
from parsel import Selector

sel = Selector(html)
# CSS
titles = sel.css("h2.product-title::text").getall()
# XPath — text contains
price = sel.xpath("//span[contains(@class,'price')]/text()").get()
# XPath — parent traversal
label = sel.xpath("//input[@id='email']/../../label/text()").get()
```

### Resilient selectors — ranked by stability

1. `data-testid`, `data-id`, `id` attributes — most stable
2. ARIA roles: `[role="button"]`, `[aria-label="Add to cart"]`
3. Structured class names (BEM)
4. Generic class names (`.btn`, `.title`) — fragile
5. Position-based (`nth-child(3)`) — most fragile, breaks on layout change

---

## Rate limiting and retries

```python
import httpx, time, random
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

@retry(
    retry=retry_if_exception_type((httpx.HTTPStatusError, httpx.TransportError)),
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=2, max=30),
)
async def fetch(client, url):
    r = await client.get(url)
    if r.status_code == 429:
        retry_after = int(r.headers.get("Retry-After", 10))
        time.sleep(retry_after + random.uniform(0, 3))
        r.raise_for_status()
    r.raise_for_status()
    return r
```

429 = slow down. 403 = blocked (rotate proxy/fingerprint). 503 = Cloudflare challenge.

---

## Distributed crawling

For large-scale work (millions of URLs):

1. **Deduplication** — Bloom filter or Redis SET for seen URLs. `scrapy-redis` for distributed Scrapy.
2. **Frontier management** — priority queue (score by freshness, depth, domain).
3. **Politeness** — one concurrent request per domain max, respect `Crawl-delay` in robots.txt.
4. **Checkpointing** — store progress in Redis/DB so crashes don't restart from zero.
5. **Output** — stream to S3/GCS as JSONL, partition by date+domain for easy querying.

Scrapy with `scrapy-redis` handles most of this. For custom needs: Celery + Redis queue + httpx workers.

---

## Legal and ethical guardrails

- Check `robots.txt` — disallowed paths can be a ToS violation (and sometimes a legal issue).
- Scraping publicly available data for personal/research use is generally fine; reselling it may not be.
- Don't scrape PII (emails, names, addresses) without a clear legal basis (GDPR/CCPA).
- Identify yourself in User-Agent for non-hostile scraping: `MyBot/1.0 (+https://mysite.com/bot)`.
- Rate limit by default — be a polite citizen.

---

## Additional reference
- See [anti-detection.md](anti-detection.md) for deep dives: Cloudflare bypass, DataDome, PerimeterX, CAPTCHA solving, proxy provider comparison, browser profile management.
- See [tools.md](tools.md) for full setup snippets, Scrapy spider templates, Playwright async patterns, and `curl_cffi` session reuse.
