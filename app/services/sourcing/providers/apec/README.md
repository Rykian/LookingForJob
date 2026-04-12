# Apec Provider

This provider integrates Apec into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover Apec offer URLs from logged-out search pages.
- fetch_step.rb: Fetch offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from rendered Apec HTML.
- enrich_step.rb: LLM enrichment for missing structured fields.

## Runtime behavior

### API access assessment

Apec exposes public website webservices such as `/cms/webservices/rechercheOffre` and `/cms/webservices/offre/public`, but they do not appear to be documented as a supported external API product. This implementation intentionally uses Playwright crawling because that mode was explicitly selected.

### Session mode

- Logged-out mode was validated on live Apec search and detail pages.
- No trusted session is required for discovery or fetch.
- Anonymous mode was selected because search results, pagination, and detail pages render without login.

### Discovery

- Base search URL: https://www.apec.fr/candidat/recherche-emploi.html/emploi
- Job URL pattern: `/candidat/recherche-emploi.html/emploi/detail-offre/<id>`
- Keyword filtering uses the public `motsCles` query parameter.
- Validated telework filters:
  - `remote` -> `typesTeletravail=20767` (`Télétravail total possible`)
  - `hybrid` -> `typesTeletravail=20765` and `typesTeletravail=20766` (`Télétravail partiel possible`, `Télétravail ponctuel autorisé`)
- `on-site` is not implemented because no stable on-site-only filter was validated; discovery fails loudly if requested.
- Pagination uses the `page` query parameter with a safety cap.
- Challenge pages (Cloudflare/captcha/challenge/access denied) fail loudly.

### Fetch

- Uses Playwright with `fr-FR` locale.
- Waits for `h1`, `apec-offre-metadata`, or `.details-post` before capturing HTML.
- Validates the detail URL shape, presence of offer metadata, and minimum body size.
- Fails loudly on anti-bot/challenge pages and 404/non-job pages.

### Analyze

Extraction precedence:

1. Stable rendered DOM markers (`apec-offre-metadata`, `.details-post`)
2. Text heuristics for telework and dates

Current normalized output fields:

- title
- company
- city
- employment_type
- salary_min_minor
- salary_max_minor
- salary_currency
- location_mode
- posted_at
- description_html

Description extraction:

- Keeps the rendered `Descriptif du poste` block only.
- Preserves nested sections such as `Profil recherché` and embedded skill blocks when they are included inside that main description block.
- Removes buttons, SVGs, and presentational attributes via `clean_attributes`.

### Enrich

- Converts `description_html` to plain text before prompting the LLM.
- Keeps strict schema output compatible with the sourcing pipeline.
- Uses environment-backed LLM credentials (`OPENAI_API_KEY` or `LLM_API_KEY` via LLM config).

## Validation notes

- Live logged-out search validation confirmed:
  - keyword search via `motsCles=ruby`
  - remote filter via `typesTeletravail=20767`
  - hybrid filters via `typesTeletravail=20765` and `typesTeletravail=20766`
- Live detail validation confirmed that rendered pages expose `h1`, `apec-offre-metadata`, and repeated `.details-post` blocks without authentication.

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/apec/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/apec/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/apec/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/apec/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/