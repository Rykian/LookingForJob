# France Travail Provider

This provider integrates France Travail offers into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover France Travail offer URLs from search pages.
- fetch_step.rb: Fetch offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from HTML microdata and semantic selectors.
- enrich_step.rb: LLM enrichment for missing structured fields.

## Runtime behavior

### Discovery

- Search base URL: https://candidat.francetravail.fr/offres/recherche
- Offer base URL: https://candidat.francetravail.fr
- Builds full offer URLs from discovered relative links.
- Supports pagination and URL filtering through provider logic.

### Fetch

- Validates that fetched pages are not auth/login walls.
- Fails loudly when HTML is empty/shell-like or blocked by auth state.

### Analyze

- Uses schema/microdata first (title, company, posted date, salary fields).
- Normalizes city, contract type, salary units, and location mode.
- Extracts concise description_html from the main description block.

### Enrich

- Uses stripped description text as LLM input.
- Returns strict enrichment schema used by the pipeline.

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/france_travail/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/france_travail/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/france_travail/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/france_travail/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/

## Notes

- Auth/interstitial pages are treated as explicit failures.
- Keep extraction order deterministic: microdata first, selector fallbacks second.
