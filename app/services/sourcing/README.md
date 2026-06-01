# Sourcing Pipeline

Core pipeline: `DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob`

Provider implementations live under `providers/<name>/`.

## Step contracts

### Fetch

All Playwright-based providers use `fr-FR` locale. LinkedIn is the exception — it uses plain HTTP with no Playwright.

### Analyze output

Every provider normalizes to the same field set:

- `title`
- `company`
- `city`
- `employment_type`
- `salary_min_minor`, `salary_max_minor`, `salary_currency`
- `location_mode`
- `posted_at`
- `description_html`

Provider READMEs only document extraction precedence and deviations from this contract.

### Enrich

All enrich steps convert `description_html` to plain text before prompting the LLM. Credentials are read from `OPENAI_API_KEY` or `LLM_API_KEY` via `Sourcing::LlmConfig`.

## Verification

```bash
bundle exec rspec spec/services/sourcing/
```

## Technology canonicalization

Technologies extracted by the enrich step are stored as-is on first ingestion. A background job (`DedupTechnologiesJob`) periodically normalizes them to canonical names ("Node.js", "PostgreSQL", etc.) using an LLM.

### DedupTechnologiesJob

- **Schedule**: every Monday at 3am (`config/sidekiq.yml`).
- **What it does**: collects all distinct `primary_technologies` from active offers, sends them to the LLM in batches of 500, builds a raw→canonical alias map, rewrites every offer's technologies, updates `data/scoring_profile.json`, and writes the top-120 canonical names to Redis.
- **Resumable**: uses `ActiveJob::Continuable` — checkpointed after each batch and offer. Safe to interrupt and restart.
- **Redis artifacts** (written by `TechnologyStore`):
  - `sourcing:technologies:alias_map` — full raw→canonical mapping used by the enrich step prompt.
  - `sourcing:technologies:common` — top-120 canonical names injected into LLM prompts.

### Bootstrap dependency

Until the first `DedupTechnologiesJob` run completes, `TechnologyStore` returns empty structures (`{}` / `[]`). The enrich step silently omits the technology hint from its prompt in that state — extraction still works, just without canonical guidance. Run the job once after initial data ingestion:

```bash
bin/rails runner "Sourcing::DedupTechnologiesJob.perform_later"
```
