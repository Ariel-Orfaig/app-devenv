# Shortcuts for the mobile dev container. Run `make help`.
COMPOSE ?= docker compose
SERVICE := mobile-dev

.PHONY: help build up shell claude doctor down usb kvm clean

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'

.env:
	cp .env.example .env
	sed -i.bak "s/^USER_UID=.*/USER_UID=$$(id -u)/; s/^USER_GID=.*/USER_GID=$$(id -g)/" .env && rm -f .env.bak

build: .env ## Build the image
	mkdir -p workspace
	$(COMPOSE) build

up: .env ## Start the container in the background
	mkdir -p workspace
	$(COMPOSE) up -d

shell: up ## Open a shell in the container
	$(COMPOSE) exec $(SERVICE) bash -l

claude: up ## Start Claude Code in /workspace
	$(COMPOSE) exec $(SERVICE) claude

doctor: up ## Check the toolchain inside the container
	$(COMPOSE) exec $(SERVICE) devenv-doctor

usb: .env ## Start with USB passthrough (Linux hosts)
	$(COMPOSE) -f docker-compose.yml -f docker-compose.usb.yml up -d

kvm: .env ## Start with /dev/kvm for the emulator (Linux hosts)
	$(COMPOSE) -f docker-compose.yml -f docker-compose.kvm.yml up -d

down: ## Stop the container
	$(COMPOSE) down

clean: ## Stop and delete the container AND its volumes (logs out Claude, clears caches)
	$(COMPOSE) down -v
