# WeLoveDevs Provider

Integrates WeLoveDevs (https://www.welovedevs.com) into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

WeLoveDevs is a public job board with **no API**, **no login wall**, and **no anti-bot
challenge**. There is therefore no SessionManager and no login rake task — both discovery
and fetch run unauthenticated.

## Files

- discovery_step.rb: Render the Algolia search listing with Playwright and collect offer URLs.
- fetch_step.rb: Fetch offer detail HTML with Playwright; validate it is a real offer.
- analyze_step.rb: Extract normalized fields, JSON-LD JobPosting first.
- enrich_step.rb: LLM enrichment for technologies, seniority, English level, hybrid days.
- parsers/salary.rb, parsers/contract.rb, parsers/location_mode.rb: per-field normalization.

## Runtime behavior

### Discovery

- Search URL: `https://www.welovedevs.com/app/jobs?query=<keyword>`.
- The listing is an Algolia InstantSearch app (index `public_jobs`) rendered client-side.
  It exposes **no per-offer detail links** — clicking a card only updates a `?jobId=` query
  param via client routing — so there is nothing to scrape from the DOM. Instead, Playwright
  renders the search page and we **capture the Algolia search responses** it fires, reading
  each hit's `seoAlias` (the canonical detail slug) to build `https://www.welovedevs.com/app/job/<slug>`
  URLs. Scrolling triggers the next Algolia page (infinite scroll), so discovery scrolls
  until no new hits arrive.
- `supports_work_mode_filter?` is `false`: a reliable remote/hybrid/on-site URL refinement
  could not be encoded, so discovery runs once per keyword and location is captured per-offer
  during analyze. Keyword filtering is Algolia relevance on `query`.

### Fetch

- Detail pages are server-rendered and always embed a JSON-LD JobPosting block, which is the
  marker of a valid offer.
- A missing JobPosting with nothing else loaded raises `Sourcing::OfferGoneError` (removed
  offer → disabled by FetchJob). A page that loads but has no JobPosting raises a loud error
  (possible selector drift).

### Analyze

Extraction precedence:

1. JSON-LD JobPosting (`title`, `hiringOrganization.name`, `jobLocation.address.addressLocality`,
   `baseSalary` MonetaryAmount, `jobLocationType`, `datePosted`, `description`).
2. Templated `<meta name="description">` text as a secondary signal — used to recover the
   precise contract (`employmentType` JSON-LD only carries coarse `FULL_TIME`/`PART_TIME`,
   so "... in Permanent contract" → `PERMANENT`) and remote granularity.

Normalizations:

- Contract: meta text first (permanent/CDI, freelance, fixed-term/CDD, internship/stage,
  apprenticeship/alternance, part-time, full-time), then JSON-LD `employmentType`.
- Salary: JSON-LD MonetaryAmount (yearly; MONTH ×12), whole-unit amounts per pipeline
  convention; text fallback for "Nk to Mk".
- Location mode, most-precise first: (1) the per-offer remote chip
  (`a[href*='/app/job-remote']`): "100% Teleworking" → remote, "Hybrid teleworking
  (N weekdays)" / "Regular remote work" → hybrid, "Occasional remote work" → on-site
  (occasional = predominantly office); generic "Remote IT jobs" links ignored. The chip is
  the only signal that separates occasional from hybrid — `remotePolicy` reports `hybrid`
  frequency for both. (2) `remotePolicy.frequency` from the embedded app state
  (`fullTime`→remote, `hybrid`→hybrid, `no`→on-site) — fills in on-site offers, which
  render no chip. (3) JSON-LD `jobLocationType=TELECOMMUTE` (full remote only). (4) meta
  text. Validated across the ingested corpus (365 offers).
- Description: JSON-LD `description`, scripts/styles removed, then `clean_attributes`.

### Enrich

- Mirrors the shared enrich contract; sets `hybrid_remote_days_min_per_week` only when
  `location_mode == "hybrid"`.

## Known limitations

- No work-mode filtering at discovery (see above).
- `posted_at` relies on JSON-LD `datePosted` (date only, no time).
- Detail pages are server-rendered, so fetch could be downgraded to plain HTTP later as a
  performance optimization; Playwright is used for parity and robustness.

## Verification commands

- bundle exec rspec spec/services/sourcing/providers/welovedevs/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/enrich_step_spec.rb

Manual probes (Playwright; set `HEADLESS=false` to watch):

```bash
bin/rails runner 'pp Sourcing::Providers::Welovedevs::DiscoveryStep.new.call(source: "welovedevs", keyword: "ruby", work_mode: nil, force: false)[:discovered_urls].first(10)'
bin/rails runner 'html = Sourcing::Providers::Welovedevs::FetchStep.new.call(url: "https://www.welovedevs.com/app/job/<slug>"); pp Sourcing::Providers::Welovedevs::AnalyzeStep.new.call(html_content: html)'
```
