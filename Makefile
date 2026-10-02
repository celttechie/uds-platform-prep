# ==============================================================================
# UDS Platform Prep Automation Makefile
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help
help: ## Display available targets and descriptions
	@echo "=============================================================================="
	@echo "                   UDS PLATFORM PREP AUTOMATION PIPELINE                      "
	@echo "=============================================================================="
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo "=============================================================================="

.PHONY: configure
configure: ## Create target.env configuration if not present
	@if [ ! -f target.env ]; then \
		cp target.env.example target.env; \
		echo "Created target.env from template. Edit target.env with your host details."; \
	else \
		echo "target.env already exists."; \
	fi

.PHONY: update-versions
update-versions: ## Query GitHub APIs for latest releases of UDS, Zarf, Lula, K3s
	@./scripts/update-versions.sh

.PHONY: download
download: ## Download all toolchains and airgap packages based on versions.env
	@./scripts/download-payloads.sh

.PHONY: deploy
deploy: ## Deploy toolchains, K8s runtime, and Zarf init to target host
	@./scripts/deploy-target.sh

.PHONY: status
status: ## Check remote cluster nodes, pods, and Zarf status
	@if [ -f kubeconfig ]; then \
		kubectl --kubeconfig=kubeconfig get nodes -o wide; \
		echo ""; \
		kubectl --kubeconfig=kubeconfig get pods -A -o wide; \
	else \
		source target.env 2>/dev/null || source target.env.example; \
		SSH_CMD="ssh -o StrictHostKeyChecking=no"; \
		[ -n "$${JUMP_HOST}" ] && SSH_CMD="$${SSH_CMD} -J $${JUMP_HOST}"; \
		[ -n "$${SSH_KEY}" ] && SSH_CMD="$${SSH_CMD} -i $${SSH_KEY}"; \
		$${SSH_CMD} $${TARGET_USER}@$${TARGET_HOST} "sudo kubectl get nodes -o wide; echo ''; sudo kubectl get pods -A"; \
	fi

.PHONY: clean
clean: ## Remove downloaded payloads and local kubeconfig
	@rm -rf payloads/bin/* payloads/packages/* kubeconfig
	@touch payloads/bin/.gitkeep payloads/packages/.gitkeep
	@echo "Payloads and cached kubeconfig cleaned."
