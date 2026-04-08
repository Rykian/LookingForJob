---
name: sourcing-provider-creation
description: "Use when: creating a new sourcing provider, adding provider steps, validating discovery/fetch/analyze/enrich contracts, testing extraction on real job URLs, mapping fields/selectors, and enforcing LLM enrichment for missing fields."
---

# Sourcing Provider Creation

Create a new sourcing provider that integrates with the existing pipeline:

`DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob`

## Goals

1. Keep pipeline and step contracts unchanged.
2. Add provider-specific logic for discovery, fetch, analyze, and enrich.
3. Validate discovery and analyze with real URLs and ask the user to confirm quality.
4. In analyze, detect and report missing fields with a field mapping table.
5. Keep `description_html` minimal to reduce token usage.
6. In enrich, infer missing fields from plain text stripped from HTML.
7. Prefer structured data and shared fetch helpers over brittle one-off selectors.
8. Fail loudly when auth, challenge, quota, or invalid-content conditions make extraction unreliable.

## Required Workflow

### 0. API or Crawl Decision

1. Check whether the provider offers an API that can return job search and job details.
2. Assess and report API access difficulty (public, partner-only, paid tier, approval delays, auth complexity, quota limits).
3. Tell the user clearly if getting API access appears difficult.
4. Ask the user to choose implementation mode: API integration or Playwright crawling.
5. Continue implementation only after user confirms the mode.

### 0.5 Session Management (for Playwright crawling)

If using Playwright crawling, assess authentication needs:

1. **Determine if authenticated access is required or beneficial:**
   - Can the provider be scraped without login? Test logged-out discovery results.
   - Does logged-in mode provide significantly better job coverage, relevance, or stability?
   - Document the comparison and recommend the mode that gives best quality.

2. **Implement SessionManager pattern if authentication is needed:**
   - Create `app/services/sourcing/providers/<provider>/session_manager.rb`
   - Provide methods: `load`, `load_if_required!`, persistence (file or database).
   - Store session state (cookies, localStorage) for browser reuse.
   - Document exact session path and expected structure.

3. **Provide interactive login task:**
   - Create `lib/tasks/<provider>.rake` with login subtask.
   - Allow manual HEADLESS=false inspection and login workflow.
   - Print clear instructions on session save location.
   - Do not require HEADLESS=false for normal operation; make it optional.

4. **Mark session requirement clearly:**
   - In discovery/fetch, decide whether session is optional (graceful fallback) or required (fail explicitly).
   - If session is optional, test both modes and report differences.
   - If required, fail loudly with actionable guidance: "No trusted session found; run `rails <provider>:login` to create one."

### 1. Discovery

1. Implement provider discovery in the provider step registry/dispatch flow.
2. Test discovery against at least one real provider URL.
3. Compare logged-out and logged-in discovery results when authentication is possible.
4. Decide and document which mode gives better discovery quality (coverage, relevance, stability).
5. Show discovered URLs and the chosen mode to the user and ask: "Does this result look correct?"
6. Ask the user whether keyword filtering and location filtering are working correctly.
7. If user rejects results, refine selectors/rules/session strategy and re-run.

### 2. Fetch

1. Fetch page content with resilient selectors and clear failures.
2. Keep provider errors actionable (auth/session/quota/selector drift).
3. Preserve payload shape consumed by analyze step.
4. Reuse shared browser/context helpers when they exist instead of duplicating setup and teardown logic.
5. Validate that fetched HTML contains meaningful job content before passing it to analyze.
6. If the page resolves to an auth wall, challenge page, or other non-job state, fail explicitly with context instead of returning partial HTML.

**Anti-Bot and Challenge Detection:**

7. Detect common anti-bot patterns and fail fast with clear guidance:
   - Cloudflare challenges, GDPR consent walls, authentication redirects.
   - Use regex patterns on page text to identify challenge content.
   - Store regex patterns as constants at the class level.
   - Fail with specific context: `"Cadremploi returned a Cloudflare challenge; provide a trusted session in #{SessionManager.path}"`
   - Do not attempt retries or workarounds; let the operator handle session provision.

**Performance Optimization:**

8. For crawler actions that may block or timeout (e.g., click, evaluate on slow pages):
   - Set reasonable bounded timeouts (e.g., 1-2 seconds for modal clicks).
   - Fall back gracefully when actions timeout instead of long retry loops.
   - Detect blocking conditions (overlays, modals) with short `page.evaluate()` checks before expensive actions.
   - Fast-fail on block detection and return a truncated result rather than wait for action to succeed.
   - Measure real-world performance on target URLs and document expected fetch times.
   - Do not assume page actions will complete in test time; validate on live provider pages.

### 3. Analyze

