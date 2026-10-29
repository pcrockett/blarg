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

ci: up lint
	@bin/python-version-test.sh
.PHONY: ci

install:
	cp blarg ~/.local/bin
.PHONY: install

release:
	./bin/release.sh
.PHONY: release
