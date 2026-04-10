---
applyTo: "**/*"
name: "Rails Project Overview"
description: "Rails version, database, models, routes, gems, architecture patterns"
---

# LookingForJob — Overview

Rails 8.1.3 | Ruby 4.0.2

- Database: static_parse — 4 tables
- Models: 1
- Routes: 21
- jobs: sidekiq
- api: graphql
- database: pg, solid_cache, solid_cable
- files: activestorage, aws-sdk-s3
- testing: rspec-rails, minitest
- deploy: kamal, thruster
- API-only mode (no views/assets)
- GraphQL API (app/graphql/)
- Service objects pattern (app/services/)
- concerns_models
- concerns_controllers
- API: API-only, GraphQL
- Storage: ActiveStorage (1 models with attachments)
- Assets: none, vite, tailwindcss

Use MCP tools for detailed data. Start with `detail:"summary"`.