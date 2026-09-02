.PHONY: help setup deps db.setup db.create db.migrate db.rollback db.reset db.seed \
       db.gen.migration server iex routes \
       test test.stale test.unit test.integration test.liveview test.feature test.all test.cover \
       e2e e2e.headless e2e.full e2e.changed e2e.shard e2e.smoke e2e.smoke.connect e2e.smoke.chat e2e.smoke.dialogs e2e.smoke.i18n e2e.smoke.calls e2e.smoke.mobile e2e.smoke.perf e2e.ui e2e.shots e2e.install e2e.db.setup load.test \
       test.cover.all test.domain test.domain.stale test.web test.web.stale test.failed test.seed test.file test.line \
       test.js test.js.changed test.js.related test.js.watch \
       ci ci.quick ci.changed ci.serial ci.quick.serial ci.partition-profile ci.partition-profile.plan \
       umbrella.boundary-audit \
       i18n.audit i18n.audit.check i18n.status i18n.catalog.check i18n.catalog.size.check i18n.placeholder.check i18n.source-fallback.check i18n.quality.check i18n.glossary i18n.repair i18n.tooling.test i18n.locales.add i18n.wave1.add i18n.gettext.extract i18n.gettext.merge i18n.gettext.rebuild i18n.gettext.check \
       lint format format.check credo dialyzer lint.js lint.js.changed lint.js.fix lint.css lint.bundle precommit compile \
       assets.setup assets.build assets.deploy \
       clean clean.deps clean.build clean.all \
       deps.tree deps.update deps.unlock app.tree \
       docker.up docker.down docker.ps docker.logs docker.reset docker.stop \
       deploy deploy.skip-ci deploy-sun

DOMAIN_APP = apps/retro_hex_chat
WEB_APP    = apps/retro_hex_chat_web

