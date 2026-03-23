# LookingForJob

Backend API Rails for the LookingForJob rebuild.

## Developer workflow

### Run locally

Use one command to run Rails, Vite, and GraphQL schema/type generation in watch mode:

```bash
bin/dev
```

`Procfile.dev` starts:
- `web`: Rails server on port 3000
- `vite`: Vite dev server
- `gql-schema`: watches Ruby GraphQL schema files and refreshes `tmp/schema.graphql`
- `gql-types`: watches frontend TS/TSX files and regenerates `app/frontend/graphql/generated.ts`

### GraphQL code generation

```bash
npm run graphql:schema
npm run graphql:types
```

- `graphql:schema` exports SDL from `::LookingForJobSchema` into `tmp/schema.graphql`
- `graphql:types` runs schema export then GraphQL Code Generator
- codegen config is in `codegen.ts`

### Where GraphQL operations live

Frontend queries and mutations are defined inline in TSX pages, then codegen plucks those operations:

- `app/frontend/pages/dashboard.tsx`
- `app/frontend/pages/offers/index.tsx`
- `app/frontend/pages/offers/detail.tsx`
- `app/frontend/pages/sourcing.tsx`
- `app/frontend/pages/profile.tsx`

Generated operation/types output:

- `app/frontend/graphql/generated.ts`

## Prerequisites

- Ruby 4.0+
- Bundler
- Docker + Docker Compose

## Start PostgreSQL with Docker Compose

```bash
docker compose up -d postgres
```

## Setup the app

```bash
bundle install
bin/rails db:create db:migrate
```

## Run tests

```bash
bundle exec rspec
```

Run type checks:

```bash
npx tsc --noEmit
```

## Profile-Driven Scoring (V1)

Job offers are scored after enrichment by `Sourcing::ScoringJob`, using a JSON profile file at `data/scoring_profile.json`.

### Profile schema

```json
{
	"technology": {
		"primary": ["ruby", "rails"],
		"secondary": ["postgresql", "sidekiq"]
	},
	"remote_hybrid": {
		"importance": "high",
		"preferred_modes": ["yes", "hybrid"],
		"hybrid": {
			"allowed_cities": ["Nantes", "Rennes", "Laval", "Angers"]
		}
	}
}
```

### V1 scoring rules

- Criteria: technology and remote/hybrid only.
- Technology importance is implicit by placement: primary technologies have stronger effect than secondary technologies.
- Bonus is applied when all user primary technologies are present.
- Malus is applied when offer primary technologies include technologies outside the user stack.
- Remote/hybrid uses preference importance (`low`, `medium`, `high`) and preferred modes.
- For hybrid offers, city is matched against `allowed_cities`.
- For hybrid offers, score increases monotonically with remote days (`hybrid_remote_days_min_per_week`): more remote days always score higher.

### Failure behavior

- Missing/invalid profile fails the scoring job loudly with explicit log context.

## Stop PostgreSQL

```bash
docker compose down
```
