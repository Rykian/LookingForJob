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

## Required Workflow

### 0. API or Crawl Decision

1. Check whether the provider offers an API that can return job search and job details.
2. Assess and report API access difficulty (public, partner-only, paid tier, approval delays, auth complexity, quota limits).
3. Tell the user clearly if getting API access appears difficult.
4. Ask the user to choose implementation mode: API integration or Playwright crawling.
5. Continue implementation only after user confirms the mode.

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

5. For `description_html`, return the smallest meaningful HTML fragment only:
   - Keep core content blocks.
   - Remove scripts, styles, nav, footer, sidebars, and unrelated wrappers.
   - Prefer concise subtree extraction instead of full-page HTML.

### 4. Enrich (LLM required)

1. Convert `description_html` to stripped plain text before prompting.
2. Infer missing fields from the stripped description text.
3. Keep strict output schema and defaults for unknown values.
4. Fail loudly with actionable details when LLM keys are missing (`OPENAI_API_KEY` or `LLM_API_KEY`) or quota is hit.

## Output Format (for review with user)

When presenting analyze results, always include:

1. Real URL tested.
2. Short extraction summary.
3. Field mapping table (Field, Selector or Strategy, Example Value, Status).
4. Missing fields list.
5. Explicit user confirmation question.

When presenting discovery results, always include:

1. Real discovery URL tested.
2. Whether logged-in or logged-out mode was selected and why.
3. A short sample of discovered URLs.
4. Explicit question: "Are keyword and location filters working correctly?"

Before discovery implementation, always include:

1. Whether an API exists for the provider.
2. API access difficulty assessment.
3. Explicit question: "Do you want to use the API or crawl with Playwright?"

## Validation Checklist

1. Provider is wired into all four steps (discovery/fetch/analyze/enrich).
2. API availability and access difficulty were assessed and reported to user.
3. User explicitly chose API integration or Playwright crawling.
4. Discovery validated on real URL, including logged-in vs logged-out comparison when possible.
5. Analyze validated on real URL and user approved result.
6. Missing fields are clearly listed and mapped.
7. `description_html` is minimized for token efficiency.
8. Enrich infers missing fields from stripped description text.
9. Provider-specific specs exist for integration behavior.

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

## Guardrails

1. Do not break existing payload contracts between jobs/steps.
2. Do not silently swallow rate-limit/auth/session issues.
3. Keep changes surgical: only provider-related files unless contract updates are required.
4. Preserve idempotent ingestion behavior.
