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

## Stop PostgreSQL

```bash
docker compose down
```