1. Test analyze against at least one real job URL.
2. Extract target fields and identify all missing fields.
3. Present the analysis to user and ask: "Does this extraction look correct?"
4. Build and display a field mapping table:

| Field | Selector or Strategy | Example Value | Status |
|---|---|---|---|
| title | `h1.job-title` | Senior Backend Engineer | extracted |
| company | `.company-name` | Example Corp | extracted |
| salary | `.salary-range` | - | missing |

5. **Use structured data extraction first:**
   - Check for `JSON-LD` JobPosting schema in `<script type="application/ld+json">` tags.
   - Extract `title`, `hiringOrganization.name`, `jobLocation.address`, `baseSalary`, `employmentType`, `datePosted`, `description`.
   - JSON-LD is the most reliable and portable extraction method; use it as primary strategy.
   - Fall back to DOM selectors only when schema is missing.

6. For `description_html`, return the smallest meaningful HTML fragment only:
   - Keep core content blocks (job description, responsibilities, requirements).
   - Remove scripts, styles, nav, footer, sidebars, and unrelated wrappers.
   - Prefer concise subtree extraction instead of full-page HTML.
   - **Remove style and class attributes** from all returned HTML elements using `clean_attributes()` to reduce token usage in enrich.
   - Call `clean_attributes()` on all description HTML before returning to ensure consistency across providers.

7. Use this extraction precedence unless the user asks otherwise:
   - Structured payloads first (`JSON-LD`, embedded app state, API payloads).
   - Stable semantic DOM selectors second.
   - Regex and loose text parsing last.

8. Normalize extracted values before returning them:
   - Collapse unusual whitespace such as non-breaking spaces.
   - Normalize provider-specific labels into pipeline enums.
   - Prefer explicit timestamps when they are available from structured data.

9. Keep a clear distinction between `missing`, `present but ambiguous`, and `present but normalized` fields when reporting results.

### 4. Enrich (LLM required)

1. Convert `description_html` to stripped plain text before prompting.
2. Infer missing fields from the stripped description text.
3. Keep strict output schema and defaults for unknown values.
4. Fail loudly with actionable details when LLM keys are missing (`OPENAI_API_KEY` or `LLM_API_KEY`) or quota is hit.

## Output Format (for review with user)

When presenting analyze results, always include:

1. Real URL tested.
2. Short extraction summary (e.g., "JSON-LD JobPosting + DOM fallback").
3. Field mapping table (Field, Selector or Strategy, Example Value, Status).
4. Missing fields list with extraction difficulty estimate (easy, moderate, difficult).
5. Description HTML size (chars) and content blocks included.
6. Explicit user confirmation question: "Does this extraction look correct?"

When presenting discovery results, always include:

1. Real discovery URL tested.
2. Whether logged-in or logged-out mode was selected and why (if applicable).
3. A short sample of discovered URLs (5-10 examples).
4. Keyword and location filter validation: "Are filters working correctly?"
5. Session mode (optional graceful fallback, or required with explicit guidance).

When presenting fetch results, always include:

1. Real job URL tested.
2. Whether session was used (if applicable) and why.
3. Any challenges, anti-bot triggers, or performance observations.
4. HTML size and main content markers present.
5. Explicit pass/fail on content quality: "Does the fetched HTML look like a job page?"

Before discovery implementation, always include:

1. Whether an API exists for the provider.
2. API access difficulty assessment.
3. Explicit question: "Do you want to use the API or crawl with Playwright?"

## Validation Checklist

1. Provider is wired into all four steps (discovery/fetch/analyze/enrich).
2. API availability and access difficulty were assessed and reported to user.
3. User explicitly chose API integration or Playwright crawling.
4. **Session management validated:**
   - If authenticated: SessionManager created, login task provided, optional vs required session mode documented.
   - If not authenticated: logged-out discovery tested and confirmed sufficient for coverage.
5. Discovery validated on real URL, including logged-in vs logged-out comparison when possible.
6. Anti-bot and challenge detection tested; challenge patterns documented as regex constants.
7. Fetch performance validated on real URLs; expected fetch time documented; timeouts bounded.
8. Analyze validated on real URL and user approved result.
9. Missing fields are clearly listed and mapped.
10. `description_html` is minimized for token efficiency; `clean_attributes()` applied to remove style/class.
11. **HTML sanitization centralized:** All analyze steps use `Sourcing::AnalyzeStep#clean_attributes` (protected method).
12. Enrich infers missing fields from stripped description text.
13. **Provider-specific README created** and linked from root README:
    - Document extraction strategy (JSON-LD first, then selectors, fallback heuristics).
    - Document known limitations and provider-specific behavior.
    - Include rebuild instructions and test command examples.
