# Hellowork Provider

This provider integrates Hellowork into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover Hellowork offer URLs from search pages.
- fetch_step.rb: Fetch offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from JSON-LD first, then DOM fallbacks.
- enrich_step.rb: LLM enrichment for missing structured fields.

## Runtime behavior

### API access assessment

No public Hellowork API endpoint was identified during implementation, and site terms include language indicating automated data extraction requires an explicit written license. This implementation uses Playwright crawling.

### Discovery

- Base search URL: https://www.hellowork.com/fr-fr/emploi/recherche.html
- Job URL pattern: /fr-fr/emplois/<id>.html
- Pagination uses the `p` query parameter with a safety cap.
- Challenge pages (Cloudflare/captcha/challenge/access denied) fail loudly.
- Work mode filtering is currently disabled (`supports_work_mode_filter? == false`) because no stable public query parameter or deterministic automation path was validated.

### Fetch

- Uses Playwright with `fr-FR` locale.
- Validates that fetched pages are real Hellowork job URLs.
- Fails loudly on anti-bot/challenge pages and 404/non-job pages.
- Validates minimum content size before analyze.

### Analyze

Extraction precedence:

1. JSON-LD JobPosting
2. Stable DOM selectors and metadata list items
3. Text heuristics for location mode and dates

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

- Keeps full HTML bodies for Hellowork content sections when available, including `Détail du poste`, `Le profil recherché`, and other relevant sections such as `Les avantages`, `Infos complémentaires`, `Bienvenue chez`, and similar content blocks.
- Reads the full `truncate-text` content block directly instead of the collapsed preview, so `Voir plus` content is preserved without needing to keep the toggle button.
- Includes closed `details` section bodies directly from the fetched HTML, so folded sections are preserved in `description_html`.
- Falls back to JSON-LD description otherwise.
- Always runs `clean_attributes` to remove style/class attributes.

### Enrich

- Converts `description_html` to plain text before prompting LLM.
- Keeps strict schema output compatible with the sourcing pipeline.
- Uses environment-backed LLM credentials (`OPENAI_API_KEY` or `LLM_API_KEY` via LLM config).

## Verification commands

Targeted provider checks:

- bundle exec rspec spec/services/sourcing/providers/hellowork/discovery_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/hellowork/fetch_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/hellowork/analyze_step_spec.rb
- bundle exec rspec spec/services/sourcing/providers/hellowork/enrich_step_spec.rb

Run all sourcing specs:

- bundle exec rspec spec/services/sourcing/

## Notes

- The implementation is intentionally JSON-LD-first to reduce selector brittleness.
- Hellowork legal terms explicitly mention restrictions on automated extraction without licensing; operate this provider according to your legal and contractual constraints.
