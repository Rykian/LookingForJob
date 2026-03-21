# LookingForJob

Backend API Rails for the LookingForJob rebuild.

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
