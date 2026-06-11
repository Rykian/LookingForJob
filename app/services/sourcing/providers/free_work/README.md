# Free-Work Provider

Integrates Free-Work (https://www.free-work.com) into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

Free-Work is the largest French IT job board (freelance + permanent). Its Nuxt front
consumes an API Platform backend whose endpoints are open — **no auth, no API key, no
anti-bot** — so both discovery and fetch are plain HTTP (Faraday), no Playwright, no
SessionManager, no login rake task. The API is undocumented and unofficial: shape drift
is detected by fail-loud validation in every step.

## Files

- discovery_step.rb: Faraday GET on `/api/job_postings` (hydra collection), paginate via `?page=N`.
- fetch_step.rb: Faraday GET on `/api/job_postings/<slug>`; store the raw JSON body.
- analyze_step.rb: map the stored JSON payload structurally — no HTML scraping.
- enrich_step.rb: LLM enrichment for technologies, seniority, languages, hybrid days.
- parsers/contract.rb, parsers/salary.rb, parsers/location_mode.rb: per-field normalization.

## Runtime behavior

### Discovery

- Endpoint: `GET https://www.free-work.com/api/job_postings?searchKeywords=<kw>&itemsPerPage=30&page=<N>`
  with `Accept: application/ld+json` (hydra collection).
- Keyword (`searchKeywords`) and work mode (`remoteMode=full|partial|none`, mapped from
  `remote|hybrid|on-site`) both filter server-side (verified live), so
  `supports_work_mode_filter?` is true.
- Pagination: `hydra:view["hydra:next"]` presence drives `has_next_page`; `MAX_PAGES`
  safety cap at 300 (~9000 offers).
- Offer URLs are the public detail pages
  `/fr/tech-it/<job.nameForContributionSlug>/job-mission/<slug>`; the category segment is
  cosmetic (fetch only uses the trailing slug) and falls back to a generic value when
  the API omits it.

### Fetch

- The slug after `/job-mission/` maps directly to `GET /api/job_postings/<slug>`
  (`Accept: application/json`); the raw JSON body is stored as the offer payload.
- HTTP 404 → `Sourcing::OfferGoneError` (offer removed; verified live with a bogus slug).
- Any payload without a non-blank `id` + `title`, or a non-JSON body, fails loudly
  (provider shape drift).

### Analyze

Fully structural from the stored API JSON (no JSON-LD — though the public detail pages
do carry a JSON-LD JobPosting, kept as a documented fallback if the API ever closes):

- title ← `title`; company ← `company.name`; city ← `location.locality`.
- employment_type ← `contracts[]` (live values: permanent, contractor, fixed-term,
  apprenticeship, internship). Offers can accept several types at once; the
  highest-priority one wins, PERMANENT first because the salary convention follows it.
  Unknown values map to nil, never silently mislabeled.
- salary ← `minAnnualSalary`/`maxAnnualSalary` (whole euros) + `currency`. The freelance
  daily-rate channel (`minDailySalary`/`maxDailySalary`) is on a different scale and is
  deliberately ignored to preserve the annual convention.
- location_mode ← `remoteMode` (`full→remote`, `partial→hybrid`, `none→on-site`, null→nil).
- posted_at ← `publishedAt` (fallback `createdAt`).
- description_html ← `description` + `candidateProfile` (requirements live there);
  `companyDescription` recruiter boilerplate is dropped; scripts/styles stripped and
  attributes cleaned via the inherited `clean_attributes`.

A malformed payload yields all-nil fields without raising — gone-offer detection is
FetchStep's responsibility.

### Enrich

LLM fills what the API does not carry reliably: primary/secondary technologies,
normalized seniority, offer language, required languages, hybrid remote days
(hybrid offers only). The API's `experienceLevel` field (junior/intermediate/senior/
expert) is not persisted by the pipeline contract, so seniority is inferred from the
description text.

## Known limitations

- The API is unofficial; Free-Work may change or close it. Every step fails loudly with
  context on shape drift, so breakage surfaces as actionable pipeline errors.
- Freelance daily rates are not captured (left nil) pending a daily-rate channel.
- `skills[]` exists in the payload but is usually empty; technologies come from enrich.

## Verification

```bash
bundle exec rspec spec/services/sourcing/providers/free_work
```

Manual probes:

```bash
# Discovery (keyword + work mode filter)
bin/rails runner 'pp Sourcing::Providers::FreeWork::DiscoveryStep.new.crawl_page(input: { keyword: "ruby", work_mode: "hybrid" }, runtime: {}, page: 1)'

# Fetch + analyze a real offer
bin/rails runner 'url = "<public offer url>"; pp Sourcing::Providers::FreeWork::AnalyzeStep.new.call(html_content: Sourcing::Providers::FreeWork::FetchStep.new.call(url: url))'
```
