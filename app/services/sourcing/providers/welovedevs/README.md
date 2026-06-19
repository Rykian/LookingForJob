# WeLoveDevs Provider

Integrates WeLoveDevs (https://www.welovedevs.com) into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

WeLoveDevs is a client-side Algolia InstantSearch app with **no login wall** and **no
anti-bot challenge**. Its public Algolia `public_jobs` index is open — the application id
and search-only API key are embedded verbatim in the site bundle — so the whole provider
runs as **plain HTTP (Faraday), with no Playwright**. There is no SessionManager and no
login rake task.

## Files

- algolia_client.rb: Faraday client over the Algolia `public_jobs` index (`search`, `get_object`).
- discovery_step.rb: Paginate the Algolia search endpoint and build `?jobId=<objectID>` URLs.
- fetch_step.rb: Resolve the URL's `jobId` to one Algolia get-object call; store the raw JSON.
- analyze_step.rb: Extract normalized fields structurally from the stored object.
- enrich_step.rb: LLM enrichment for technologies, seniority, language, hybrid days.
- parsers/salary.rb, parsers/contract.rb, parsers/location_mode.rb: per-field normalization.

## Runtime behavior

A WeLoveDevs Algolia hit carries the **entire offer** (title, `smallCompany.companyName`,
`details.salary`, `contractTypes`, `details.remotePolicy`, `formattedPlaces`, markdown
`mdDescription`). The detail page (`/app/jobs?jobId=<objectID>`) is a client-side modal over
the listing and fires no job-data XHR — there is nothing to scrape — so fetch reads the
object directly from Algolia instead of rendering a page.

### Discovery

- Queries `POST https://<appId>-dsn.algolia.net/1/indexes/*/queries` with
  `{indexName: "public_jobs", params: "query=<keyword>&hitsPerPage=100&page=N"}`, paginating
  while `page+1 < nbPages` (Algolia pages are 0-indexed; the pipeline loop is 1-indexed).
- Builds canonical `https://www.welovedevs.com/app/jobs?jobId=<objectID>` URLs (the objectID
  is URL-encoded — it commonly contains `+`, e.g. `greenhouse+5967999002`).
- Only `type == "company_job"` hits are kept; `spontaneous_application` cards have no offer.
- `supports_work_mode_filter?` is `false`: no stable Algolia facet refinement for
  remote/hybrid/on-site was wired, so discovery runs once per keyword and location_mode is
  captured per-offer during analyze. Keyword filtering is Algolia relevance on `query`.

### Fetch

- Decodes `jobId` from the URL and calls `GET /1/indexes/public_jobs/<objectID>`; the raw JSON
  body is stored as the offer payload.
- HTTP 404 raises `Sourcing::OfferGoneError` (removed offer → disabled by FetchJob).
- Legacy `/app/job/<seoAlias>` URLs from the previous Playwright implementation carry no
  `jobId` and no longer resolve on the site; they are retired as `OfferGoneError`.
- A payload missing `objectID`/`title`, or non-JSON, fails loudly (index shape drift).

### Analyze

Fully structural from the stored Algolia object — no HTML scraping, no JSON-LD:

- Title: `title`. Company: `smallCompany.companyName`. City: first `formattedPlaces` entry.
- Contract (`parsers/contract.rb`): `contractTypes[]` mapped with PERMANENT priority
  (permanent > fixedTerm > apprenticeship > internship > freelance).
- Salary (`parsers/salary.rb`): `details.salary`, **yearly channel only** (other recurrences
  are on a different scale and left nil), amounts scaled ×1000 to whole units, `€` → `EUR`,
  defaulting to `EUR` when amounts are present without a currency symbol.
- Location mode (`parsers/location_mode.rb`): `details.remotePolicy.frequency`
  (`fullTime`→remote, `hybrid`/partial→hybrid, `no`/`none`→on-site, missing→nil).
- `posted_at`: epoch-ms `publishDate` (fallback `createdAt`) → ISO8601.
- Description: markdown `mdDescription` rendered to HTML via kramdown, scripts/styles removed,
  then `clean_attributes` for token-efficient enrich.

### Enrich

- Mirrors the shared enrich contract; sets `hybrid_remote_days_min_per_week` only when
  `location_mode == "hybrid"`.

## Known limitations

- No work-mode filtering at discovery (see above).
- City is only as precise as `formattedPlaces` (often a country, e.g. "France", for full-remote
  offers); `details.places` carries only Google place IDs, not names.
- Salary is read for yearly recurrences only; monthly/other recurrences yield no salary.
- The Algolia application id and search key are public site constants. If WeLoveDevs rotates
  them or restricts the index, discovery and fetch fail loudly with the HTTP status.

## Verification commands

- bundle exec rspec spec/services/sourcing/providers/welovedevs/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/welovedevs/enrich_step_spec.rb

Manual probe (plain HTTP, no Playwright):

```bash
bin/rails runner '
  urls = Sourcing::Providers::Welovedevs::DiscoveryStep.new.call(source: "welovedevs", keyword: "ruby", work_mode: nil, page: 1)[:discovered_urls]
  body = Sourcing::Providers::Welovedevs::FetchStep.new.call(source: "welovedevs", url: urls.first, url_hash: "x")
  pp Sourcing::Providers::Welovedevs::AnalyzeStep.new.call(html_content: body)
'
```
