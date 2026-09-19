test:
	@python3 --version
	@bats ./tests
.PHONY: test

up:
	@docker compose --file tests/ssh/compose.yml up --wait --build
.PHONY: up

down:
	@docker compose --file tests/ssh/compose.yml down
.PHONY: down

lint:
	@pre-commit run --all-files
.PHONY: lint

ci: up
	@bin/python-version-test.sh
.PHONY: ci

ci-shell: up
	@docker run --rm -it \
		--mount "type=bind,source=.,target=/app,readonly" \
		"blarg-ci:3.14" /bin/bash
.PHONY: ci-shell

install:
	cp blarg ~/.local/bin
.PHONY: install
