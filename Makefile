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

ci-shell:
	@docker run --rm -it \
		--mount "type=bind,source=.,target=/app,readonly" \
		"blarg-ci:3.14" /bin/bash
.PHONY: ci-shell

install:
	cp blarg ~/.local/bin
.PHONY: install
