# Tools & Setup Reference

## Python stack

### httpx + parsel (static sites)

```python
import httpx
from parsel import Selector

async with httpx.AsyncClient(
    headers=HEADERS,
    follow_redirects=True,
    timeout=httpx.Timeout(30.0),
    limits=httpx.Limits(max_connections=10, max_keepalive_connections=5),
) as client:
    r = await client.get("https://example.com/products")
    sel = Selector(r.text)
    for item in sel.css("div.product"):
        yield {
            "title": item.css("h2::text").get("").strip(),
            "price": item.css(".price::text").get("").strip(),
            "url":   item.css("a::attr(href)").get(),
        }
```

### curl_cffi (TLS-hardened sites)

```python
from curl_cffi.requests import AsyncSession

async with AsyncSession(impersonate="chrome124") as s:
    r = await s.get(url, headers=headers, proxies={"https": proxy_url})
    data = r.json()
```

### Playwright async (JS-rendered)

```python
from playwright.async_api import async_playwright

async with async_playwright() as p:
    browser = await p.chromium.launch(headless=True)
    ctx = await browser.new_context(
        user_agent="Mozilla/5.0 ...",
        viewport={"width": 1280, "height": 900},
        locale="en-US",
        proxy={"server": "http://proxy:8080", "username": "u", "password": "p"},
    )
    page = await ctx.new_page()

    # Intercept and block images/fonts (speed up)
    await page.route("**/*.{png,jpg,jpeg,gif,webp,woff,woff2}", lambda r: r.abort())

    await page.goto("https://example.com", wait_until="domcontentloaded")
    await page.wait_for_selector(".product-grid")

    html = await page.inner_html(".product-grid")
    await browser.close()
```

### Network interception — grab the API call instead of parsing HTML

```python
responses = []

async def capture(response):
    if "api/products" in response.url:
        responses.append(await response.json())

page.on("response", capture)
await page.goto("https://example.com/shop")
await page.wait_for_load_state("networkidle")
# responses now has the JSON payloads
```

### Scrapy spider template

```python
import scrapy

class ProductSpider(scrapy.Spider):
    name = "products"
    start_urls = ["https://example.com/products?page=1"]
    custom_settings = {
        "DOWNLOAD_DELAY": 2,
        "RANDOMIZE_DOWNLOAD_DELAY": True,
        "CONCURRENT_REQUESTS_PER_DOMAIN": 1,
        "AUTOTHROTTLE_ENABLED": True,
        "AUTOTHROTTLE_TARGET_CONCURRENCY": 1.0,
        "ROBOTSTXT_OBEY": True,
        "DEFAULT_REQUEST_HEADERS": HEADERS,
    }

    def parse(self, response):
        for product in response.css("div.product"):
            yield {
                "title": product.css("h2::text").get("").strip(),
                "price": product.css(".price::text").get("").strip(),
                "url":   response.urljoin(product.css("a::attr(href)").get()),
            }
        next_page = response.css("a.next-page::attr(href)").get()
        if next_page:
            yield response.follow(next_page, callback=self.parse)
```

`scrapy crawl products -o output.jsonl`

---

## JavaScript stack

### Crawlee (Playwright-backed, production-grade)

```typescript
import { PlaywrightCrawler, Dataset } from 'crawlee';

const crawler = new PlaywrightCrawler({
    maxConcurrency: 5,
    requestHandlerTimeoutSecs: 30,

    async requestHandler({ page, request, enqueueLinks }) {
        const title = await page.title();
        const items = await page.$$eval('.product', els =>
            els.map(el => ({
                title: el.querySelector('h2')?.textContent?.trim(),
                price: el.querySelector('.price')?.textContent?.trim(),
            }))
        );
        await Dataset.pushData(items);
        await enqueueLinks({ selector: 'a.next-page' });
    },
});

await crawler.run(['https://example.com/products']);
```

### Cheerio (static HTML, fast)

```typescript
import axios from 'axios';
import * as cheerio from 'cheerio';

const { data } = await axios.get(url, { headers: HEADERS });
const $ = cheerio.load(data);

$('div.product').each((_, el) => {
    console.log({
        title: $(el).find('h2').text().trim(),
        price: $(el).find('.price').text().trim(),
    });
});
```

---

## Go stack

### Colly (crawl framework)

```go
package main

import (
    "fmt"
    "github.com/gocolly/colly/v2"
)

func main() {
    c := colly.NewCollector(
        colly.AllowedDomains("example.com"),
        colly.Async(true),
    )
    c.Limit(&colly.LimitRule{
        DomainGlob:  "*",
        Parallelism: 2,
        Delay:       2 * time.Second,
        RandomDelay: 1 * time.Second,
    })

    c.OnHTML(".product", func(e *colly.HTMLElement) {
        fmt.Println(e.ChildText("h2"), e.ChildText(".price"))
    })

    c.OnHTML("a.next-page[href]", func(e *colly.HTMLElement) {
        e.Request.Visit(e.Attr("href"))
    })

    c.Visit("https://example.com/products")
    c.Wait()
}
```

---

## Output formats

| Format | When to use |
|---|---|
| JSONL | Streaming, large datasets, easy to append |
| Parquet | Analytics, columnar queries, compression |
| CSV | Simple tabular, Excel-compatible |
| SQLite | Relational, deduplication queries, local dev |
| PostgreSQL | Production, multi-consumer, full SQL |

### JSONL streaming output

```python
import json, pathlib

out = pathlib.Path("output.jsonl").open("a")

def save(record: dict):
    out.write(json.dumps(record, ensure_ascii=False) + "\n")
    out.flush()
```

### Deduplication with SQLite

```python
import sqlite3, hashlib, json

conn = sqlite3.connect("scrape.db")
conn.execute("CREATE TABLE IF NOT EXISTS seen (url_hash TEXT PRIMARY KEY)")
conn.execute("CREATE TABLE IF NOT EXISTS items (data TEXT)")

def is_seen(url: str) -> bool:
    h = hashlib.sha1(url.encode()).hexdigest()
    if conn.execute("SELECT 1 FROM seen WHERE url_hash=?", (h,)).fetchone():
        return True
    conn.execute("INSERT INTO seen VALUES (?)", (h,))
    conn.commit()
    return False

def save(item: dict):
    conn.execute("INSERT INTO items VALUES (?)", (json.dumps(item),))
    conn.commit()
```
