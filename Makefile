test:
	bats ./tests
.PHONY: test

lint:
	pre-commit run --all-files
.PHONY: lint
