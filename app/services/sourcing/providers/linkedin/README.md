# LinkedIn Provider

This provider integrates LinkedIn jobs into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover LinkedIn job URLs from search result pages.
- fetch_step.rb: Fetch LinkedIn job detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from embedded data and DOM fallbacks.
- enrich_step.rb: LLM enrichment for missing structured fields.
- session_manager.rb: Load/save Playwright storage state for authenticated sessions.

## Runtime behavior

### Discovery

- Uses authenticated Playwright context from saved session state.
- Paginates with a MAX_PAGES cap.
- Detects blocked/challenge/login pages and fails loudly.
- Normalizes discovered URLs (removes query/fragment noise).

### Fetch

- Reuses authenticated session state.
- Handles login/challenge/interstitial diagnostics.
- Fails loudly if page content is shell HTML or blocked state.

### Analyze

- Extracts title, company, city, employment_type, salary, location_mode, posted_at, description_html.
- Includes normalization for common contract and salary formats.

### Enrich

- Uses stripped description text as LLM input.
- Returns strict enrichment schema used by the pipeline.

## Session setup

Create or refresh LinkedIn session storage:

- bin/rails linkedin:login

Session file path:

- data/linkedin_session.json

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/linkedin/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/linkedin/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/linkedin/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/linkedin/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/

## Notes

- LinkedIn access quality depends on session freshness and challenge risk.
- When session is missing/corrupt, discovery/fetch fail with actionable guidance.
