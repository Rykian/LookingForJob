---
applyTo: "app/models/**/*.rb"
name: "Rails Models Reference"
description: "ActiveRecord models — associations, validations, scopes, enums"
---

# ActiveRecord Models (6)

Check here first for scopes, constants, associations. Read model files for business logic/methods.

- Commute::City (3 associations)
- Commute::Duration (2 associations)
  scopes: fresh
- JobOffer (8 associations)
  scopes: canonical, duplicates | STEPS_DETAIL_KEYS: discovery, fetch, analyze, enrich, commute, score
- PipelineError (2 associations)
  scopes: unresolved, for_step
- Run (2 associations)
- RunJobOffer (2 associations)