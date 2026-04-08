# Cadremploi Provider

This provider integrates Cadremploi into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover Cadremploi offer URLs from search pages.
- fetch_step.rb: Fetch offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from JSON-LD and DOM fallbacks.
- enrich_step.rb: LLM enrichment for missing structured fields.
- session_manager.rb: Load/save Playwright storage state for trusted sessions.

## Runtime behavior

### Discovery

- Base search URL: https://www.cadremploi.fr/emploi/liste_offres
- Job URL pattern: /emploi/detail_offre?offreId=...
- Supports pagination with a MAX_PAGES cap.
- Detects challenge pages and fails with an actionable error.
- Canonicalizes discovered URLs by removing fragments.

### Fetch

- Uses Playwright with fr-FR locale.
- Handles cookie consent banners.
- Fails loudly when the page is not a real job page (auth wall/challenge/no title).

### Analyze

Extraction precedence:

1. JSON-LD JobPosting
2. Stable DOM selectors
3. Text heuristics

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

Implemented normalizations include:

- Employment types from French labels and schema values (for example FULL_TIME, PART_TIME, CDI, CDD).
- Salary from JSON-LD MonetaryAmount and Cadremploi text formats (for example KEUR ranges).

### Enrich

- Uses stripped description text as LLM input.
- Keeps strict schema output compatible with the sourcing pipeline.

## Trusted session mode

Cadremploi can return anti-bot challenge pages. To use a trusted browser session:

1. Create/save a session:
   - bin/rails cadremploi:login
2. Enable strict trusted-session mode for runtime:
   - CADREMPLOI_REQUIRE_SESSION=true

When strict mode is enabled and no session exists, discovery/fetch fail immediately with guidance.

## Session storage path

Default path:

- data/cadremploi_session.json

Override path:

- CADREMPLOI_STORAGE_STATE_PATH=/absolute/path/to/session.json

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/cadremploi/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/cadremploi/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/cadremploi/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/cadremploi/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/

## Notes

- Real-world listing pages can be challenge-protected depending on environment/session state.
- Some offers do not expose explicit location_mode signals; null is expected in those cases.
