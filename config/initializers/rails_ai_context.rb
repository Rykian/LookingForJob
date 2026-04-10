# frozen_string_literal: true

if defined?(RailsAiContext)
  return unless defined?(RailsAiContext)

  RailsAiContext.configure do |config|
    # ── AI Tools ──────────────────────────────────────────────────────
    # Which AI tools to generate context files for (selected during install)
    # Run `rails generate rails_ai_context:install` to change selection
    config.ai_tools = %i[copilot]

    # Tool invocation mode:
    #   :mcp — MCP primary + CLI fallback (default, requires `rails ai:serve`)
    #   :cli — CLI only (no MCP server needed, uses `rails 'ai:tool[NAME]'`)
    config.tool_mode = :mcp   # MCP primary + CLI fallback

    # ── Introspection ─────────────────────────────────────────────────
    # Introspector preset:
    #   :full     — all 33 introspectors (default)
    #   :standard — 19 core introspectors (schema, models, routes, jobs, gems,
    #               conventions, controllers, tests, migrations, stimulus,
    #               view_templates, design_tokens, config, components)
    # config.preset = :full

    # Context mode: :compact (default, ≤150 lines) or :full (dumps everything)
    # config.context_mode = :compact

    # Max lines for CLAUDE.md in compact mode
    # config.claude_max_lines = 150

    # Whether to generate root files (CLAUDE.md, AGENTS.md, etc.)
    # Set false to only generate split rules (.claude/rules/, .cursor/rules/, etc.)
    # config.generate_root_files = true

    # Anti-Hallucination Protocol: 6-rule verification section embedded in every
    # generated context file. Forces AI to verify facts before writing code.
    # Default: true. Set false to skip the protocol entirely.
    # config.anti_hallucination_rules = true

    # ── Models & Filtering ────────────────────────────────────────────
    # Models to exclude from introspection
    # config.excluded_models += %w[AdminUser InternalThing]

    # Controllers to exclude from listings
    # config.excluded_controllers += %w[Admin::BaseController]

    # Route prefixes to hide with app_only filter
    # config.excluded_route_prefixes += %w[sidekiq/]

    # ── MCP Server ────────────────────────────────────────────────────
    # Cache TTL in seconds for introspection data
    # config.cache_ttl = 60

    # Max characters for any single tool response (safety net)
    # config.max_tool_response_chars = 200_000

    # Live reload: auto-invalidate MCP tool caches on file changes
    #   :auto — enable if `listen` gem is available (default)
    #   true  — enable, raise if `listen` gem is missing
    #   false — disable entirely
    # config.live_reload = :auto

    # Auto-mount HTTP MCP endpoint (for HTTP transport)
    # config.auto_mount = false
    # config.http_path = "/mcp"
    # config.http_port = 6029

    # ── File Size Limits ──────────────────────────────────────────────
    # Increase for larger projects
    # config.max_file_size = 5_000_000         # Per-file read (5MB)
    # config.max_test_file_size = 1_000_000    # Test file read (1MB)
    # config.max_schema_file_size = 10_000_000 # schema.rb parse (10MB)
    # config.max_view_total_size = 10_000_000  # Aggregated view content (10MB)
    # config.max_view_file_size = 1_000_000    # Per-view file (1MB)
    # config.max_search_results = 200          # Max search results per call
    # config.max_validate_files = 50           # Max files per validate call

    # ── Extensibility ─────────────────────────────────────────────────
    # Register additional MCP tool classes alongside the 39 built-in tools
    # config.custom_tools = [MyApp::CustomTool]

    # Exclude specific built-in tools by name
    # config.skip_tools = %w[rails_security_scan]

    # ── Security ──────────────────────────────────────────────────────
    # Paths excluded from code search
    # config.excluded_paths += %w[vendor/cache]

    # File patterns blocked from search and read tools
    # config.sensitive_patterns += %w[config/secrets.yml]

    # ── Search ────────────────────────────────────────────────────────
    # File extensions for fallback search (when ripgrep unavailable)
    # config.search_extensions = %w[rb js erb yml yaml json ts tsx vue svelte haml slim]

    # Where to look for concern source files
    # config.concern_paths = %w[app/models/concerns app/controllers/concerns]

    # ── Frontend Framework Detection ─────────────────────────────────
    # Auto-detected from package.json, config/vite.json, etc. Override only if needed.
    # config.frontend_paths = ["app/frontend", "../web-client"]
  end
end
