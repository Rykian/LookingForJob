# WTTJ Provider

Welcome to the Jungle (WTTJ) integration for the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Combined sitemap (always) + jobs-matches (when session is present).
- fetch_step.rb: Fetch WTTJ offer HTML via Playwright with optional stored session.
- analyze_step.rb: Extract normalized fields from JSON-LD, `__INITIAL_DATA__`, and DOM fallbacks.
- enrich_step.rb: LLM enrichment for missing structured fields.
- session_manager.rb: Stores Playwright `storageState` for AWS-WAF-protected pages.

## Runtime behavior

### Discovery

WTTJ added AWS WAF on CloudFront, which blocks every headless request to frontend
page routes. Discovery therefore avoids the search page entirely and combines two
sources:

1. **Public sitemaps** (always): `https://www.welcometothejungle.com/sitemaps/job-listings.{0..10}.xml.gz`.
   Filters: `/fr/companies/` URL prefix, `lastmod` within `input[:days]` (default 14),
   optional `input[:keyword]` slug match. No Playwright, no session needed.
2. **`/fr/jobs-matches`** (only when `SessionManager.exists?`): personalized matches
   for the logged-in WTTJ profile. Uses Playwright with the stored session.

`work_mode` filtering is **not** supported (sitemap has no metadata; downstream
enrich/score handles relevance).

### Fetch

- Loads session via `SessionManager.load_if_exists` and passes it as `storage_state`
  to Playwright. With a valid `aws-waf-token` cookie the WAF challenge is bypassed.
- Detects WAF challenge / rate-limit pages and raises with guidance to re-run
  `bin/rails wttj:login` or slow down the crawl.
- Applies jittered per-request throttling (2–4s) to reduce WAF triggers. Fetches
  are serialized (Sidekiq concurrency=1 per provider) like LinkedIn.

### Analyze

Detects disabled offers (returns `disabled: true`) when the page shows WTTJ's
"Cette offre n'est plus disponible" banner (offer taken down or expired).
The pipeline flags these and skips further enrichment.

Extraction priority:
1. **JSON-LD** (`script[type='application/ld+json']` with `@type == "JobPosting"`) —
   Next.js emits this for SEO. Primary, most reliable source.
2. **`window.__INITIAL_DATA__`** (legacy React Query cache, may still be present).
3. **DOM selectors** — last-resort fallbacks for `h1`/contract/salary/location.

### Enrich

Strips description HTML to plain text and asks the LLM for missing structured fields.

## Session setup

WTTJ pages are gated by AWS WAF (CloudFront). Headless browsers are fingerprinted
and rejected with an HTTP 202 + `x-amzn-waf-action: challenge`.

Harvest a session from a real Chrome:

```bash
bin/rails wttj:login
```

The task prints instructions: launch Chrome with `--remote-debugging-port=9222`,
visit `https://www.welcometothejungle.com/fr/jobs-matches` (pass any WAF challenge,
sign in), then press Enter to harvest cookies into `data/wttj_session.json`.

The critical cookie is `aws-waf-token` (AWS WAF bypass token).

## Verification commands

- bundle exec rspec spec/services/sourcing/providers/wttj/
- bin/rails runner "pp Sourcing::Providers::Wttj::DiscoveryStep.new.call(keyword: 'rails', days: 7)"
- bin/rails runner "pp Sourcing::Providers::Wttj::FetchStep.new.call(url: '<url-from-discovery>')"

## Notes

- AWS WAF token expiry depends on WTTJ's challenge immunity configuration. If
  sessions expire mid-run, re-run `bin/rails wttj:login`.
- Sitemap is regenerated daily (`changefreq: daily`); jobs posted in the last few
  hours may not appear until the next regeneration.
