# Copyright (c) 2023 ESL Erlang Solutions
# All Rights Reserved.

.PHONY: help docker.build test test.cover local.deploy.install local.deploy.uninstall

EX_APP_NAME := elisnake
BUILD_VSN := $(shell cat vsn.txt)
GITHUB_OAUTH_TOKEN ?= skip_fetch

ENV_FILE ?= .env

# import and export .env variables
ifneq (,$(wildcard ${ENV_FILE}))
	include ${ENV_FILE}
    export
endif

default: help

#❓ help: @ Displays this message
help:
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(firstword $(MAKEFILE_LIST))| tr -d '#'  | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}'

#🐳 docker.build: @ Builds a new local docker image
docker.build: SHELL:=/bin/bash
docker.build: MIX_ENV=prod
docker.build: TAG:=latest
docker.build:
	@echo "🐳👁️  Build docker image ${EX_APP_NAME}"
	@docker build --target candidate -t gcr.io/${EX_APP_NAME}:${BUILD_VSN} \
	-t gcr.io/${EX_APP_NAME}:latest -f devops/docker/Dockerfile \
	--build-arg GITHUB_OAUTH_TOKEN=${GITHUB_OAUTH_TOKEN} .

#🧪 test: @ Runs all test suites
test: MIX_ENV=test
test: SHELL:=/bin/bash
test:
	mix test

#🧪 test.cover: @ Runs mix tests and generates coverage
test.cover: MIX_ENV=test
test.cover: SHELL:=/bin/bash
test.cover:
	MIX_ENV=test mix coveralls.html

#🚀 local.deploy.install: @ Install locally all applications using helm+kubernetes and run
local.deploy.install: SHELL:=/bin/bash
local.deploy.install:
	helm install ${EX_APP_NAME} devops/helm/${EX_APP_NAME} --set GITHUB_SHA=`git rev-parse HEAD` --values devops/helm/values/local-values.yaml --create-namespace --namespace ${EX_APP_NAME}

#🔙 local.deploy.uninstall: @ Uninstall all applications from kubernetes
local.deploy.uninstall: SHELL:=/bin/bash
local.deploy.uninstall:
	helm uninstall ${EX_APP_NAME} -n ${EX_APP_NAME}
