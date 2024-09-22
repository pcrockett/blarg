test:
	@python3 --version
	@bats ./tests
.PHONY: test

lint:
	@pre-commit run --all-files
.PHONY: lint

ci:
	@bin/python-version-test.sh
.PHONY: ci
