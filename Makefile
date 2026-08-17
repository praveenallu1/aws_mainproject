SHELL := /bin/sh

.PHONY: help install test lint docker-build tf-fmt tf-validate validate

help:
	@awk 'BEGIN {FS = ":.*##"; print "Available targets:"} /^[a-zA-Z_-]+:.*?##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install application dependencies from the lock file
	cd app && npm ci

test: ## Run application tests
	cd app && npm test

lint: ## Run application static checks
	cd app && npm run lint

docker-build: ## Build the application container locally
	docker build -t cloudops-api:local app

tf-fmt: ## Check Terraform formatting
	terraform -chdir=infrastructure fmt -check -recursive

tf-validate: ## Initialize without a backend and validate Terraform
	terraform -chdir=infrastructure init -backend=false
	terraform -chdir=infrastructure validate

validate: lint test tf-fmt tf-validate ## Run the local quality gate