# Throwaway target for the CSS build check, so proving the stylesheet compiles
# never overwrites the bundle a running server is serving.
CSS_BUILD_CHECK_OUT = $(shell mktemp -t retrohex-css-check)
E2E_DIR    = e2e
PRETTIER   = $(WEB_APP)/assets/node_modules/.bin/prettier
E2E_FORMAT_SOURCES = $(E2E_DIR)/*.json $(E2E_DIR)/*.ts $(E2E_DIR)/helpers $(E2E_DIR)/pages $(E2E_DIR)/tests $(E2E_DIR)/load
E2E_SMOKE_CONNECT_ARGS = tests/connect-flow.spec.ts
E2E_SMOKE_CHAT_ARGS = tests/chat-welcome.spec.ts
E2E_SMOKE_DIALOGS_ARGS = tests/chat-dialog-close.spec.ts
E2E_SMOKE_I18N_ARGS = tests/i18n.spec.ts --grep "switches the connect UI"
E2E_SMOKE_CALLS_ARGS = tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts --grep "accepting from the PM header|pre-join dialog keeps preview"
E2E_SMOKE_MOBILE_ARGS = tests/chat-mobile-desktop.spec.ts --grep "shows one fullscreen window"
E2E_SMOKE_PERF_ARGS = tests/perf-payload.spec.ts tests/perf-critical-path.spec.ts
I18N_REQUIRED_LOCALES = pt_BR,es,fr,de,ja,zh_hans,id,ru,zh_hant,pt_PT,it,pl,nl

ifneq (,$(wildcard .env))
include .env
endif

PORT ?= 4000
TEST_PORT ?= 4002
E2E_PORT ?= 4003
CI_TEST_PARTITIONS ?= 3
CI_FEATURE_PARTITIONS ?= 4
CI_TEST_DB_POOL_SIZE ?= 6
CI_PARTITION_COUNTS ?= 1,2,3,4
CI_PARTITION_RUNS ?= 1
CI_PARTITION_SUITES ?= test,test_feature
CI_BOUNDARY_COMMITS ?= 80
CI_BASE ?= origin/main
CI_HEAD ?= HEAD
DEV_DB_PORT ?= 5432
TEST_DB_PORT ?= 5433
BASE_URL ?= http://localhost:$(PORT)
PUBLIC_ORIGIN ?= $(BASE_URL)
E2E_BASE_URL ?= http://localhost:$(E2E_PORT)
TURN_LISTEN_PORT ?= 3478
TURN_RELAY_PORT_MIN ?= 49152
TURN_RELAY_PORT_MAX ?= 49651

DEV_ENV = PGPORT=$(DEV_DB_PORT) PORT=$(PORT) BASE_URL=$(BASE_URL) PUBLIC_ORIGIN=$(PUBLIC_ORIGIN) TURN_LISTEN_PORT=$(TURN_LISTEN_PORT) TURN_RELAY_PORT_MIN=$(TURN_RELAY_PORT_MIN) TURN_RELAY_PORT_MAX=$(TURN_RELAY_PORT_MAX)
TEST_ENV = PGPORT=$(TEST_DB_PORT) TEST_PORT=$(TEST_PORT)
E2E_ENV = MIX_ENV=e2e PGPORT=$(TEST_DB_PORT) E2E_PORT=$(E2E_PORT) E2E_BASE_URL=$(E2E_BASE_URL) BASE_URL=$(E2E_BASE_URL) PUBLIC_ORIGIN=$(E2E_BASE_URL)
DEV_MIX = $(DEV_ENV) mix
TEST_MIX = $(TEST_ENV) mix
E2E_MIX = $(E2E_ENV) mix
CI_CHANGED_FLAGS = --changed --base $(CI_BASE) --head $(CI_HEAD)

ifeq ($(EXPLAIN),1)
CI_CHANGED_FLAGS += --explain-only
endif

# ---------------------------------------------------------------------
# RetroHexChat -- Development Makefile
# ---------------------------------------------------------------------

help: ## Show this help
	@grep -hE '^[a-zA-Z_\.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------
# Docker Compose
# ---------------------------------------------------------------------

docker.up: ## Start PostgreSQL containers (dev + test)
	docker compose up -d

docker.down: ## Stop and remove PostgreSQL containers
	docker compose down

docker.stop: ## Stop PostgreSQL containers (keep data)
	docker compose stop

docker.ps: ## Show running container status
	docker compose ps

docker.logs: ## Tail PostgreSQL container logs
	docker compose logs -f

docker.reset: ## Destroy containers and volumes (fresh start)
	docker compose down -v

# ---------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------

setup: ## First-time project setup (docker + deps + db + assets)
	docker compose up -d
	mix deps.get
	npm install --prefix $(WEB_APP)/assets
	$(DEV_MIX) ecto.setup

deps: ## Install Elixir dependencies
	mix deps.get

# ---------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------

db.setup: ## Create database, run migrations, and seed
	$(DEV_MIX) ecto.setup

db.create: ## Create the database
	$(DEV_MIX) ecto.create

db.migrate: ## Run pending migrations
	$(DEV_MIX) ecto.migrate

db.rollback: ## Rollback the last migration
	$(DEV_MIX) ecto.rollback

db.reset: ## Drop, create, migrate, and seed the database
	$(DEV_MIX) ecto.reset

db.seed: ## Run seed script
	$(DEV_MIX) run $(DOMAIN_APP)/priv/repo/seeds.exs

db.gen.migration: ## Generate a migration (usage: make db.gen.migration NAME=create_foo)
	$(DEV_MIX) ecto.gen.migration $(NAME)

# ---------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------

server: ## Start Phoenix dev server at configured PORT (default 4000)
	$(DEV_MIX) phx.server

iex: ## Start Phoenix dev server inside IEx
	$(DEV_ENV) iex -S mix phx.server

routes: ## List all application routes
	$(DEV_MIX) phx.routes RetroHexChatWeb.Router

# ---------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------

test: ## Run full test suite -- excludes LiveView feature tests
	$(TEST_MIX) test

test.stale: ## Run stale Elixir tests from the umbrella root
	$(TEST_MIX) test --stale

test.unit: ## Run unit tests only
	cd $(DOMAIN_APP) && $(TEST_MIX) test --only unit

test.integration: ## Run integration tests only
	cd $(DOMAIN_APP) && $(TEST_MIX) test --only integration

test.liveview: ## Run LiveView tests only
	cd $(WEB_APP) && $(TEST_MIX) test --only liveview

test.feature: ## Run LiveView feature tests only (server-side feature/journey tests)
	cd $(WEB_APP) && $(TEST_MIX) test --only liveview_feature

test.all: ## Run ALL tests including LiveView feature tests
	$(TEST_MIX) test --include liveview_feature

test.cover: ## Run tests with coverage report
	$(TEST_MIX) test --cover

test.cover.all: ## Run ALL tests with coverage (including LiveView feature tests)
	$(TEST_MIX) test --include liveview_feature --cover

test.domain: ## Run domain app tests only
	cd $(DOMAIN_APP) && $(TEST_MIX) test

test.domain.stale: ## Run stale domain app tests only
	cd $(DOMAIN_APP) && $(TEST_MIX) test --stale

test.web: ## Run web app tests only (excludes LiveView feature tests)
	cd $(WEB_APP) && $(TEST_MIX) test

test.web.stale: ## Run stale web app tests only
	cd $(WEB_APP) && $(TEST_MIX) test --stale

test.failed: ## Re-run only previously failed tests
	$(TEST_MIX) test --failed

test.seed: ## Run tests with a specific seed (usage: make test.seed SEED=12345)
	$(TEST_MIX) test --seed $(SEED)

test.file: ## Run a specific test file (usage: make test.file FILE=path/to/test.exs)
	$(TEST_MIX) test $(FILE)

test.line: ## Run a specific test by file:line (usage: make test.line TARGET=path/to/test.exs:42)
	$(TEST_MIX) test $(TARGET)

test.js: ## Run JavaScript tests (Vitest)
	npm test --prefix $(WEB_APP)/assets

test.js.changed: ## Run Vitest tests affected by changed JS files (usage: make test.js.changed SINCE=origin/main)
	npm run test:changed --prefix $(WEB_APP)/assets -- $(SINCE)

test.js.related: ## Run Vitest tests related to asset files (usage: make test.js.related FILES="js/app.js")
	@test -n "$(FILES)" || { echo "usage: make test.js.related FILES=\"js/app.js test/lib/foo.test.js\""; exit 2; }
	npm run test:related --prefix $(WEB_APP)/assets -- $(FILES)

test.js.watch: ## Run JavaScript tests in watch mode
	npm run test:watch --prefix $(WEB_APP)/assets

# ---------------------------------------------------------------------
# Browser E2E (Playwright) -- LOCAL ONLY, intentionally NOT in CI
# ---------------------------------------------------------------------

e2e: ## Run Playwright with VISIBLE browser + slow-mo (default; watch the flow)
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) SLOW_MO=$${SLOW_MO:-300} npm run test:headed

e2e.headless: ## Run Playwright headless (faster, no browser window)
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npm test

e2e.full: ## Run the whole Playwright suite (~36 min) — the release gate `make ci` cannot be
	@echo "The whole suite, one worker, roughly 36 minutes."
	@echo "Run it before a deploy: make ci proves the server, this proves the browser."
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test

e2e.changed: ## Run Playwright specs changed since SINCE (default: uncommitted changes)
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test --only-changed $(SINCE)

e2e.catalog: ## Regenerate e2e/TEST_CATALOG.md from the @flow headers in the specs
	cd e2e && node scripts/catalog.mjs

e2e.catalog.check: ## Verify TEST_CATALOG.md matches the spec @flow headers
	cd e2e && node scripts/catalog.mjs --check

e2e.shard: ## Run a Playwright shard (usage: make e2e.shard SHARD=1/2)
	@test -n "$(SHARD)" || { echo "usage: make e2e.shard SHARD=1/2"; exit 2; }
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test --shard=$(SHARD)

e2e.smoke: ## Run a named Playwright smoke surface (usage: make e2e.smoke SURFACE=connect)
	@test -n "$(SURFACE)" || { echo "usage: make e2e.smoke SURFACE=connect|chat|dialogs|i18n|calls|mobile|perf"; exit 2; }
	$(MAKE) e2e.smoke.$(SURFACE)

e2e.smoke.connect: ## Run connect-flow browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_CONNECT_ARGS)

e2e.smoke.chat: ## Run chat-shell browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_CHAT_ARGS)

e2e.smoke.dialogs: ## Run dialog/window-manager browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_DIALOGS_ARGS)

e2e.smoke.i18n: ## Run i18n browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_I18N_ARGS)

e2e.smoke.calls: ## Run P2P/group-call browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_CALLS_ARGS)

e2e.smoke.mobile: ## Run mobile-layout browser smoke
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_MOBILE_ARGS)

e2e.smoke.perf: ## Run the payload and critical-path performance budgets
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) npx playwright test $(E2E_SMOKE_PERF_ARGS)

e2e.ui: ## Run Playwright in interactive UI mode (play/pause/inspect)
	cd e2e && $(E2E_ENV) npm run test:ui

e2e.shots: ## Capture visual evidence from a spec: make e2e.shots FILE=tests/x.spec.ts
	@test -n "$(FILE)" || { echo "usage: make e2e.shots FILE=tests/<file>.spec.ts"; exit 1; }
	$(E2E_MIX) assets.build
	cd e2e && $(E2E_ENV) E2E_SHOTS=1 npx playwright test $(FILE)
	@echo "Screenshots: e2e/screenshots/"

e2e.install: ## First-time: install npm deps + download Chromium
	cd e2e && npm install
	cd e2e && npm run install:browsers

e2e.db.setup: ## First-time: create + migrate the retro_hex_chat_e2e database
	$(E2E_MIX) ecto.create
	$(E2E_MIX) ecto.migrate

load.test: ## Load test against a RUNNING server (default: production; LOAD_BASE_URL/LOAD_USERS/LOAD_DURATION_MS to override)
	cd e2e && npx playwright test --config=load/load.config.ts

# ---------------------------------------------------------------------
# Static Analysis
# ---------------------------------------------------------------------

lint: format.check credo dialyzer lint.js lint.hooks lint.css lint.bundle ## Run all static analysis checks

format: ## Auto-format all source files
	mix format
	npm run format --prefix $(WEB_APP)/assets
	$(MAKE) format.e2e

format.check: ## Check formatting without modifying files
	mix format --check-formatted
	npm run format:check --prefix $(WEB_APP)/assets
	$(MAKE) format.e2e.check

format.e2e: ## Auto-format Playwright E2E sources
	$(PRETTIER) --write $(E2E_FORMAT_SOURCES)

format.e2e.check: ## Check Playwright E2E formatting
	$(PRETTIER) --check $(E2E_FORMAT_SOURCES)

credo: ## Run Credo linter (strict mode)
	mix credo --strict

lint.js: ## Run ESLint + Prettier check on JS
	npm run lint --prefix $(WEB_APP)/assets
	npm run format:check --prefix $(WEB_APP)/assets

lint.js.changed: ## Run ESLint + Prettier on changed JS assets (usage: make lint.js.changed SINCE=origin/main)
	@cd $(WEB_APP)/assets && \
		files="$$(git -C ../../.. diff --name-only --diff-filter=ACMRTUXB $${SINCE:-origin/main} -- apps/retro_hex_chat_web/assets/js apps/retro_hex_chat_web/assets/test apps/retro_hex_chat_web/assets/scripts | sed 's#^apps/retro_hex_chat_web/assets/##')" ; \
		if [ -z "$$files" ]; then \
			echo "No changed JS assets."; \
		else \
			npm run lint:changed -- $$files && npx prettier --check $$files; \
		fi

lint.js.fix: ## Auto-fix ESLint + Prettier issues
	npm run lint:fix --prefix $(WEB_APP)/assets
	npm run format --prefix $(WEB_APP)/assets

lint.hooks: ## Enforce LiveView hook loading contract
	npm run lint:hooks --prefix $(WEB_APP)/assets

dialyzer: ## Run Dialyzer type checker
	mix dialyzer

lint.css: ## Audit inline styles and CSS class consistency
	@mix lint.inline_styles
	@mix lint.css_consistency
	@mix audit.styles --strict
	@$(MAKE) --no-print-directory lint.css.build

# The three audits above read the stylesheet; none of them compile it. An
# `@apply` of a utility that does not exist passes every one of them and then
# fails the real build, which serves the previous CSS — so the app looks fine
# locally and every E2E run is quietly styled by a stale bundle.
lint.css.build: ## Prove the stylesheet compiles
	@cd $(WEB_APP) && node assets/scripts/bundle_retrohex_css.cjs
	@cd $(WEB_APP) && env BROWSERSLIST_IGNORE_OLD_DATA=1 \
		assets/node_modules/.bin/tailwindcss \
		-c assets/tailwind.config.js \
		-i assets/css/.generated/retrohex.css \
		-o $(CSS_BUILD_CHECK_OUT)

lint.bundle: ## Enforce frontend bundle budgets
	npm run bundle:budget --prefix $(WEB_APP)/assets

ci: ## Run all CI checks locally with maximum parallelism
	$(TEST_ENV) CI_TEST_PARTITIONS=$(CI_TEST_PARTITIONS) CI_FEATURE_PARTITIONS=$(CI_FEATURE_PARTITIONS) CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci.exs

ci.quick: ## Run CI checks without dialyzer (faster iteration)
	$(TEST_ENV) CI_TEST_PARTITIONS=$(CI_TEST_PARTITIONS) CI_FEATURE_PARTITIONS=$(CI_FEATURE_PARTITIONS) CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci.exs --quick

ci.changed: ## Run checks selected from git diff (usage: make ci.changed CI_BASE=origin/main EXPLAIN=1)
	$(TEST_ENV) CI_TEST_PARTITIONS=$(CI_TEST_PARTITIONS) CI_FEATURE_PARTITIONS=$(CI_FEATURE_PARTITIONS) CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci.exs $(CI_CHANGED_FLAGS)

ci.serial: ## Run all CI checks with one Elixir test partition per suite
	$(TEST_ENV) CI_TEST_PARTITIONS=1 CI_FEATURE_PARTITIONS=1 CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci.exs

ci.quick.serial: ## Run quick CI with one Elixir test partition per suite
	$(TEST_ENV) CI_TEST_PARTITIONS=1 CI_FEATURE_PARTITIONS=1 CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci.exs --quick

ci.partition-profile: ## Measure ExUnit suite time by partition count (usage: make ci.partition-profile CI_PARTITION_COUNTS=2,3,4)
	$(TEST_ENV) CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci_partition_profile.exs --counts $(CI_PARTITION_COUNTS) --suites $(CI_PARTITION_SUITES) --runs $(CI_PARTITION_RUNS)

ci.partition-profile.plan: ## Print partition profile plan without running tests
	$(TEST_ENV) CI_TEST_DB_POOL_SIZE=$(CI_TEST_DB_POOL_SIZE) elixir scripts/ci_partition_profile.exs --counts $(CI_PARTITION_COUNTS) --suites $(CI_PARTITION_SUITES) --runs $(CI_PARTITION_RUNS) --dry-run

umbrella.boundary-audit: ## Analyze recent git history for umbrella extraction candidates
	elixir scripts/umbrella_boundary_audit.exs --commits $(CI_BOUNDARY_COMMITS)

i18n.audit: ## Find hardcoded user-visible strings that still need i18n
	elixir scripts/i18n_audit.exs

i18n.audit.check: ## Fail when hardcoded user-visible strings are found
	elixir scripts/i18n_audit.exs --fail-on-findings

i18n.status: ## Report translated, empty, and fuzzy Gettext catalog entries
	elixir scripts/i18n_po_status.exs

i18n.catalog.check: ## Fail while required catalogs have missing/empty/fuzzy entries, unsafe placeholders, English fallbacks, oversized files, or unusable translations
	elixir scripts/i18n_catalog_completeness_check.exs --fail-on-missing
	elixir scripts/i18n_po_status.exs --fail-on-untranslated --fail-locale $(I18N_REQUIRED_LOCALES)
	elixir scripts/i18n_catalog_size_check.exs --fail-on-exceed --max-lines 12000
	mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings
	python3 scripts/i18n_source_fallback_check.py --locales $(I18N_REQUIRED_LOCALES) --fail-on-findings
	python3 scripts/i18n_quality_check.py --locales $(I18N_REQUIRED_LOCALES) --fail-on-findings

i18n.catalog.size.check: ## Fail when any Gettext catalog exceeds the readable size limit
	elixir scripts/i18n_catalog_size_check.exs --fail-on-exceed --max-lines 12000

i18n.quality.check: ## Fail on collapsed, degenerate, or sentinel-leaking translations
	python3 scripts/i18n_quality_check.py --locales $(I18N_REQUIRED_LOCALES) --fail-on-findings

i18n.glossary: ## Apply the curated UI label glossary to the catalogs
	python3 scripts/i18n_apply_glossary.py --locales $(I18N_REQUIRED_LOCALES) --write

i18n.repair: ## Repair unusable catalog entries (needs the translation venv)
	python3 scripts/i18n_repair_catalogs.py --locales $(I18N_REQUIRED_LOCALES) --write

i18n.tooling.test: ## Run the i18n Python tooling test suite
	python3 -m unittest discover -s scripts -t scripts -p 'test_*.py'

i18n.placeholder.check: ## Fail when translated strings lose Gettext placeholders
	mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings

i18n.source-fallback.check: ## Fail when enabled non-English catalogs keep actionable English fallbacks
	python3 scripts/i18n_source_fallback_check.py --locales $(I18N_REQUIRED_LOCALES) --fail-on-findings

i18n.locales.add: ## Generate Gettext catalogs for LOCALES=es,fr or WAVE=1
	elixir scripts/i18n_add_locales.exs $$(test -n "$(LOCALES)" && echo --locales $(LOCALES)) $$(test -n "$(WAVE)" && echo --wave $(WAVE))

i18n.wave1.add: ## Generate Gettext catalogs for the first expansion wave
	elixir scripts/i18n_add_locales.exs --wave 1

i18n.gettext.extract: ## Extract Gettext POT templates for all apps
	cd $(DOMAIN_APP) && mix gettext.extract
	cd $(WEB_APP) && mix gettext.extract

i18n.gettext.merge: ## Merge selected Gettext domains into PO catalogs; use DOMAINS=landing APP=web LOCALES=pt_BR,es
	elixir scripts/i18n_merge_domain_catalogs.exs $$(test -n "$(APP)" && echo --app "$(APP)") $$(test -n "$(DOMAINS)" && echo --domains "$(DOMAINS)") $$(test -n "$(LOCALES)" && echo --locales "$(LOCALES)") $$(test "$(NO_FUZZY)" = "1" && echo --no-fuzzy)

i18n.gettext.rebuild: ## Rebuild all Gettext PO catalogs; requires CONFIRM_GLOBAL_REBUILD=1
	test "$(CONFIRM_GLOBAL_REBUILD)" = "1" || (echo "Refusing global i18n rebuild. Re-run with CONFIRM_GLOBAL_REBUILD=1." && exit 2)
	elixir scripts/i18n_rebuild_domain_catalogs.exs --confirm-global-rebuild

i18n.gettext.check: ## Verify Gettext catalogs are up to date for all apps
	cd $(DOMAIN_APP) && mix gettext.extract --check-up-to-date
	cd $(WEB_APP) && mix gettext.extract --check-up-to-date

precommit: ## Run pre-commit pipeline (compile + format + test)
	$(TEST_MIX) precommit

compile: ## Compile with warnings as errors
	mix compile --warnings-as-errors

# ---------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------

assets.setup: ## Install esbuild and Node.js dependencies
	mix esbuild.install --if-missing
	npm install --prefix $(WEB_APP)/assets

assets.build: ## Build JS/CSS assets for development
	cd $(WEB_APP) && mix assets.build

assets.deploy: ## Build and minify assets for production
	mix assets.deploy

# ---------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------

clean: ## Clean compiled artifacts
	mix clean

clean.deps: ## Remove all fetched dependencies
	mix deps.clean --all

clean.build: ## Remove _build directory
	rm -rf _build

clean.all: clean.build clean.deps ## Full clean (build + deps + node_modules + assets)
	rm -rf $(WEB_APP)/assets/node_modules
	rm -rf $(WEB_APP)/priv/static/assets

# ---------------------------------------------------------------------
# Introspection
# ---------------------------------------------------------------------

deps.tree: ## Show dependency tree
	mix deps.tree

deps.update: ## Update all dependencies
	mix deps.update --all

deps.unlock: ## Remove unused dependencies from lock file
	mix deps.unlock --unused

app.tree: ## Show OTP application supervision tree
	mix app.tree --app retro_hex_chat

# ---------------------------------------------------------------------
# Deploy (via DeployEx)
# ---------------------------------------------------------------------

REF ?= main

# Deploy env vars (all required, set via environment or make args):
#   DEPLOY_USER  — SSH username on the target server
#   SUN_IP       — Production server IP address
#   SSH_PORT     — SSH port (default: 2222)

deploy: ## CI + deploy to production (Sun) — usage: make deploy REF=main
	elixir scripts/deploy_all.exs --ref $(REF)

deploy.skip-ci: ## Deploy Sun without CI (already validated) — usage: make deploy.skip-ci REF=main
	elixir scripts/deploy_all.exs --ref $(REF) --skip-ci

deploy-sun: ## Deploy to production (no CI) — usage: make deploy-sun REF=main
	@test -n "$(DEPLOY_USER)" || (echo "Error: DEPLOY_USER is required" && exit 1)
	@test -n "$(SUN_IP)" || (echo "Error: SUN_IP is required" && exit 1)
	scp -P $${SSH_PORT:-2222} scripts/deploy.sh $(DEPLOY_USER)@$(SUN_IP):~/deploy.sh
	ssh -p $${SSH_PORT:-2222} $(DEPLOY_USER)@$(SUN_IP) "bash ~/deploy.sh $(REF)"
