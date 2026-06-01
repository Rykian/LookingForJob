# Indeed Provider

This provider integrates Indeed into the sourcing pipeline:

DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob

## Files

- discovery_step.rb: Discover Indeed offer URLs from search pages, canonicalized to `/viewjob?jk=<id>`.
- fetch_step.rb: Fetch offer detail HTML with Playwright.
- analyze_step.rb: Extract normalized fields from JSON-LD JobPosting and DOM fallbacks.
- enrich_step.rb: LLM enrichment for missing structured fields.
- session_manager.rb: Load/save Playwright storage state for trusted sessions.

## Runtime behavior

### Discovery

- Base search URL: `https://fr.indeed.com/jobs`
- Host overridable via `INDEED_HOST` env var (defaults to `fr.indeed.com`).
- Pagination: `start` offset increments by `PAGE_SIZE=10`. Cap: `MAX_PAGES=10`.
- Job ids are extracted from `a[data-jk]` and canonicalized to `https://<host>/viewjob?jk=<id>`.
- Cookie consent: OneTrust banner (`#onetrust-accept-btn-handler`).
- Anti-bot detection via title/body regex (`BLOCKED_PAGE_PATTERN`); fails fast with actionable guidance.
- Work-mode filter:
  - `remote` -> `sc=0kf:attr(DSQF7);`
  - `hybrid` -> `sc=0kf:attr(PAXZC);`
  - `on-site` -> raises (no stable filter exists).

### Fetch

- Handles cookie consent banner.
- Fails loudly when the page is an anti-bot challenge or lacks main content markers.
- Main content markers: JSON-LD script, `h1[data-testid='jobsearch-JobInfoHeader-title']`, `#jobDescriptionText`.

### Analyze

Extraction precedence:

1. JSON-LD JobPosting (`script[type='application/ld+json']`)
2. Stable DOM selectors (`#jobDescriptionText`, `[data-testid='inlineHeader-companyName']`, etc.)
3. Text heuristics for employment type and location mode

Provider-specific output notes:

- `city` — postal codes stripped from `"Paris (75001)"` / `"75001 Paris"` shapes
- `employment_type` — PERMANENT/FIXED_TERM/APPRENTICESHIP/INTERNSHIP/FREELANCE/TEMPORARY/FULL_TIME/PART_TIME
- `salary_*` — normalized to yearly amounts from MONTH/WEEK/DAY/HOUR units
- `location_mode` — `jobLocationType=TELECOMMUTE` in JSON-LD is the strongest signal

### Enrich

- Uses stripped description text as LLM input.
- Strict JSON schema output, identical shape to Apec/Cadremploi for downstream consistency.

## Trusted session mode

Indeed sits behind Cloudflare Turnstile, which fingerprints every Playwright-launched browser (bundled Chromium *and* system Chrome with stealth args). If the default guest session is blocked, the reliable workaround is to harvest cookies from a real Chrome the user runs themselves, then use those cookies in Playwright's storage state. Playwright is used only as a CDP client to read the cookies - it never has to pass Turnstile itself.

1. Quit all Chrome windows.
2. Start Chrome with remote debugging enabled, using your normal profile:
   ```fish
   open -na 'Google Chrome' --args \
     --remote-debugging-port=9222 \
     --user-data-dir="$HOME/Library/Application Support/Google/Chrome"
   ```
3. In that Chrome, visit https://fr.indeed.com, pass the Cloudflare check, sign in if you want, and confirm the search results render.
4. Run `bin/rails indeed:login`. It connects to `http://localhost:9222` (override with `INDEED_CDP_URL`), reads cookies via the CDP `Network.getAllCookies` command, filters to `*.indeed.com`, and writes Playwright storage_state to `data/indeed_session.json`.

Optional strict mode for runtime:

- `INDEED_REQUIRE_SESSION=true` - discovery/fetch fail immediately when no session exists.

Without strict mode the provider runs logged-out and picks up the session file if present.

### Caveats

- The `cf_clearance` cookie is bound to user-agent and IP. Discovery/fetch must run from the same machine as the Chrome that harvested it, and the Playwright user-agent (`Sourcing::PlaywrightSupport::DEFAULT_USER_AGENT`) should roughly match the Chrome version that did the harvest - if you upgrade Chrome significantly, re-harvest.
- Sessions expire. If discovery starts hitting challenge pages again, repeat the harvest.

## Session storage path

Default path:

- `data/indeed_session.json`

Override path:

- `INDEED_STORAGE_STATE_PATH=/absolute/path/to/session.json`

## Verification commands

Targeted provider checks:

- `bundle exec rspec spec/services/sourcing/providers/indeed/discovery_step_spec.rb`
- `bundle exec rspec spec/services/sourcing/providers/indeed/fetch_step_spec.rb`
- `bundle exec rspec spec/services/sourcing/providers/indeed/analyze_step_spec.rb`
- `bundle exec rspec spec/services/sourcing/providers/indeed/enrich_step_spec.rb`

## Notes

- Real-world listing pages can be challenge-protected from cloud/datacenter IPs. Use a trusted session created from a residential connection when running outside a local browser.
- Indeed occasionally injects sponsored job cards above the 10 organic results, so a single search page may yield more than `PAGE_SIZE` discovered URLs - this is expected.
- Indeed's `sc=0kf:attr(<id>);` attribute filters for `remote` and `hybrid` have been stable for years but are not part of any public API; update `REMOTE_ATTR` / `HYBRID_ATTR` constants if the facet IDs drift.
- Some offers do not expose explicit `jobLocationType`; text heuristics on the description provide a best-effort `location_mode`.
