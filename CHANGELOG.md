## [unreleased]

### 🚀 Features

- *(db)* Add job_offers schema and domain model
- *(application)* Add sourcing discovery and fetch pipeline skeleton
- *(application)* Add analyze and enrich jobs pipeline
- *(crawler)* Add provider-based steps with linkedin playwright defaults
- *(config)* Centralize llm settings for enrich step
- *(linkedin)* Add session persistence for authenticated searches
- *(linkedin)* Enhance job posting extraction with JSON-LD support and improve salary parsing
- *(sourcing)* Add launch discovery job driven by KEYWORDS and WORK_MODE
- *(sourcing)* Add profile-driven scoring and city extraction
- *(ui)* Add Vite React SPA with vite_rails
- *(graphql)* Add GraphQL API surface with Apollo Client wiring
- *(ui)* Wire phase 3 screens to GraphQL
- *(graphql)* Integrate GraphQL Code Generator for typed operations
- *(offers)* Add GraphQL-backed sorting for offers list
- *(sourcing)* Add bulk offer score recompute action
- *(frontend)* Add original offer link from offers list
- *(sourcing)* Redesign scoring v2 and hybrid location gating
- Add sidekiq process to Procfile.dev
- *(graphql)* Add url field to JobOffer type in JobOffersQuery
- *(sidekiq)* Mount web ui with production basic auth
- *(nav)* Add external link to sidekiq ui
- *(offers)* Improve external offer links in list and detail
- *(profile)* Enhance scoring profile schema and validation rules
- *(sourcing)* Split discovery lifecycle into continuable steps
- *(sourcing)* Migrate pipeline timestamps to steps_details
- *(sourcing)* Persist html_content as ActiveStorage attachment
- *(storage)* Configure RustFS as S3-compatible ActiveStorage backend
- *(sourcing)* Add step versioning to skip completed steps
- *(sourcing)* Align location mode enum across pipeline
- Enhance job offers page with search parameters and location mode updates
- *(sourcing)* Normalize technologies on enrich and migrate to array columns
- *(graphql)* Add provider enum and providers query
- *(sourcing)* Add base enrich step and playwright support module
- *(sourcing)* Add france travail provider and consolidate playwright sourcing improvements
- *(sourcing)* Enhance sourcing provider creation with API decision workflow and validation improvements
- *(sourcing)* Add Cadremploi provider, consolidate HTML cleaning, optimize LinkedIn expansion
- *(sourcing)* Enhance session management and anti-bot detection for Playwright crawling
- *(sourcing)* Share provider session login validation flow
- *(sourcing)* Use scoring profile defaults for discovery keywords and work modes
- *(sourcing)* Add Hellowork provider integration with discovery, fetch, analyze, and enrich steps
- *(graphql)* Enhance jobOffers query with additional filters for firstSeen and lastSeen timestamps
- Integrate Lefthook for Git hooks management and add RuboCop pre-commit hook
- *(infra)* Run biome in pre-commit hook
- *(sourcing)* Add APEC provider
- *(sourcing)* Reject irrelevant offers before enrich and score
- *(frontend)* Add Storybook 10 with component stories and interaction tests
- Add example environment configuration file
- *(sourcing)* Display status (queue count, activity) on frontend
- *(offers)* Display technology icons in job listing
- *(offers)* Add English level required filter
- *(frontend)* Add missing technology icons (Java, Elixir, Elm, Scala, Sidekiq)
- *(sourcing-linkedin)* Rewrite LinkedIn provider using plain HTTP (Faraday)
- *(sourcing)* Add sidekiq-throttled for LinkedIn rate limit isolation
- *(sourcing)* Centralize pipeline advancement with version-checked deduplication
- *(sourcing)* Add commute duration pipeline with Mapbox geocoding and caching

### 🐛 Bug Fixes

