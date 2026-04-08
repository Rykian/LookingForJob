# WTTJ Provider

This provider integrates Welcome to the Jungle jobs into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover WTTJ offer URLs from search pages.
- fetch_step.rb: Fetch WTTJ offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from embedded data and DOM fallback selectors.
- enrich_step.rb: LLM enrichment for missing structured fields.

## Runtime behavior

### Discovery

- Search base URL: https://www.welcometothejungle.com/fr/jobs
- Supports keyword and location filtering via URL params.
- Uses next-page controls with MAX_PAGES guard.

### Fetch

- Fetches page in Playwright and validates basic content sanity.
- Returns HTML payload consumed by analyze step.

### Analyze

- Prioritizes structured/embedded data when available.
- Normalizes contracts, salary ranges, location mode, and posted_at.
- Extracts minimal description HTML for token efficiency.

### Enrich

- Uses stripped description text as LLM input.
- Returns strict enrichment schema used by the pipeline.

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/wttj/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/wttj/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/wttj/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/wttj/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/

## Notes

- WTTJ layout changes can affect selector-based fallbacks.
- Re-run provider specs and a real URL check after selector updates.
