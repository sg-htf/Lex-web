# =============================================================================
# Lex Platform — developer workflow
# make help   — list all targets
# =============================================================================
SHELL := /usr/bin/env bash
APP   ?= Lex
MOD   ?=
FEAT  ?=
TYPE  ?= command
SVC   ?=
FORM  ?=
TITLE ?=

SCRIPTS := scripts

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v '^_' \
	  | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2}'

# ── Dev stack ──────────────────────────────────────────────────────────────
.PHONY: up down logs
up:   ## Start the full dev stack
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml up -d
down: ## Stop the dev stack
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml down
logs: ## Tail API logs
	docker compose -f infra/docker-compose.yml -f infra/docker-compose.override.yml logs -f api

# ── Build & test ───────────────────────────────────────────────────────────
.PHONY: build test test-arch lint
build:     ## Build the .NET solution
	dotnet build Lex.sln -c Release
test:      ## Run all tests
	dotnet test Lex.sln -c Release --filter "Category!=Integration"
test-arch: ## Run architecture boundary tests only
	dotnet test tests/Lex.ArchitectureTests -c Release
lint:      ## Verify .NET formatting
	dotnet format Lex.sln --verify-no-changes

# ── Database ───────────────────────────────────────────────────────────────
.PHONY: migrate
migrate: ## Add EF Core migration. Requires MOD= e.g. make migrate MOD=DiaryManagement
	$(call require-var,MOD,"module name (PascalCase)")
	dotnet ef migrations add InitialCreate \
	  --project src/Modules/Lex.Module.$(MOD)/Lex.Module.$(MOD).Infrastructure \
	  --startup-project src/Host/Lex.API

# ── Scaffolding ────────────────────────────────────────────────────────────
.PHONY: new-module new-feature new-integration new-adr new-adr-client new-client-module new-form new-module-full
new-module: ## New backend module. MOD=PascalName
	$(call require-var,MOD,"module name")
	@chmod +x $(SCRIPTS)/new-module.sh && $(SCRIPTS)/new-module.sh "$(MOD)" "$(APP)"

new-feature: ## New vertical slice. MOD= FEAT= TYPE=[command|query|event]
	$(call require-var,MOD,"module name")
	$(call require-var,FEAT,"feature name")
	@chmod +x $(SCRIPTS)/new-feature.sh && $(SCRIPTS)/new-feature.sh "$(MOD)" "$(FEAT)" "$(TYPE)" "$(APP)"

new-integration: ## New external API integration. MOD= SVC=
	$(call require-var,MOD,"module name")
	$(call require-var,SVC,"service name")
	@chmod +x $(SCRIPTS)/new-integration.sh && $(SCRIPTS)/new-integration.sh "$(MOD)" "$(SVC)" "$(APP)"

new-adr: ## New backend ADR. TITLE="..."
	$(call require-var,TITLE,"ADR title")
	@chmod +x $(SCRIPTS)/new-adr.sh && $(SCRIPTS)/new-adr.sh "$(TITLE)"

new-adr-client: ## New frontend ADR. TITLE="..."
	$(call require-var,TITLE,"ADR title")
	@chmod +x $(SCRIPTS)/new-adr.sh && $(SCRIPTS)/new-adr.sh "$(TITLE)" --client

new-client-module: ## New frontend module. MOD=lowercase
	$(call require-var,MOD,"module name (lowercase)")
	@chmod +x $(SCRIPTS)/new-client-module.sh && $(SCRIPTS)/new-client-module.sh "$(MOD)"

new-form: ## New React form component. FORM= MOD=
	$(call require-var,FORM,"form name")
	$(call require-var,MOD,"module name")
	@chmod +x $(SCRIPTS)/new-form.sh && $(SCRIPTS)/new-form.sh "$(FORM)" "$(MOD)"

new-module-full: ## Scaffold backend + frontend module pair. MOD=PascalName
	$(call require-var,MOD,"module name (PascalCase)")
	@chmod +x $(SCRIPTS)/new-module.sh && $(SCRIPTS)/new-module.sh "$(MOD)" "$(APP)"
	@chmod +x $(SCRIPTS)/new-client-module.sh && $(SCRIPTS)/new-client-module.sh "$$(echo '$(MOD)' | tr '[:upper:]' '[:lower:]')"

# ── Ops ─────────────────────────────────────────────────────────────────────
.PHONY: install upgrade backup
install: ## Run on-prem installer (from infra/)
	cd infra && bash scripts/install.sh
upgrade: ## Zero-downtime upgrade (from infra/)
	cd infra && bash scripts/upgrade.sh
backup:  ## Point-in-time backup (from infra/)
	cd infra && bash scripts/backup.sh

define require-var
  @if [ -z "$($(1))" ]; then echo ""; echo "  ERROR: $(1) is required.  make $(MAKECMDGOALS) $(1)=<$(2)>"; echo ""; exit 1; fi
endef