- *(sourcing)* Stop linkedin pagination on partial page instead of any result
- *(sourcing)* Remove deprecated job offer fields
- *(linkedin)* Clean discovered URLs by stripping query params and fragments
- *(sourcing)* Improve linkedin discovery and city matching
- *(offers)* Default UI order by score desc
- *(analyze)* Strip linkedin shell noise from location city parsing
- *(linkedin)* Expand job descriptions during fetch
- *(sourcing)* Validate LinkedIn HTML before storing and wait for job markers in headless mode
- *(sourcing-linkedin)* Restrict location_mode detection to top-card selectors and patterns only
- *(sourcing-linkedin)* Fail loudly on shell, login, or empty discovery pages
- *(graphql)* Use ProviderRegistry.sources and finalize providers enum for sourcing filter
- *(sourcing-wttj)* Fix AnalyzeStep class structure, helpers, and selector bugs for robust extraction and testability
- *(sourcing-linkedin)* Simplify enrich inheritance and use dynamic playwright version
- *(sourcing)* Refactor wttj enrich inheritance and improve description selector
- *(sourcing)* Allow filtering by multiple sources in job offer search
- *(sourcing)* Align wttj location mode and enrichment fields
- *(sourcing)* Avoid duplicate discovery for unsupported work mode sources
- *(ci)* Failing because of an empty checksum in bundle
- *(sourcing-france_travail)* Remove false-positive auth wall detection (BLOCKED_PATTERN) in fetch step; only check for content selector
- *(sourcing-linkedin)* Race all job marker selectors in parallel for fetch, reducing worst-case wait from 60s to 12s
- *(sourcing)* Stop hellowork pagination on empty trailing pages
- *(offers)* Update default values for seenField and datePreset parameters
- *(linkedin)* Provider-specific persisted attributes and robust topcard fallback
- *(sourcing)* Install Playwright Chromium for backend integration specs [ci]
- *(sourcing)* Disabling WTTJ since it's not browsable anymore
- *(offers)* Refresh list when sourcing completes
- *(offers)* Refresh frontend not working when table is empty
- *(sourcing)* Running count fixed
- *(sourcing)* Empty results are not handled on France-Travail

### 💼 Other

- *(queue)* Switch to sidekiq and bootstrap rspec
- *(db)* Add docker compose postgres setup
- *(deps)* Add dotenv-rails for local env loading
- *(deps)* Bump puma from 7.2.0 to 8.0.0
- *(deps)* Bump playwright-ruby-client from 1.58.1 to 1.59.0 (#9)
- *(deps)* Bump aws-sdk-s3 from 1.218.0 to 1.219.0 (#10)
- *(deps)* Bump actions/cache from 4 to 5
- *(deps)* Bump actions/setup-node from 4 to 6

### 🚜 Refactor

- *(graphql)* Move frontend operations back into TSX files
- Mutualize GraphQL config in TypeScript and DRY codegen setup
- *(graphql)* Split queries into their own files
- *(sourcing)* Event-driven pipeline for offer jobs
- Removing configuration for linkedin's timeout and cadremploi session path
- *(frontend)* Reorganize frontend by feature folders
- *(graphql)* Split JobOffersQuery and drop Query suffix
- *(sourcing)* Upsert discovered offers atomically
- *(sourcing)* Split cadremploi analyze step into per-field parsers
- *(sourcing)* Split hellowork analyze step into per-field parsers
- *(sourcing)* Lift FetchStep init/call boilerplate into base class

### 📚 Documentation

- *(graphql)* Tighten dev workflow and document API contracts
- Update AGENTS.md with allowed conventional commit scopes and selection rules
- Deduplicate generic guidelines from user CLAUDE in AGENTS
- *(sourcing)* Add provider documentation and update AGENTS guidelines
- Update README to include Sidekiq in local run command and clarify Node.js requirement
- Rewrite README with pitch, architecture, stack, and badges

### ⚡ Performance

- *(db)* Index job_offers columns used in list filters and sorts

### 🧪 Testing

- *(db)* Add job_offer model contract specs
- *(application)* Add sourcing job specs
- *(application)* Add analyze and enrich job specs
- *(crawler)* Cover provider routing and linkedin step contracts
- *(crawler)* Add llm config and enrich wiring specs
- *(model)* Migrate JobOffer specs to shoulda-matchers
- *(graphql)* Add request specs for core queries and mutations
- *(sourcing-linkedin)* Avoid removing linkedin session during test execution
- *(ui)* Add vitest configuration for unit tests & storybook
- Fix CI execution by adding a default .env

### ⚙️ Miscellaneous Tasks

- *(bootstrap)* Initialize rails api project
- *(docs)* Tighten agents guide with pr review checklist
- *(infra)* Add redis service to compose and use default queue
- Add graphql:watch process to bin/dev
- *(linkedin)* Move session storage to data
- Ignore Playwright MCP files
- *(tooling)* Add Biome for linting and formatting
- Update RuboCop configuration and VSCode settings for Ruby formatting
- *(docs)* Add or update sourcing-provider-creation skill
- Update gems
- Remove outdated sourcing-provider-creation skill file
- Add rails-ai-context integration and configuration
- Upgrade TypeScript to 6.0.3
- Remove old screenshots from tests
- Update AI context and agent documentation
- Improve Claude support
- *(frontend)* Drop dead Vite scaffolding entrypoint
- Add PolyForm Noncommercial 1.0.0 LICENSE
- *(sourcing)* Strip stale WTTJ TODO comments
- *(infra)* Add SimpleCov with branch coverage
- *(infra)* Adopt factory_bot for spec data setup
- *(frontend)* Enable tsconfig strict + noUnused* flags
- *(infra)* Add nightly scrapers smoke workflow
