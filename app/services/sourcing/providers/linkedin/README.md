# LinkedIn Provider

Integrates LinkedIn jobs into the sourcing pipeline:

```
DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob
```

This provider runs **logged out, over plain HTTP** against LinkedIn's public guest endpoints.
No authentication, no Playwright, no session storage. If LinkedIn ever locks these endpoints
behind auth, the failure surface is explicit (HTTP 403/429/404 raise loudly).

## Files

- `discovery_step.rb` — paginated HTTP GET against the guest search endpoint; extracts canonical job URLs.
- `fetch_step.rb` — single HTTP GET against the guest job-detail endpoint; returns the HTML fragment.
- `analyze_step.rb` — Nokogiri DOM extraction (LinkedIn does **not** expose JSON-LD JobPosting on guest pages).
- `parsers/posted_at.rb` — converts LinkedIn's relative `posted-time-ago` strings ("3 days ago") to ISO8601.
- `enrich_step.rb` — LLM inference for fields the guest HTML does not expose (location_mode, salary, etc.).

## Endpoints

| Step | Method | URL |
|---|---|---|
| Discovery | GET | `https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=&location=&f_WT=&start=` |
| Fetch | GET | `https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/<id>` |

Pagination: `start=0,10,20,…`, 10 results per page. `MAX_PAGES = 40` cap. No "end of results" signal —
deduplication happens in the base `DiscoveryStep` after each page.

Work-mode filter (`f_WT`): `1` = on-site, `2` = remote, `3` = hybrid. Wired to the pipeline's
`work_mode` input ("onsite"/"on-site"/"remote"/"hybrid").

## Extraction strategy (analyze)

LinkedIn guest pages expose stable, class-prefixed DOM. There is **no JSON-LD** to fall back to.

| Field | Selector | Notes |
|---|---|---|
| `title` | `h2.top-card-layout__title` | |
| `company` | `a.topcard__org-name-link` | |
| `city` | `span.topcard__flavor.topcard__flavor--bullet` | First comma-separated segment of "City, Region, Country" |
| `employment_type` | `li.description__job-criteria-item` where subheader = "Employment type" | Mapped onto `JobOffer::EMPLOYMENT_TYPES` |
| `posted_at` | `span.posted-time-ago__text` | Relative ("3 days ago") → ISO8601 via `Parsers::PostedAt` |
| `description_html` | `div.show-more-less-html__markup` | Sanitized via inherited `clean_attributes` (strip style/class) |
| `salary_*` | — | Not shown on guest pages → enrich |
| `location_mode` | — | Not shown on guest pages → enrich (from description text) |

## Failure modes

- `Sourcing::Providers::Linkedin::FetchContentError` — raised when fetch returns 404/410 (job removed),
  blank HTML, shell HTML, or HTML missing the `top-card-layout__title` marker (auth wall or selector drift).
- Generic `StandardError` raised on HTTP 403/429 (rate-limit / IP block) and other non-2xx responses.
- Discovery raises on non-2xx from the search endpoint.

These errors are intentionally loud: LinkedIn's guest endpoints are not contractually stable.
On selector drift, prefer fixing this provider over silent degradation.

## Verification

Targeted specs:

```bash
bundle exec rspec spec/services/sourcing/providers/linkedin/
```

Manual probe (no Rails boot needed):

```bash
# Discovery — search results HTML fragment
curl -A "Mozilla/5.0" \
  "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=backend&location=France&start=0" \
  | grep -oE 'urn:li:jobPosting:[0-9]+' | sort -u

# Fetch — single job HTML fragment
curl -A "Mozilla/5.0" \
  "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/<id>"
```

## Known limitations

- Salary is virtually never present on guest pages; it always goes to enrich.
- `posted_at` is approximated from relative strings ("3 months ago" → now − 90 days).
- Pagination has no natural end; relies on `MAX_PAGES` + dedup.
- LinkedIn may rate-limit or block IPs that hit guest endpoints heavily; back off the IP on 403/429.
- LinkedIn account flagging is a real risk for authenticated sessions; this provider deliberately
  avoids that surface by staying logged out.
