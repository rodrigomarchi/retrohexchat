.PHONY: help setup deps db.setup db.create db.migrate db.rollback db.reset db.seed \
       db.gen.migration server iex routes \
       test test.unit test.integration test.liveview test.feature test.all test.cover \
       e2e e2e.headless e2e.ui e2e.install e2e.db.setup \
       test.cover.all test.domain test.web test.failed test.seed test.file test.line \
       test.js test.js.watch \
       ci ci.quick \
       i18n.audit i18n.audit.check i18n.status i18n.catalog.check i18n.gettext.extract i18n.gettext.check \
       lint format format.check credo dialyzer lint.js lint.js.fix lint.css precommit compile \
       assets.setup assets.build assets.deploy \
       clean clean.deps clean.build clean.all \
       deps.tree deps.update deps.unlock app.tree \
       docker.up docker.down docker.ps docker.logs docker.reset docker.stop \
       deploy deploy deploy.sun deploy.moon deploy.skip-ci \
       deploy-sun deploy-moon

DOMAIN_APP = apps/retro_hex_chat
WEB_APP    = apps/retro_hex_chat_web

# ---------------------------------------------------------------------
# RetroHexChat -- Development Makefile
# ---------------------------------------------------------------------

help: ## Show this help
	@grep -E '^[a-zA-Z_\.-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
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
	mix ecto.setup

deps: ## Install Elixir dependencies
	mix deps.get

# ---------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------

db.setup: ## Create database, run migrations, and seed
	mix ecto.setup

db.create: ## Create the database
	mix ecto.create

db.migrate: ## Run pending migrations
	mix ecto.migrate

db.rollback: ## Rollback the last migration
	mix ecto.rollback

db.reset: ## Drop, create, migrate, and seed the database
	mix ecto.reset

db.seed: ## Run seed script
	mix run $(DOMAIN_APP)/priv/repo/seeds.exs

db.gen.migration: ## Generate a migration (usage: make db.gen.migration NAME=create_foo)
	mix ecto.gen.migration $(NAME)

# ---------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------

server: ## Start Phoenix dev server at localhost:4000
	mix phx.server

iex: ## Start Phoenix dev server inside IEx
	iex -S mix phx.server

routes: ## List all application routes
	mix phx.routes RetroHexChatWeb.Router

# ---------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------

test: ## Run full test suite -- excludes LiveView feature tests
	mix test

test.unit: ## Run unit tests only
	cd $(DOMAIN_APP) && mix test --only unit

test.integration: ## Run integration tests only
	cd $(DOMAIN_APP) && mix test --only integration

test.liveview: ## Run LiveView tests only
	cd $(WEB_APP) && mix test --only liveview

test.feature: ## Run LiveView feature tests only (server-side feature/journey tests)
	cd $(WEB_APP) && mix test --only liveview_feature

test.all: ## Run ALL tests including LiveView feature tests
	mix test --include liveview_feature

test.cover: ## Run tests with coverage report
	mix test --cover

test.cover.all: ## Run ALL tests with coverage (including LiveView feature tests)
	mix test --include liveview_feature --cover

test.domain: ## Run domain app tests only
	cd $(DOMAIN_APP) && mix test

test.web: ## Run web app tests only (excludes LiveView feature tests)
	cd $(WEB_APP) && mix test

test.failed: ## Re-run only previously failed tests
	mix test --failed

test.seed: ## Run tests with a specific seed (usage: make test.seed SEED=12345)
	mix test --seed $(SEED)

test.file: ## Run a specific test file (usage: make test.file FILE=path/to/test.exs)
	mix test $(FILE)

test.line: ## Run a specific test by file:line (usage: make test.line TARGET=path/to/test.exs:42)
	mix test $(TARGET)

test.js: ## Run JavaScript tests (Vitest)
	npm test --prefix $(WEB_APP)/assets

test.js.watch: ## Run JavaScript tests in watch mode
	npm run test:watch --prefix $(WEB_APP)/assets

# ---------------------------------------------------------------------
# Browser E2E (Playwright) -- LOCAL ONLY, intentionally NOT in CI
# ---------------------------------------------------------------------

e2e: ## Run Playwright with VISIBLE browser + slow-mo (default; watch the flow)
	MIX_ENV=e2e mix assets.build
	cd e2e && SLOW_MO=$${SLOW_MO:-300} npm run test:headed

e2e.headless: ## Run Playwright headless (faster, no browser window)
	MIX_ENV=e2e mix assets.build
	cd e2e && npm test

e2e.ui: ## Run Playwright in interactive UI mode (play/pause/inspect)
	cd e2e && npm run test:ui

e2e.install: ## First-time: install npm deps + download Chromium
	cd e2e && npm install
	cd e2e && npm run install:browsers

e2e.db.setup: ## First-time: create + migrate the retro_hex_chat_e2e database
	MIX_ENV=e2e mix ecto.create
	MIX_ENV=e2e mix ecto.migrate

