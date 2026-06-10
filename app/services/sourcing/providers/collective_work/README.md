# Collective.work Provider

Integrates Collective.work (https://www.collective.work) into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

Collective.work is a freelance-mission marketplace with a public Next.js jobs board.
No official API, **no login wall, and no anti-bot challenge** on the public listing,
so there is no SessionManager and no login rake task — both discovery and fetch run
unauthenticated over plain HTTP (Faraday), no Playwright.

## Files

- discovery_step.rb: Faraday GET on the SSR listing, parse `__NEXT_DATA__`, paginate via `?page=N`.
- fetch_step.rb: Faraday GET on the detail page; validate the embedded `project` payload.
- analyze_step.rb: Read `__NEXT_DATA__.props.pageProps.project` and map structurally.
- enrich_step.rb: LLM enrichment for technologies, seniority, English level, hybrid days.
- parsers/salary.rb, parsers/contract.rb, parsers/location_mode.rb: per-field normalization.

## Runtime behavior

### Discovery

- Listing URL: `https://www.collective.work/jobs/fr?search=<keyword>&page=<N>`.
- Both keyword (`search` param — confirmed: `?search=ruby` returns 6 hits vs 5374 default)
  and pagination (`page`, 1-indexed, 30 results/page) pass through to the SSR payload.
- The listing is a Next.js page; the React-Query hydrated state at
  `props.pageProps.dehydratedState.queries[0]` (queryKey `PublicPages_SearchJobs`) carries
  the full results object — `projects[]` with slug, `pagination.from`, `pagination.total`.
  Discovery walks pages until `from + len(projects) >= total` or `projects` is empty,
  capped at `MAX_PAGES = 200`.
- `supports_work_mode_filter?` is `false`: the `workPreferences` filter is only applied
  client-side via a React Query mutation; passing it on the URL has no effect on the SSR
  payload (verified with `?workPreference=REMOTE`/`?workPreferences=REMOTE`/`?remote=true`
  — all returned the unfiltered set). Location mode is captured per-offer in analyze.

### Fetch

- Detail pages are server-rendered with the same embedded `__NEXT_DATA__` blob. A valid
  offer carries a non-empty `project` hash at `props.pageProps.project`; a removed offer
  either returns HTTP 404 or renders with `project=null`, both treated as gone offers
  (`Sourcing::OfferGoneError` → disabled by FetchJob).
- Missing `__NEXT_DATA__` script tag raises loudly (possible selector drift).

### Analyze

Extraction reads `__NEXT_DATA__.props.pageProps.project` only — no JSON-LD JobPosting is
emitted on this site, and DOM scraping a React-rendered page is brittle. Field mapping:

| Field              | Source                                          |
|--------------------|-------------------------------------------------|
| title              | `project.name`                                  |
| company            | `project.company.name`                          |
| city               | first comma-segment of `project.location.fullNameFrench` |
| employment_type    | `project.isPermanentContract ? PERMANENT : FREELANCE` |
| salary_*           | `project.budgetBrief` (annual; permanent contracts only — daily rates left nil) |
| location_mode      | `project.workPreferences[]` collapsed (priority: REMOTE > HYBRID > ON_SITE) |
| posted_at          | `project.publishedAt` (fallback `project.createdAt`) |
| description_html   | `project.description` + `project.profileWanted`, scripts/styles removed, `clean_attributes` applied |

Normalizations:

- **Contract**: collective.work is a freelance marketplace, so the only structured contract
  signal is the `isPermanentContract` boolean (CDI vs freelance). Internships / fixed-term
  / apprenticeships are not exposed; everything non-permanent falls through to FREELANCE.
- **Salary**: `budgetBrief` is annual for permanent contracts ("70 000 € - 85 000 €") and a
  daily rate for freelance ("550€/jour", "450-515"). Daily rates on a different scale would
  corrupt the `salary_min_minor` annual convention used by other providers, so the parser
  deliberately returns blank for freelance and uses a 20k floor on the permanent branch to
  ignore mislabeled budgets.
- **Location mode**: `workPreferences` is an array (recruiters accept multiple modes). It
  collapses to the most-flexible accepted mode using REMOTE > HYBRID > ON_SITE priority.
- **Description**: `project.description` (mission) and `project.profileWanted` (candidate
  requirements) are both HTML strings and both useful for enrich (the LLM reads requirements
  to infer seniority / English level / technologies), so they are concatenated before
  cleaning.

### Enrich

- Mirrors the shared enrich contract; sets `hybrid_remote_days_min_per_week` only when
  `location_mode == "hybrid"`.

## Known limitations

- No work-mode filtering at discovery (URL params ignored by SSR — see above).
- Salary not extracted for freelance offers (`budgetBrief` is a daily rate that does not
  fit the annual `salary_min_minor` convention). Adding a `daily_rate_*` channel later
  would let downstream code consume this signal.
- `posted_at` carries a full ISO timestamp from `publishedAt`.

## Verification commands

- bundle exec rspec spec/services/sourcing/providers/collective_work/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/collective_work/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/collective_work/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/collective_work/enrich_step_spec.rb

Manual probes (plain HTTP, no Playwright required):

```bash
bin/rails runner 'pp Sourcing::Providers::CollectiveWork::DiscoveryStep.new.call(source: "collective_work", keyword: "ruby", work_mode: nil, force: false)[:discovered_urls].first(10)'
bin/rails runner 'html = Sourcing::Providers::CollectiveWork::FetchStep.new.call(url: "https://www.collective.work/jobs/fr/<slug>"); pp Sourcing::Providers::CollectiveWork::AnalyzeStep.new.call(html_content: html)'
```
