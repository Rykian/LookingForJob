# LookingForJob

[![CI](https://github.com/Rykian/LookingForJob/actions/workflows/ci.yml/badge.svg)](https://github.com/Rykian/LookingForJob/actions/workflows/ci.yml)
[![License: PolyForm NC 1.0](https://img.shields.io/badge/license-PolyForm%20NC%201.0-orange)](./LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-4.0-cc342d?logo=ruby&logoColor=white)](mise.toml)
[![Rails](https://img.shields.io/badge/Rails-8.1-cc0000?logo=rubyonrails&logoColor=white)](Gemfile)
[![React](https://img.shields.io/badge/React-19-61dafb?logo=react&logoColor=black)](package.json)
[![GraphQL](https://img.shields.io/badge/API-GraphQL-e10098?logo=graphql&logoColor=white)](app/graphql/)

Self-hosted job-board crawler that ingests offers from six French/EU sources,
enriches them with an LLM, scores them against a personal preference profile,
and serves the result through a typed GraphQL API to a React SPA.

> Built to replace the noisy "scroll five job sites every morning" routine
> with a single dashboard that ranks offers by how well they match my actual
> stack and remote-work preferences.

## How it works

```
    ┌─────────────────────────────────────────────────────────────────┐
    │                       Sourcing pipeline                         │
    │                                                                 │
    │   Discovery  ──►  Fetch  ──►  Analyze  ──►  Enrich  ──►  Score  │
    │   (Playwright)   (HTTP/JS)   (parse HTML)   (LLM)     (profile) │
    └─────────────────────────────────────────────────────────────────┘
            │              │             │            │           │
            ▼              ▼             ▼            ▼           ▼
                      JobOffer row (Postgres + jsonb step metadata)
```

Each stage is an idempotent Sidekiq job that writes a `steps_details.<step>`
JSONB key with `{ at, version }` so re-runs are safe and version-aware. The
`Score` step is profile-driven (see [data/scoring_profile.json](data/scoring_profile.json))
and re-runnable independently of the rest of the pipeline.

## Stack

| Layer       | Tech                                                         |
|-------------|--------------------------------------------------------------|
| Backend     | Rails 8.1 (API-only) + GraphQL-Ruby 2.3 + Sidekiq 8          |
| Database    | PostgreSQL 16                                                |
| LLM         | RubyLLM (provider-agnostic; OpenAI by default)               |
| Scraping    | Playwright (Ruby client) for JS-rendered providers           |
| Storage     | ActiveStorage on RustFS (S3-compatible, self-hosted)         |
| Frontend    | React 19 + Apollo Client 4 + React Router 7                  |
| Build       | Vite 8 + vite-ruby + Tailwind v4 + Biome                     |
| Auth/UI     | shadcn-ui + Radix UI + Lucide                                |
| Testing     | RSpec, FactoryBot, SimpleCov, Vitest, Storybook + Playwright |
| Deploy      | Kamal + Thruster on Docker                                   |
| CI          | GitHub Actions (Brakeman, bundler-audit, RuboCop, RSpec, tsc, Vitest, Storybook) |
| Dev tools   | mise (Ruby + Node versions), lefthook (pre-commit), foreman  |

## Sources

Seven providers behind a uniform four-step contract
(`Sourcing::DiscoveryStep / FetchStep / AnalyzeStep / EnrichStep`):

| Provider                                                                          | Notes                                            |
|-----------------------------------------------------------------------------------|--------------------------------------------------|
| [APEC](app/services/sourcing/providers/apec/README.md)                            | French executive job board                       |
| [Cadremploi](app/services/sourcing/providers/cadremploi/README.md)                | French job board, session-based crawling         |
| [France Travail](app/services/sourcing/providers/france_travail/README.md)        | French public employment service                 |
| [Hellowork](app/services/sourcing/providers/hellowork/README.md)                  | General French job board                         |
| [Indeed](app/services/sourcing/providers/indeed/README.md)                        | Aggregator, Cloudflare-protected, optional session |
| [LinkedIn](app/services/sourcing/providers/linkedin/README.md)                    | Public guest endpoints over plain HTTP (no auth) |
| [Welcome to the Jungle](app/services/sourcing/providers/wttj/README.md)           | Tech-leaning French board                        |

Adding a new provider = drop four files under `app/services/sourcing/providers/<name>/`
and register the key in [Sourcing::Providers](app/services/sourcing/providers.rb).
See [app/services/sourcing/README.md](app/services/sourcing/README.md) for pipeline internals and the technology canonicalization system.

## Profile-driven scoring

The `Sourcing::ScoringJob` reads [data/scoring_profile.json](data/scoring_profile.json)
and writes a 0-100 `score` plus a `score_breakdown` JSONB explaining each
component. The profile is editable through a GraphQL mutation
(`updateScoringProfile`), so the React UI can tune scoring without redeploy.

Current scoring axes:

- **Technology**: primary (strong weight) and secondary (light weight) matches;
  malus when an offer requires a primary tech outside the profile.
- **Remote/hybrid**: weighted preference ranking (`remote`/`hybrid`/`on_site`);
  for hybrid offers, allowed cities and minimum remote-days-per-week.

## Run locally

Prerequisites:

- [mise](https://mise.jdx.dev/) (pins Ruby 4.0 + Node 22 — see [mise.toml](mise.toml))
- Docker + Docker Compose (for Postgres, Redis, RustFS)
- An OpenAI-compatible API key (`OPENAI_API_KEY` or `LLM_API_KEY`)

```bash
# infra services
docker compose up -d postgres redis rustfs

# Ruby + Node deps
bundle install
bundle exec lefthook install -f
npm ci

# database
bin/rails db:create db:migrate

# everything: Rails + Sidekiq + Vite + GraphQL codegen watchers
bin/dev
```

Open <http://localhost:3000>.

`Procfile.dev` starts:
- `web` — Rails server (port 3000)
- `sidekiq` — background pipeline
- `vite` — Vite dev server
- `gql-schema` — watches Ruby GraphQL files → regenerates `tmp/schema.graphql`
- `gql-types` — watches frontend TS/TSX → regenerates `app/frontend/graphql/generated.ts`

Copy [.env.example](.env.example) to `.env` and fill in API keys.

## Test

```bash
bundle exec rspec            # backend (RSpec + FactoryBot)
COVERAGE=true bundle exec rspec   # with SimpleCov branch coverage report
npm run test:unit            # frontend (Vitest, jsdom)
npm run test:storybook       # frontend (Vitest browser + Playwright)
npx tsc --noEmit             # type check
```

CI runs all of the above in parallel jobs plus Brakeman, bundler-audit, and
RuboCop. Coverage report is uploaded as a 14-day-retention artifact.

## Project layout

```
app/
├── channels/                 # ActionCable (live sourcing status)
├── controllers/              # GraphQL endpoint + SPA shell
├── frontend/                 # React app (Vite-mounted)
│   ├── app.tsx               # router
│   ├── components/{ui,layout}/ # shared components + shadcn primitives
│   ├── features/{offers,profile,sourcing}/ # feature-scoped UI
│   ├── graphql/              # codegen output + queries
│   └── pages/                # route entry points
├── graphql/
│   ├── mutations/            # launchDiscovery, recomputeOfferScores, updateScoringProfile
│   ├── subscriptions/        # sourcingStatus
│   └── types/queries/        # jobOffers, jobOffer, dashboardMetrics, providers, scoringProfile, technologies
├── jobs/sourcing/            # ActiveJob: Discovery / Fetch / Analyze / Enrich / Scoring / LaunchDiscovery
├── models/job_offer.rb       # single domain model (dry-schema validated jsonb)
├── services/sourcing/        # pipeline contract + 6 providers
└── subscribers/sourcing/     # ActiveSupport::Notifications hooks (offer_discovered, offer_fetched, …)

db/migrate/                   # schema migrations (9)
spec/                         # RSpec, FactoryBot, Vitest stories share the storybook runner
```

## License

[PolyForm Noncommercial 1.0.0](./LICENSE) — source-available for noncommercial
use (research, learning, personal projects, public-interest organizations).
Commercial use requires permission.