# ---------------------------------------------------------------------
# Static Analysis (Constitution Principle VI)
# ---------------------------------------------------------------------

lint: format.check credo dialyzer lint.js lint.css ## Run all static analysis checks

format: ## Auto-format all source files
	mix format
	npm run format --prefix $(WEB_APP)/assets

format.check: ## Check formatting without modifying files
	mix format --check-formatted

credo: ## Run Credo linter (strict mode)
	mix credo --strict

lint.js: ## Run ESLint + Prettier check on JS
	npm run lint --prefix $(WEB_APP)/assets
	npm run format:check --prefix $(WEB_APP)/assets

lint.js.fix: ## Auto-fix ESLint + Prettier issues
	npm run lint:fix --prefix $(WEB_APP)/assets
	npm run format --prefix $(WEB_APP)/assets

dialyzer: ## Run Dialyzer type checker
	mix dialyzer

lint.css: ## Audit inline styles and CSS class consistency
	@mix lint.inline_styles
	@mix lint.css_consistency

ci: ## Run all CI checks locally with maximum parallelism
	elixir scripts/ci.exs

ci.quick: ## Run CI checks without dialyzer (faster iteration)
	elixir scripts/ci.exs --quick

i18n.audit: ## Find hardcoded user-visible strings that still need i18n
	elixir scripts/i18n_audit.exs

i18n.audit.check: ## Fail when hardcoded user-visible strings are found
	elixir scripts/i18n_audit.exs --fail-on-findings

i18n.status: ## Report translated, empty, and fuzzy Gettext catalog entries
	elixir scripts/i18n_po_status.exs

i18n.catalog.check: ## Fail while pt_BR catalogs still have empty or fuzzy entries
	elixir scripts/i18n_po_status.exs --fail-on-untranslated --fail-locale pt_BR

i18n.gettext.extract: ## Extract and merge Gettext catalogs for all apps
	cd $(DOMAIN_APP) && mix gettext.extract --merge --no-fuzzy
	cd $(WEB_APP) && mix gettext.extract --merge --no-fuzzy

i18n.gettext.check: ## Verify Gettext catalogs are up to date for all apps
	cd $(DOMAIN_APP) && mix gettext.extract --check-up-to-date
	cd $(WEB_APP) && mix gettext.extract --check-up-to-date

precommit: ## Run pre-commit pipeline (compile + format + test)
	mix precommit

compile: ## Compile with warnings as errors
	mix compile --warnings-as-errors

# ---------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------

assets.setup: ## Install esbuild and Node.js dependencies
	mix esbuild.install --if-missing
	npm install --prefix $(WEB_APP)/assets

assets.build: ## Build JS/CSS assets for development
	mix esbuild retro_hex_chat_web
	mix esbuild retro_hex_chat_web_css

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
#   DEPLOY_USER  — SSH username on the target servers
#   SUN_IP       — Production server IP address
#   MOON_IP      — Staging server IP address
#   SSH_PORT     — SSH port (default: 2222)

deploy: ## CI + deploy to both environments in parallel — usage: make deploy REF=main
	elixir scripts/deploy_all.exs --ref $(REF)

deploy.sun: ## CI + deploy to production only — usage: make deploy.sun REF=main
	elixir scripts/deploy_all.exs --ref $(REF) --only sun

deploy.moon: ## CI + deploy to staging only — usage: make deploy.moon REF=main
	elixir scripts/deploy_all.exs --ref $(REF) --only moon

deploy.skip-ci: ## Deploy both without CI (already validated) — usage: make deploy.skip-ci REF=main
	elixir scripts/deploy_all.exs --ref $(REF) --skip-ci

deploy-sun: ## Deploy to production (no CI) — usage: make deploy-sun REF=main
	@test -n "$(DEPLOY_USER)" || (echo "Error: DEPLOY_USER is required" && exit 1)
	@test -n "$(SUN_IP)" || (echo "Error: SUN_IP is required" && exit 1)
	scp -P $${SSH_PORT:-2222} scripts/deploy.sh $(DEPLOY_USER)@$(SUN_IP):~/deploy.sh
	ssh -p $${SSH_PORT:-2222} $(DEPLOY_USER)@$(SUN_IP) "bash ~/deploy.sh $(REF)"

deploy-moon: ## Deploy to staging (no CI) — usage: make deploy-moon REF=main
	@test -n "$(DEPLOY_USER)" || (echo "Error: DEPLOY_USER is required" && exit 1)
	@test -n "$(MOON_IP)" || (echo "Error: MOON_IP is required" && exit 1)
	scp -P $${SSH_PORT:-2222} scripts/deploy.sh $(DEPLOY_USER)@$(MOON_IP):~/deploy.sh
	ssh -p $${SSH_PORT:-2222} $(DEPLOY_USER)@$(MOON_IP) "bash ~/deploy.sh $(REF)"
