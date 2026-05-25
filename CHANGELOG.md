# Changelog

All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

---
## [0.1.0] - 2026-05-24

### Bug Fixes

- **(analyze)** strip linkedin shell noise from location city parsing - ([b49cef4](https://github.com/Rykian/LookingForJob/commit/b49cef4fc4c6b2b51548d21f9db7af686cec02c7)) - Thibault Lacroux
- **(ci)** failing because of an empty checksum in bundle - ([5d0198f](https://github.com/Rykian/LookingForJob/commit/5d0198facfcda9618dc2ccc7aaff050abe558a32)) - Thibault Lacroux
- **(graphql)** use ProviderRegistry.sources and finalize providers enum for sourcing filter - ([e4c22f5](https://github.com/Rykian/LookingForJob/commit/e4c22f5ec33e23c07af11697b4dd8a1a4ac7abc5)) - Thibault Lacroux
- **(linkedin)** clean discovered URLs by stripping query params and fragments - ([9eab54e](https://github.com/Rykian/LookingForJob/commit/9eab54e95d2ebba42fc6b55eec844838c7606fb6)) - Thibault Lacroux
- **(linkedin)** expand job descriptions during fetch - ([bd1f4b1](https://github.com/Rykian/LookingForJob/commit/bd1f4b1d66ea7e7815ae8b6fcc3e2d5c497cf2a6)) - Thibault Lacroux
- **(linkedin)** provider-specific persisted attributes and robust topcard fallback - ([c7e3966](https://github.com/Rykian/LookingForJob/commit/c7e3966a8b93980ebb37af0b289456ae9b4ab390)) - Thibault Lacroux
- **(offers)** default UI order by score desc - ([7b20ffb](https://github.com/Rykian/LookingForJob/commit/7b20ffb05de0b70ee752971065ef17c7f3e7cb0c)) - Thibault Lacroux
- **(offers)** update default values for seenField and datePreset parameters - ([554baed](https://github.com/Rykian/LookingForJob/commit/554baed1b10e8a7bc275e287fd49b825a0317842)) - Thibault Lacroux
- **(offers)** refresh list when sourcing completes - ([593548f](https://github.com/Rykian/LookingForJob/commit/593548fa7feca401adb39647757dd7d082c2a7a9)) - Thibault Lacroux
- **(offers)** refresh frontend not working when table is empty - ([8e03a3a](https://github.com/Rykian/LookingForJob/commit/8e03a3a40b8d294d586ab527389bf029819920b3)) - Thibault Lacroux
- **(sourcing)** stop linkedin pagination on partial page instead of any result - ([4cf569f](https://github.com/Rykian/LookingForJob/commit/4cf569f5f1af95947aa30165d62505c21abf95c9)) - Thibault Lacroux
- **(sourcing)** remove deprecated job offer fields - ([b73b9da](https://github.com/Rykian/LookingForJob/commit/b73b9da880405fc007dd2fb3f927e7c22cc78f9a)) - Thibault Lacroux
- **(sourcing)** improve linkedin discovery and city matching - ([0d72e8f](https://github.com/Rykian/LookingForJob/commit/0d72e8fb1a26332bebe19175bb3e393282c8c458)) - Thibault Lacroux
- **(sourcing)** validate LinkedIn HTML before storing and wait for job markers in headless mode - ([7cedfda](https://github.com/Rykian/LookingForJob/commit/7cedfda3a93c8479728bf09a0906f6dc609e54db)) - Thibault Lacroux
- **(sourcing)** refactor wttj enrich inheritance and improve description selector - ([62dd982](https://github.com/Rykian/LookingForJob/commit/62dd982c07d6a84fd2ba4c07278245e13128c5bc)) - Thibault Lacroux
- **(sourcing)** allow filtering by multiple sources in job offer search - ([5408db5](https://github.com/Rykian/LookingForJob/commit/5408db5d279a3d71bcb553bd2e951fb6dc327607)) - Thibault Lacroux
- **(sourcing)** align wttj location mode and enrichment fields - ([787cd0b](https://github.com/Rykian/LookingForJob/commit/787cd0b8967a8bd674fb917982a20a6c3592c278)) - Thibault Lacroux
- **(sourcing)** avoid duplicate discovery for unsupported work mode sources - ([13c81dd](https://github.com/Rykian/LookingForJob/commit/13c81dd096400fe78520839a55af9688952c4dc8)) - Thibault Lacroux
- **(sourcing)** stop hellowork pagination on empty trailing pages - ([a972aed](https://github.com/Rykian/LookingForJob/commit/a972aed3fea3bf44d0b0e4e9a3895f248d4d2f20)) - Thibault Lacroux
- **(sourcing)** install Playwright Chromium for backend integration specs [ci] - ([0110a9b](https://github.com/Rykian/LookingForJob/commit/0110a9ba31802cfb22f1bab4c27b2cc32cc754c8)) - Thibault Lacroux
- **(sourcing)** disabling WTTJ since it's not browsable anymore - ([bccd341](https://github.com/Rykian/LookingForJob/commit/bccd341f8836b116b3a73c2f17ee79598fb66000)) - Thibault Lacroux
- **(sourcing)** running count fixed - ([afed37d](https://github.com/Rykian/LookingForJob/commit/afed37d01f6b34cb180a55bd4ec1820e92e30594)) - Thibault Lacroux
- **(sourcing)** empty results are not handled on France-Travail - ([7ff898a](https://github.com/Rykian/LookingForJob/commit/7ff898a48dbbc248c4d8e2485b0f1e432e9b47e0)) - Thibault Lacroux
- **(sourcing-france_travail)** remove false-positive auth wall detection (BLOCKED_PATTERN) in fetch step; only check for content selector - ([71aac20](https://github.com/Rykian/LookingForJob/commit/71aac2009f28b4b5df20199938637ac05c74036d)) - Thibault Lacroux
- **(sourcing-linkedin)** restrict location_mode detection to top-card selectors and patterns only - ([0f9471f](https://github.com/Rykian/LookingForJob/commit/0f9471fcb6804c52f20e89a05a69c853d73da84b)) - Thibault Lacroux
- **(sourcing-linkedin)** fail loudly on shell, login, or empty discovery pages - ([a5e74cf](https://github.com/Rykian/LookingForJob/commit/a5e74cfa7eebf3990c7292845dfb8e8961ddc36c)) - Thibault Lacroux
- **(sourcing-linkedin)** simplify enrich inheritance and use dynamic playwright version - ([d1ef4fc](https://github.com/Rykian/LookingForJob/commit/d1ef4fc26d814419dc783cdb3f98ad84f276bff1)) - Thibault Lacroux
- **(sourcing-linkedin)** race all job marker selectors in parallel for fetch, reducing worst-case wait from 60s to 12s - ([031e8ca](https://github.com/Rykian/LookingForJob/commit/031e8cab2d918f62725335948e0b99b4ad2fe8f3)) - Thibault Lacroux
- **(sourcing-wttj)** fix AnalyzeStep class structure, helpers, and selector bugs for robust extraction and testability - ([a097850](https://github.com/Rykian/LookingForJob/commit/a097850133c9320c404b8421c82b9b8d01ffdc30)) - Thibault Lacroux

### Documentation

- **(graphql)** tighten dev workflow and document API contracts - ([3a6a1a3](https://github.com/Rykian/LookingForJob/commit/3a6a1a3001e3a2b81d9fabe955214cc957375de9)) - Thibault Lacroux
- **(sourcing)** add provider documentation and update AGENTS guidelines - ([e70214c](https://github.com/Rykian/LookingForJob/commit/e70214c19ca8fb3135baa89eadc7c319c4d43ce9)) - Thibault Lacroux
- update AGENTS.md with allowed conventional commit scopes and selection rules - ([412819e](https://github.com/Rykian/LookingForJob/commit/412819ea1f692b5a66d5c0be0ac98a03bbd69261)) - Thibault Lacroux
- deduplicate generic guidelines from user CLAUDE in AGENTS - ([3e83278](https://github.com/Rykian/LookingForJob/commit/3e83278c050374c3468c059f3d4c69291c7454f8)) - Thibault Lacroux
- update README to include Sidekiq in local run command and clarify Node.js requirement - ([09c9760](https://github.com/Rykian/LookingForJob/commit/09c97609c0cce54976b820645dbc192354b21eb9)) - Thibault Lacroux
- rewrite README with pitch, architecture, stack, and badges - ([26b2c5c](https://github.com/Rykian/LookingForJob/commit/26b2c5cb2ab1f1eae9e46aa60b17377a8425a39f)) - Thibault Lacroux

### Features

- **(application)** add sourcing discovery and fetch pipeline skeleton - ([fa8f982](https://github.com/Rykian/LookingForJob/commit/fa8f982537f4baf77a68e830c7d344266a85482a)) - Thibault Lacroux
- **(application)** add analyze and enrich jobs pipeline - ([4aac72a](https://github.com/Rykian/LookingForJob/commit/4aac72a60dffcfd0377436be025b99279eeb0cdb)) - Thibault Lacroux
- **(config)** centralize llm settings for enrich step - ([eb856d7](https://github.com/Rykian/LookingForJob/commit/eb856d76f690c1068a6855bb42169e181cf9c84b)) - Thibault Lacroux
- **(crawler)** add provider-based steps with linkedin playwright defaults - ([c393d73](https://github.com/Rykian/LookingForJob/commit/c393d7390bae6e0996b59dadfdf85d70961d726b)) - Thibault Lacroux
- **(db)** add job_offers schema and domain model - ([744078b](https://github.com/Rykian/LookingForJob/commit/744078b97b8ec33a7edff9fa9e7cc6302a7a6dea)) - Thibault Lacroux
- **(frontend)** add original offer link from offers list - ([53af4ea](https://github.com/Rykian/LookingForJob/commit/53af4ea67348dedfe091f6e7d54ebab8220a410f)) - Thibault Lacroux
- **(frontend)** add Storybook 10 with component stories and interaction tests - ([0cf13c2](https://github.com/Rykian/LookingForJob/commit/0cf13c2a92a0fa0e43f8be34a332ce1c7cfaa24c)) - Thibault Lacroux
- **(frontend)** add missing technology icons (Java, Elixir, Elm, Scala, Sidekiq) - ([2173520](https://github.com/Rykian/LookingForJob/commit/21735205fc8a3f2797de1f3e24e160d60213c6ef)) - Thibault Lacroux
- **(graphql)** add GraphQL API surface with Apollo Client wiring - ([ba2def0](https://github.com/Rykian/LookingForJob/commit/ba2def036f369962b481289caedd0e027881cf5c)) - Thibault Lacroux
- **(graphql)** integrate GraphQL Code Generator for typed operations - ([6bf6ac0](https://github.com/Rykian/LookingForJob/commit/6bf6ac0e394ffc94994c936c72ce0e57e89f6755)) - Thibault Lacroux
- **(graphql)** add url field to JobOffer type in JobOffersQuery - ([497e2fa](https://github.com/Rykian/LookingForJob/commit/497e2fa01f817dc662deb9ddf6f5725951997338)) - Thibault Lacroux
- **(graphql)** add provider enum and providers query - ([f6e369c](https://github.com/Rykian/LookingForJob/commit/f6e369c1ac1048aded6da6f608da91294877fd85)) - Thibault Lacroux
- **(graphql)** enhance jobOffers query with additional filters for firstSeen and lastSeen timestamps - ([b2a225f](https://github.com/Rykian/LookingForJob/commit/b2a225f17b57f5919d7dff4fe0b483d963f8ce62)) - Thibault Lacroux
- **(infra)** run biome in pre-commit hook - ([701b1f2](https://github.com/Rykian/LookingForJob/commit/701b1f2261f43f95246d628c960cfda81aa1fbaa)) - Thibault Lacroux
- **(linkedin)** add session persistence for authenticated searches - ([7f56279](https://github.com/Rykian/LookingForJob/commit/7f562794f863761bc32dce3f64f8bee9b6d50061)) - Thibault Lacroux
- **(linkedin)** enhance job posting extraction with JSON-LD support and improve salary parsing - ([801434a](https://github.com/Rykian/LookingForJob/commit/801434a673222538d505d096f7f01691d007f952)) - Thibault Lacroux
- **(nav)** add external link to sidekiq ui - ([5e5ea3f](https://github.com/Rykian/LookingForJob/commit/5e5ea3fcf954d03951371361b4b5f760a1185202)) - Thibault Lacroux
- **(offers)** add GraphQL-backed sorting for offers list - ([b8b2443](https://github.com/Rykian/LookingForJob/commit/b8b24431f3d33a43d8b2a9ceb7a1d17a032b501c)) - Thibault Lacroux
- **(offers)** improve external offer links in list and detail - ([01bc102](https://github.com/Rykian/LookingForJob/commit/01bc102695d8ee242dbb3a36ec3c823a7119f464)) - Thibault Lacroux
- **(offers)** display technology icons in job listing - ([0b5e439](https://github.com/Rykian/LookingForJob/commit/0b5e439707a2832ea84cc1e7e971b8e07e65b8c6)) - Thibault Lacroux
- **(offers)** add English level required filter - ([c61d400](https://github.com/Rykian/LookingForJob/commit/c61d400946ed542c01e07afa0488086c35210559)) - Thibault Lacroux
- **(profile)** enhance scoring profile schema and validation rules - ([6239afd](https://github.com/Rykian/LookingForJob/commit/6239afdc3342d6140632d73d30fb858ba3a3f08f)) - Thibault Lacroux
- **(sidekiq)** mount web ui with production basic auth - ([7bd28f5](https://github.com/Rykian/LookingForJob/commit/7bd28f50a80bf2451e268ad0f4c09af1e7595ecd)) - Thibault Lacroux
- **(sourcing)** add launch discovery job driven by KEYWORDS and WORK_MODE - ([d345bfb](https://github.com/Rykian/LookingForJob/commit/d345bfbe51c499041849efaedb840842a2869b28)) - Thibault Lacroux
- **(sourcing)** add profile-driven scoring and city extraction - ([80b8782](https://github.com/Rykian/LookingForJob/commit/80b87825cae9a6587c6777184c596eb69e15596d)) - Thibault Lacroux
- **(sourcing)** add bulk offer score recompute action - ([187d8f9](https://github.com/Rykian/LookingForJob/commit/187d8f9fa75c36532eee8f3753c31e968959ff31)) - Thibault Lacroux
- **(sourcing)** redesign scoring v2 and hybrid location gating - ([e22241e](https://github.com/Rykian/LookingForJob/commit/e22241e0e1339b7bf1a6ddc84098549439940291)) - Thibault Lacroux
- **(sourcing)** split discovery lifecycle into continuable steps - ([dbbfa85](https://github.com/Rykian/LookingForJob/commit/dbbfa85ee2cd2a468c3eda9fcd6d2a9d4d1da8d3)) - Thibault Lacroux
- **(sourcing)** migrate pipeline timestamps to steps_details - ([80b560c](https://github.com/Rykian/LookingForJob/commit/80b560c3740a6b9984aa3f2467e1b4ef4f0f8c2a)) - Thibault Lacroux
- **(sourcing)** persist html_content as ActiveStorage attachment - ([0a9e8bc](https://github.com/Rykian/LookingForJob/commit/0a9e8bc79745e1e47cf8c6a342f59ae8336fdc70)) - Thibault Lacroux
- **(sourcing)** add step versioning to skip completed steps - ([fbd5121](https://github.com/Rykian/LookingForJob/commit/fbd51214b1ebf39013f162c08c4d057ce8c28ce4)) - Thibault Lacroux
- **(sourcing)** align location mode enum across pipeline - ([7bd4731](https://github.com/Rykian/LookingForJob/commit/7bd47314ccdada0446141ebcf82a73eb1611d19c)) - Thibault Lacroux
- **(sourcing)** normalize technologies on enrich and migrate to array columns - ([8832833](https://github.com/Rykian/LookingForJob/commit/88328330bd3ea0519f476b85567560bbd8586e6f)) - Thibault Lacroux
- **(sourcing)** add base enrich step and playwright support module - ([dc3e76c](https://github.com/Rykian/LookingForJob/commit/dc3e76cdf2d456387462b67024192de85c896dd8)) - Thibault Lacroux
- **(sourcing)** add france travail provider and consolidate playwright sourcing improvements - ([efc0df2](https://github.com/Rykian/LookingForJob/commit/efc0df2ca58b8165c997ee068e44f3ae72165cdd)) - Thibault Lacroux
- **(sourcing)** enhance sourcing provider creation with API decision workflow and validation improvements - ([5278334](https://github.com/Rykian/LookingForJob/commit/5278334803438509c93f423dae9a68d532853a09)) - Thibault Lacroux
- **(sourcing)** add Cadremploi provider, consolidate HTML cleaning, optimize LinkedIn expansion - ([461af1d](https://github.com/Rykian/LookingForJob/commit/461af1dde7e5674f39bd4e122cc0f31fa432ce5c)) - Thibault Lacroux
- **(sourcing)** enhance session management and anti-bot detection for Playwright crawling - ([b21014e](https://github.com/Rykian/LookingForJob/commit/b21014e8b1381f9819bdf00460170592904b76ee)) - Thibault Lacroux
- **(sourcing)** share provider session login validation flow - ([5230634](https://github.com/Rykian/LookingForJob/commit/523063434d37df0281d6c04a5e35b19ab72cd3b1)) - Thibault Lacroux
- **(sourcing)** use scoring profile defaults for discovery keywords and work modes - ([c6e2d90](https://github.com/Rykian/LookingForJob/commit/c6e2d90cc27f833b3cc80dd8f43b995ddd8434d6)) - Thibault Lacroux
- **(sourcing)** add Hellowork provider integration with discovery, fetch, analyze, and enrich steps - ([ff95fae](https://github.com/Rykian/LookingForJob/commit/ff95fae0f32c78537ceb095bc5056423d7c74b47)) - Thibault Lacroux
- **(sourcing)** add APEC provider - ([79fde9d](https://github.com/Rykian/LookingForJob/commit/79fde9daa9e7dc15d2d78ffedea23e69e564ebf1)) - Thibault Lacroux
- **(sourcing)** reject irrelevant offers before enrich and score - ([930bb60](https://github.com/Rykian/LookingForJob/commit/930bb60a10de10c47268bedf00311db48f971fe8)) - Thibault Lacroux
- **(sourcing)** display status (queue count, activity) on frontend - ([d195b67](https://github.com/Rykian/LookingForJob/commit/d195b67cbe3a185645899a05417d1a21f8c1da38)) - Thibault Lacroux
- **(sourcing)** add sidekiq-throttled for LinkedIn rate limit isolation - ([2783e66](https://github.com/Rykian/LookingForJob/commit/2783e66df68087e2be6b5b05fe7df852269cdaab)) - Thibault Lacroux
- **(sourcing)** centralize pipeline advancement with version-checked deduplication - ([f74a5a6](https://github.com/Rykian/LookingForJob/commit/f74a5a6a78d3f4d6aecd68defb7d5bcc3c35482e)) - Thibault Lacroux
- **(sourcing)** add commute duration pipeline with Mapbox geocoding and caching - ([09b8c25](https://github.com/Rykian/LookingForJob/commit/09b8c25119126cd4eb198c1db64a77555ea61607)) - Thibault Lacroux
- **(sourcing-linkedin)** rewrite LinkedIn provider using plain HTTP (Faraday) - ([0512e47](https://github.com/Rykian/LookingForJob/commit/0512e47fc4422b1253e66f504bf401104c90a632)) - Thibault Lacroux
- **(storage)** configure RustFS as S3-compatible ActiveStorage backend - ([77f9934](https://github.com/Rykian/LookingForJob/commit/77f993483d382e6eca2f379aad3b5f19e5d073e2)) - Thibault Lacroux
- **(ui)** add Vite React SPA with vite_rails - ([c153d68](https://github.com/Rykian/LookingForJob/commit/c153d6884551033b2230af95afa8ed20ca924621)) - Thibault Lacroux
- **(ui)** wire phase 3 screens to GraphQL - ([9914185](https://github.com/Rykian/LookingForJob/commit/991418572f92923ac6bb4fcb81408bec2484d1f3)) - Thibault Lacroux
- add sidekiq process to Procfile.dev - ([2cc5649](https://github.com/Rykian/LookingForJob/commit/2cc564915d0750664b959731d948662a4ecc99ff)) - Thibault Lacroux
- enhance job offers page with search parameters and location mode updates - ([bc55fba](https://github.com/Rykian/LookingForJob/commit/bc55fba144662fac462bf040ae7a70a91c2217ff)) - Thibault Lacroux
- integrate Lefthook for Git hooks management and add RuboCop pre-commit hook - ([5384af0](https://github.com/Rykian/LookingForJob/commit/5384af01203716ab81c538d9ec9df8e74cd9174f)) - Thibault Lacroux
- add example environment configuration file - ([f077072](https://github.com/Rykian/LookingForJob/commit/f0770726de7ee1333899732fb30fcebddc4308d5)) - Thibault Lacroux
- add changelog - ([0ea6db3](https://github.com/Rykian/LookingForJob/commit/0ea6db32496443da4775b3ec005f99022ca73c24)) - Thibault Lacroux

### Miscellaneous Chores

- **(bootstrap)** initialize rails api project - ([715e696](https://github.com/Rykian/LookingForJob/commit/715e69642d7a366b2578d647d86946501ef4d0c0)) - Thibault Lacroux
- **(docs)** tighten agents guide with pr review checklist - ([4ada025](https://github.com/Rykian/LookingForJob/commit/4ada025c9c46670808ab6187ca0e9c0bf9fc3287)) - Thibault Lacroux
- **(docs)** add or update sourcing-provider-creation skill - ([d269f45](https://github.com/Rykian/LookingForJob/commit/d269f45ab0c64af02f43197bfb1ef3f8edd9de1c)) - Thibault Lacroux
- **(frontend)** drop dead Vite scaffolding entrypoint - ([b2b386e](https://github.com/Rykian/LookingForJob/commit/b2b386e47d1c548a266ce7e464df3b9c13f28b74)) - Thibault Lacroux
- **(frontend)** enable tsconfig strict + noUnused* flags - ([d4a1918](https://github.com/Rykian/LookingForJob/commit/d4a191835fd88a9fc16eaa9de92b735a7e3e2a80)) - Thibault Lacroux
- **(infra)** add redis service to compose and use default queue - ([6facdc9](https://github.com/Rykian/LookingForJob/commit/6facdc9400107ed2014c16c549f6506f044f7544)) - Thibault Lacroux
- **(infra)** add SimpleCov with branch coverage - ([58a29dc](https://github.com/Rykian/LookingForJob/commit/58a29dc3f905614c39a73c985b52c20c503b3157)) - Thibault Lacroux
- **(infra)** adopt factory_bot for spec data setup - ([a0a93c2](https://github.com/Rykian/LookingForJob/commit/a0a93c2a6855c8304a26d4ea98b742db841fcea3)) - Thibault Lacroux
- **(linkedin)** move session storage to data - ([e90da40](https://github.com/Rykian/LookingForJob/commit/e90da40868b43958756539a306a939d85ab30bc6)) - Thibault Lacroux
- **(sourcing)** strip stale WTTJ TODO comments - ([def4d69](https://github.com/Rykian/LookingForJob/commit/def4d69ad0e03a899ba92038f8ce92969a8d19ea)) - Thibault Lacroux
- **(tooling)** add Biome for linting and formatting - ([d96edff](https://github.com/Rykian/LookingForJob/commit/d96edff1558f137e06aa5594534f9c37f5b87616)) - Thibault Lacroux
- add graphql:watch process to bin/dev - ([ae19e85](https://github.com/Rykian/LookingForJob/commit/ae19e85bb50608115957d551482b39270ce115df)) - Thibault Lacroux
- ignore Playwright MCP files - ([163f32f](https://github.com/Rykian/LookingForJob/commit/163f32fcbe7fe5aa035fd614c559700fdc73c345)) - Thibault Lacroux
- update RuboCop configuration and VSCode settings for Ruby formatting - ([27beb88](https://github.com/Rykian/LookingForJob/commit/27beb88bbaa3d0ac5887b04afdd2f0bd46750447)) - Thibault Lacroux
- update gems - ([772485b](https://github.com/Rykian/LookingForJob/commit/772485b90f4b0d670ecced3a801e93e764d8fd9c)) - Thibault Lacroux
- remove outdated sourcing-provider-creation skill file - ([3b2d677](https://github.com/Rykian/LookingForJob/commit/3b2d677f4cc90bc4cdc0be5f397a265c53756e08)) - Thibault Lacroux
- Add rails-ai-context integration and configuration - ([1fb0712](https://github.com/Rykian/LookingForJob/commit/1fb0712f1d56bad2d7f263e8a980d1077cceaf28)) - Thibault Lacroux
- upgrade TypeScript to 6.0.3 - ([998b9de](https://github.com/Rykian/LookingForJob/commit/998b9de1be2f77788142a215e5d3677e1ac7de44)) - Thibault Lacroux
- remove old screenshots from tests - ([3ec397f](https://github.com/Rykian/LookingForJob/commit/3ec397f774b88a1f5627b06804217fba5e6497e6)) - Thibault Lacroux
- update AI context and agent documentation - ([00e11a6](https://github.com/Rykian/LookingForJob/commit/00e11a6a7b95674d61964c4e8405680ec2effc46)) - Thibault Lacroux
- improve Claude support - ([0f35f34](https://github.com/Rykian/LookingForJob/commit/0f35f34f5e65f22de2e811b46970a60a8939083a)) - Thibault Lacroux
- add PolyForm Noncommercial 1.0.0 LICENSE - ([b9a9bdb](https://github.com/Rykian/LookingForJob/commit/b9a9bdb71f12df2fd871206dcef9642e0c31482f)) - Thibault Lacroux

### Performance

- **(db)** index job_offers columns used in list filters and sorts - ([7d281a2](https://github.com/Rykian/LookingForJob/commit/7d281a2d611c22f2f7f9ab640713dbb107e88d05)) - Thibault Lacroux

### Refactoring

- **(frontend)** reorganize frontend by feature folders - ([69703f1](https://github.com/Rykian/LookingForJob/commit/69703f1e18327948ba0410e0a55caa99f7d487dc)) - Thibault Lacroux
- **(graphql)** move frontend operations back into TSX files - ([38fe93e](https://github.com/Rykian/LookingForJob/commit/38fe93e745165aaf64bcf83fe186dcb4efa896af)) - Thibault Lacroux
- **(graphql)** split queries into their own files - ([80020b3](https://github.com/Rykian/LookingForJob/commit/80020b363d88a80df09844f3859f5ca131dcfca4)) - Thibault Lacroux
- **(graphql)** split JobOffersQuery and drop Query suffix - ([3158283](https://github.com/Rykian/LookingForJob/commit/315828309a151b4e727473ba59f0fd06ac1c82f6)) - Thibault Lacroux
- **(sourcing)** event-driven pipeline for offer jobs - ([d609d02](https://github.com/Rykian/LookingForJob/commit/d609d022765bee17a917acd8d21c5665e6912849)) - Thibault Lacroux
- **(sourcing)** upsert discovered offers atomically - ([15b1c12](https://github.com/Rykian/LookingForJob/commit/15b1c1298484d274b40f296a5e461ccfbce48b3f)) - Thibault Lacroux
- **(sourcing)** split cadremploi analyze step into per-field parsers - ([9644c10](https://github.com/Rykian/LookingForJob/commit/9644c109cca10c2498d9d47bd42d8648ac3be3b2)) - Thibault Lacroux
- **(sourcing)** split hellowork analyze step into per-field parsers - ([cd8a25a](https://github.com/Rykian/LookingForJob/commit/cd8a25a0ed0ed398125357615b648421b4e12171)) - Thibault Lacroux
- **(sourcing)** lift FetchStep init/call boilerplate into base class - ([e14d11d](https://github.com/Rykian/LookingForJob/commit/e14d11d9af8df82d1c7883b4643aba6afff0d8a4)) - Thibault Lacroux
- mutualize GraphQL config in TypeScript and DRY codegen setup - ([15704e5](https://github.com/Rykian/LookingForJob/commit/15704e51d4b5a50a8b6bc0c7c735aafe2962803e)) - Thibault Lacroux
- removing configuration for linkedin's timeout and cadremploi session path - ([45f9365](https://github.com/Rykian/LookingForJob/commit/45f9365ecbb8f63c84fe096bd4794a13041ccd77)) - Thibault Lacroux

### Tests

- **(application)** add sourcing job specs - ([93137de](https://github.com/Rykian/LookingForJob/commit/93137dea42c4975a350cf8ade0b1d85bce3202b2)) - Thibault Lacroux
- **(application)** add analyze and enrich job specs - ([1f090c4](https://github.com/Rykian/LookingForJob/commit/1f090c4c76e865b967e2ee615f028247878e7631)) - Thibault Lacroux
- **(crawler)** cover provider routing and linkedin step contracts - ([6467639](https://github.com/Rykian/LookingForJob/commit/6467639affd01a654a07fbb10f8e55ddd14dfe7f)) - Thibault Lacroux
- **(crawler)** add llm config and enrich wiring specs - ([8ab2a19](https://github.com/Rykian/LookingForJob/commit/8ab2a19221970a58f16be776d5489d218907fe15)) - Thibault Lacroux
- **(db)** add job_offer model contract specs - ([c714002](https://github.com/Rykian/LookingForJob/commit/c7140028a6cf13e40569a7c2b3e39b5539d17924)) - Thibault Lacroux
- **(graphql)** add request specs for core queries and mutations - ([bee107a](https://github.com/Rykian/LookingForJob/commit/bee107a9100e16c7d8773d891f86d2587d51f342)) - Thibault Lacroux
- **(model)** migrate JobOffer specs to shoulda-matchers - ([8c563ac](https://github.com/Rykian/LookingForJob/commit/8c563ac1558d78e8b5c0fac566223d210dbcf767)) - Thibault Lacroux
- **(sourcing-linkedin)** avoid removing linkedin session during test execution - ([ed1e4dc](https://github.com/Rykian/LookingForJob/commit/ed1e4dca728b8cb91e0a07a48dd2fd6055b30a33)) - Thibault Lacroux
- **(ui)** add vitest configuration for unit tests & storybook - ([2c0f285](https://github.com/Rykian/LookingForJob/commit/2c0f2859582210550469e490fd89d61b565376ed)) - Thibault Lacroux
- fix CI execution by adding a default .env - ([c5c4858](https://github.com/Rykian/LookingForJob/commit/c5c4858aa6107fcae5378adbfc5f7792216b6a6e)) - Thibault Lacroux

### Build

- **(db)** add docker compose postgres setup - ([9eb556d](https://github.com/Rykian/LookingForJob/commit/9eb556dcf3d9e9add658750e85c26fb9ca47453a)) - Thibault Lacroux
- **(deps)** add dotenv-rails for local env loading - ([3429bec](https://github.com/Rykian/LookingForJob/commit/3429bec817607fd792dfb3f21bc0dd3e6f9b76ff)) - Thibault Lacroux
- **(deps)** bump puma from 7.2.0 to 8.0.0 - ([ac9c159](https://github.com/Rykian/LookingForJob/commit/ac9c159712564ef408fd72345bae792856160a39)) - dependabot[bot]
- **(deps)** bump playwright-ruby-client from 1.58.1 to 1.59.0 (#9) - ([d1c598a](https://github.com/Rykian/LookingForJob/commit/d1c598a0f6e80175be22399b76334c44d98cb0a2)) - dependabot[bot]
- **(deps)** bump aws-sdk-s3 from 1.218.0 to 1.219.0 (#10) - ([c335368](https://github.com/Rykian/LookingForJob/commit/c3353681f8987f8b09a52311cf3ebd402884b19f)) - dependabot[bot]
- **(deps)** bump actions/cache from 4 to 5 - ([57e0dec](https://github.com/Rykian/LookingForJob/commit/57e0decc84b04e7bb90954fd218789de6f0f27fa)) - dependabot[bot]
- **(deps)** bump actions/setup-node from 4 to 6 - ([2802458](https://github.com/Rykian/LookingForJob/commit/280245843920e716961075887fcaac2331096519)) - dependabot[bot]
- **(queue)** switch to sidekiq and bootstrap rspec - ([a3f34c0](https://github.com/Rykian/LookingForJob/commit/a3f34c0bc0f3d6ea1e8104279c64660b55424d0c)) - Thibault Lacroux

### Ci

- **(infra)** add nightly scrapers smoke workflow - ([990d858](https://github.com/Rykian/LookingForJob/commit/990d858ff6c6b9617a6434a83a3707f1c13dd464)) - Thibault Lacroux

<!-- generated by git-cliff -->
