SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)
MIX ?= /Users/abby/.local/share/mise/shims/mix

.PHONY: help setup deps test test-stores test-integration test-full credo dialyzer coverage check format clean release publish-release setup-hooks setup-db reset-db logs push-and-publish

help:
	@echo "BotArmyOutcomesRecorder - Outcomes Measurement System"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup           - Set up project (deps.get + install git hooks + setup database)"
	@echo "  make setup-hooks     - Install git hooks for pre-push validation"
	@echo "  make setup-db        - Create and migrate test database"
	@echo "  make reset-db        - Drop and recreate test database"
	@echo ""
	@echo "Development commands:"
	@echo "  make test            - Run all tests (unit + stores)"
	@echo "  make test-stores     - Run storage/aggregator tests"
	@echo "  make test-integration - Run integration tests (requires PostgreSQL)"
	@echo "  make test-full       - Run all tests including integration"
	@echo "  make credo           - Run linter"
	@echo "  make dialyzer        - Run static analysis"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make check           - Run all checks (test, credo, dialyzer)"
	@echo "  make format          - Format Elixir code"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Operations:"
	@echo "  make logs            - Tail outcomes_recorder log"
	@echo ""
	@echo "Release commands:"
	@echo "  make release         - Build OTP release"
	@echo "  make publish-release - Build, package, and publish to GitHub"
	@echo ""
	@echo "Normal workflow:"
	@echo "  git push             - Fast compile+test validation"
	@echo "  make push-and-publish - Push then publish release"
	@echo ""

setup: init deps setup-hooks setup-db
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run: make test"
	@echo "  2. Start developing!"
	@echo ""

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"

setup-db:
	@echo "Setting up test database..."
	@MIX_ENV=test $(MIX) ecto.create || true
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database created and migrations applied"

reset-db:
	@echo "⚠️  Resetting test database (dropping and recreating)..."
	@MIX_ENV=test $(MIX) ecto.drop || true
	@MIX_ENV=test $(MIX) ecto.create
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database reset complete"

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	$(MIX) deps.get

test:
	$(MIX) test

test-stores:
	MIX_ENV=test $(MIX) test --only stores --trace

test-integration:
	$(MIX) test --include integration --trace

test-full:
	$(MIX) test --include integration --trace

credo:
	$(MIX) credo --only warning

dialyzer: deps
	$(MIX) dialyzer

coverage:
	$(MIX) coveralls

check: test credo
	@echo "All checks passed!"

format:
	$(MIX) format

clean:
	$(MIX) clean
	rm -rf _build cover

release: test
	@echo "==============================================="
	@echo "Building OTP release"
	@echo "==============================================="
	rm -rf _build/prod/rel/outcomes_recorder_bot
	MIX_ENV=prod $(MIX) release
	@echo ""
	@echo "✓ Release built successfully"
	@echo "Location: _build/prod/rel/outcomes_recorder_bot/"
	@echo ""

publish-release: release
	@echo "==============================================="
	@echo "Publishing release to GitHub"
	@echo "==============================================="
	@echo ""
	@set -e; \
	VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	if [ -z "$$VERSION" ]; then \
		echo "Failed to resolve version from mix.exs"; \
		exit 1; \
	fi; \
	TARBALL=outcomes_recorder_bot-$$VERSION.tar.gz; \
	echo "Version: $$VERSION"; \
	echo "Creating release tarball..."; \
	tar -czf "$$TARBALL" -C _build/prod/rel outcomes_recorder_bot/; \
	echo "✓ Tarball created: $$TARBALL"; \
	echo ""; \
	echo "Creating GitHub release v$$VERSION..."; \
	if gh release view "v$$VERSION" >/dev/null 2>&1; then \
		gh release upload "v$$VERSION" "$$TARBALL" --clobber; \
	else \
		gh release create "v$$VERSION" "$$TARBALL" \
			--title "Release v$$VERSION" \
			--notes "Outcomes Recorder Bot Elixir release v$$VERSION. Download and deploy with Jenkins." \
			--draft=false; \
	fi; \
	echo "✓ Release published to GitHub"; \
	echo ""; \
	echo "Next steps:"; \
	echo "1. Jenkins will automatically detect the new release"; \
	echo "2. Trigger deployment in Jenkins UI or wait for auto-deployment"; \
	echo ""

push-and-publish:
	@git push && $(MAKE) publish-release

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh outcomes_recorder_bot

.DEFAULT_GOAL := help
