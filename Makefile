.PHONY: help setup deps db.setup db.create db.migrate db.rollback db.reset db.seed \
       db.gen.migration server iex routes \
       test test.unit test.integration test.liveview test.e2e test.all test.cover \
       test.cover.all test.domain test.web test.failed test.seed test.file test.line \
       lint format format.check credo dialyzer precommit compile \
       assets.setup assets.build assets.deploy \
       clean clean.deps clean.build clean.all \
       deps.tree deps.update deps.unlock app.tree \
       docker.up docker.down docker.ps docker.logs docker.reset docker.stop

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

test: ## Run full test suite -- excludes E2E
	mix test

test.unit: ## Run unit tests only (~390 tests)
	cd $(DOMAIN_APP) && mix test --only unit

test.integration: ## Run integration tests only (~229 tests)
	cd $(DOMAIN_APP) && mix test --only integration

test.liveview: ## Run LiveView tests only (145 tests)
	cd $(WEB_APP) && mix test --only liveview

test.e2e: ## Run E2E tests only (137 tests)
	cd $(WEB_APP) && mix test --only e2e

test.all: ## Run ALL tests including E2E
	mix test --include e2e

test.cover: ## Run tests with coverage report
	mix test --cover

test.cover.all: ## Run ALL tests with coverage (including E2E)
	mix test --include e2e --cover

test.domain: ## Run domain app tests only (621 tests)
	cd $(DOMAIN_APP) && mix test

test.web: ## Run web app tests only (201 tests, excludes E2E)
	cd $(WEB_APP) && mix test

test.failed: ## Re-run only previously failed tests
	mix test --failed

test.seed: ## Run tests with a specific seed (usage: make test.seed SEED=12345)
	mix test --seed $(SEED)

test.file: ## Run a specific test file (usage: make test.file FILE=path/to/test.exs)
	mix test $(FILE)

test.line: ## Run a specific test by file:line (usage: make test.line TARGET=path/to/test.exs:42)
	mix test $(TARGET)

# ---------------------------------------------------------------------
# Static Analysis (Constitution Principle VI)
# ---------------------------------------------------------------------

lint: format.check credo dialyzer ## Run all static analysis checks

format: ## Auto-format all source files
	mix format

format.check: ## Check formatting without modifying files
	mix format --check-formatted

credo: ## Run Credo linter (strict mode)
	mix credo --strict

dialyzer: ## Run Dialyzer type checker
	mix dialyzer

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