14. Provider-specific specs exist for integration behavior.
15. Fetch was validated against a real page state, not just fixtures.
16. Failure modes for auth walls, challenge pages, quota errors, and invalid HTML were checked explicitly.
17. Shared helpers were reused where possible instead of cloning browser logic into the provider.
18. **AGENTS.md updated** with rule: "update provider docs when provider behavior changes."

## Verification Commands

Run the smallest relevant checks first:

```bash
bundle exec rspec path/to/provider_spec.rb
```

Then broader checks when needed:

```bash
bundle exec rspec
bin/ci
```

Local setup if required:

```bash
docker compose up -d postgres
bin/rails db:create db:migrate
```

## Implementation Patterns

### Session Manager Pattern

For authenticated crawling, use this pattern:

```ruby
# app/services/sourcing/providers/<provider>/session_manager.rb
class SessionManager
  def self.path
    # Return path to session storage (file or DB)
  end

  def self.load
    # Load session state (cookies, localStorage, etc.)
    # Return nil if not found (graceful fallback)
  end

  def self.load_if_required!
    # Load session or raise with helpful guidance
    load || raise "Session not found. Run: rails <provider>:login"
  end
end
```

Then in discovery/fetch:

```ruby
session = SessionManager.load_if_required!  # Or load for optional auth
context = browser.new_context(**default_context_options(storage_state: session))
```

### HTML Sanitization Pattern

In all analyze steps, apply `clean_attributes()` to description HTML:

```ruby
# app/services/sourcing/analyze_step.rb (parent class)
protected

def clean_attributes(html_string)
  return html_string if html_string.nil? || (html_string.respond_to?(:blank?) && html_string.blank?)
  
  doc = Nokogiri::HTML.fragment(html_string)
  doc.css("*").each do |elem|
    elem.delete("style")
    elem.delete("class")
  end
  doc.to_html.strip
end
```

Then in provider analyze steps:

```ruby
description_html = clean_attributes(extract_description_html(doc))
```

### Anti-Bot Detection Pattern

```ruby
class DiscoveryStep
  BLOCKED_PAGE_PATTERN = /(cloudflare|challenge|captcha|login|security)/i
  
  def challenge_page?(page_obj)
    page_obj.content =~ BLOCKED_PAGE_PATTERN
  end
end
```

### Performance Optimization Pattern

```ruby
# Bounded click timeout with fast fallback
EXPAND_CLICK_TIMEOUT_MS = 1_200

begin
  button.click(timeout: EXPAND_CLICK_TIMEOUT_MS)
  { expanded: true, strategy: "button_click" }
rescue Playwright::TimeoutError
  # Try fallback or return partial result
  { expanded: false, strategy: "timeout" }
end

# Overlay detection short-circuit
if page_obj.evaluate('() => { return !!document.querySelector(".blocking-overlay"); }')
  return { expanded: false, strategy: "blocked_overlay" }
end
```

## Guardrails

1. Do not break existing payload contracts between jobs/steps.
2. Do not silently swallow rate-limit/auth/session issues.
3. Keep changes surgical: only provider-related files unless contract updates are required.
4. Preserve idempotent ingestion behavior.
5. Prefer deterministic extraction order over accumulating many parallel fallback heuristics.
6. Do not treat a successfully loaded browser page as a successful fetch if the content is not actually a job page.
7. When runtime serialization or job argument behavior differs across environments, handle it explicitly and document the constraint.
8. **Session and Auth:** Do not attempt automatic retries or workarounds for anti-bot challenges; fail fast and let the operator provision a trusted session.
9. **Performance:** Bound all Playwright actions with strict timeouts; use overlay/block detection to fast-fail instead of long retry loops.
10. **HTML Sanitization:** Always apply `clean_attributes()` to description HTML to remove presentational attributes; consolidate this logic in `Sourcing::AnalyzeStep` and use it across all providers.
11. **JSON-LD First:** Prefer structured data extraction (JSON-LD, embedded JSON) over DOM selectors; only resort to selectors when schema is missing.
12. **Provider Documentation:** Each provider must have a README documenting selectors, extraction strategy, and known limitations. Update root README index when adding providers.
13. **Initialization Guard:** If adding initializers that depend on external services or runtime state, guard the code to prevent test environment boot failures.

## Related Documentation

- See `app/services/sourcing/providers/cadremploi/README.md` for a complete example of discovery/fetch/analyze/enrich with session management and JSON-LD extraction.
- See `app/services/sourcing/providers/linkedin/README.md` for resilient selector patterns and performance optimization examples.
- See `AGENTS.md` for provider-specific guardrails (e.g., LinkedIn crawling brittleness, need to update provider docs on behavior changes).
