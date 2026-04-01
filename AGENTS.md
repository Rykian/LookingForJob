# AGENTS.md

Repository guide for coding agents.

## Project Snapshot

- Stack: Rails 8 API, PostgreSQL, Sidekiq, Playwright, RubyLLM
- Core flow: `DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob`
- Main code areas: `app/jobs/sourcing/`, `app/services/sourcing/`
- Tests: RSpec

## Core Checklist

- Preserve pipeline contracts and payload shapes.
- Prefer idempotent writes for ingestion paths.
- Run the smallest relevant verification command.
- Report outcomes as: changed, verified, remaining risk.

## Sourcing Guardrails

- Keep job chain contract intact: `DiscoveryJob -> FetchJob -> AnalyzeJob -> EnrichJob`.
- Respect provider step contracts:
  - `Sourcing::DiscoveryStep`
  - `Sourcing::FetchStep`
  - `Sourcing::AnalyzeStep`
  - `Sourcing::EnrichStep`
- LinkedIn crawling is brittle: fail explicitly with context.
- LLM enrichment requires env-backed keys (`OPENAI_API_KEY` or `LLM_API_KEY`).
- On quota/rate-limit issues, fail loudly with actionable details.

## Verification Checklist

- Targeted spec first: `bundle exec rspec path/to/spec_file.rb`
- Broader checks when needed: `bundle exec rspec`, then `bin/ci`
- Local setup if required:
  - `docker compose up -d postgres`
  - `bin/rails db:create db:migrate`

## PR Review Do/Don't

Do:
- Confirm every changed line maps to the request.
- Validate behavior with tests or deterministic runtime checks.
- Call out side effects, migrations, retries, and failure paths.
- Highlight residual risks and follow-up actions.
- Keep PR scope atomic and easy to review.

Don't:
- Don’t mix feature work with opportunistic refactors.
- Don’t silently change API/payload contracts.
- Don’t hide flaky behavior from external integrations.
- Don’t skip verification for touched behavior.
- Don’t include unrelated formatting churn.

## Library Preference

- Suggest 1-2 mature Rails ecosystem libraries before custom code.
- If custom implementation is chosen, explain why.
- Typical candidates:
  - HTTP/retries: Faraday middleware
  - Parsing resilience: Nokogiri selector fallbacks
  - Background reliability: Sidekiq retry/dead set
  - Complex validation: dry-schema / dry-validation

## Commit Policy

- Use Conventional Commits for all commits.
- Keep commits focused and atomic.
- Message must describe user-visible intent.

### Allowed Conventional Commit Scopes (restricted list)

Use one scope from this list:
- `sourcing` (cross-step/pipeline changes)
- `sourcing-linkedin`
- `graphql`
- `job-offer` (model and domain rules)
- `repository` (data access layer)
- `frontend` (React/Vite UI)
- `db` (migrations/schema/data backfills)
- `infra` (Docker, deploy, runtime config)

Scope selection rules:
- Prefer the most specific scope available.
- Use `sourcing` only when a change spans multiple sourcing steps.
- Use exactly one scope per commit.

Examples:
- `feat(sourcing): add linkedin pagination continuation`
- `fix(sourcing-linkedin): handle crawl selector drift with explicit error`
- `chore(docs): tighten AGENTS checklist`
