# Deployment Makefile for the NASFAA web pages.
#
# Mirrors the pattern used by the sister project ../cantilever-fea/:
# static assets synced to a per-app subdirectory of the blurbpress.com
# S3 bucket using the blurbpress_deploy profile.
#
# Layout on the bucket:
#   s3://blurbpress.com/nasfaa/shared/            (canonical theme + tokens, served from web/shared/)
#   s3://blurbpress.com/nasfaa/disclose-or-not/   (served from web/walkthrough/)
#   s3://blurbpress.com/nasfaa/disclosure-quiz/   (served from web/quiz/)
#   s3://blurbpress.com/nasfaa/about/             (served from web/about/ — outline writeup, unlinked)
#
# The descriptive leaf names (disclose-or-not, disclosure-quiz) are
# user-visible URLs chosen for search and human friendliness; the local
# source directories (web/walkthrough, web/quiz) keep their internal
# names to match the bin/nasfaa CLI subcommands.
#
# Both pages reference ../shared/... from their HTML, which resolves to
# /nasfaa/shared/... on the bucket — sibling under the nasfaa/ namespace
# so it doesn't collide with other projects served from blurbpress.com.
#
# Targets:
#   make build              regenerate data.js + JSON for both pages
#   make test               run node-side tests for both pages
#   make deploy             deploy-shared + deploy-walkthrough + deploy-quiz + deploy-about
#   make deploy-shared      sync web/shared/ (no build dependency)
#   make deploy-walkthrough deploy just the walkthrough page
#   make deploy-quiz        deploy just the quiz page
#   make deploy-about       deploy just the about page (no build dependency)
#   make dry                show what `make deploy` would upload, change nothing
#   make verify             curl the deployed pages and check HTTP 200
#   make clean              remove generated data.js / *.json

BUCKET   := blurbpress.com
PROFILE  := blurbpress_deploy

WALKTHROUGH_SUBDIR := nasfaa/disclose-or-not
QUIZ_SUBDIR        := nasfaa/disclosure-quiz
SHARED_SUBDIR      := nasfaa/shared
ABOUT_SUBDIR       := nasfaa/about

WALKTHROUGH_DIR := web/walkthrough
QUIZ_DIR        := web/quiz
SHARED_DIR      := web/shared
ABOUT_DIR       := web/about

# Files in each page directory that are source-only and must NOT ship.
# *.rb / *.mjs / verify_* are diagnostic; README.md is internal.
COMMON_EXCLUDES := \
	--exclude '*.rb' \
	--exclude '*.mjs' \
	--exclude 'verify_*' \
	--exclude 'README.md' \
	--exclude 'build.js' \
	--exclude '.DS_Store'

SYNC_FLAGS := --delete --cache-control no-store --profile $(PROFILE)

.PHONY: build text-verify test test-coverage survey time-analysis deploy deploy-shared deploy-walkthrough deploy-quiz deploy-about dry verify clean

# All front-end test files (test-*.mjs in web/*/). New tests go here as
# they're added; the wildcard saves the Makefile from drift.
JS_TESTS := $(wildcard web/quiz/test-*.mjs) $(wildcard web/walkthrough/test-*.mjs) $(wildcard web/shared/test-*.mjs)

build:
	cd $(WALKTHROUGH_DIR) && ruby build.rb
	cd $(QUIZ_DIR) && node build.js

# Local-only text-verification page (web/text-verify/).  NOT in the
# deploy aggregate — this is a working tool for cross-checking the
# YAML question text against the printed PDF.  Re-run after editing
# nasfaa_questions.yml; verification state lives in localStorage.
text-verify:
	ruby web/text-verify/build.rb

test:
	node --test $(JS_TESTS)
	# TODO: walkthrough's run-tests-node.mjs and run-dag-cross-verify.mjs are
	# broken under current Node (ESM/CJS interop). See ROADMAP "Restore
	# walkthrough Node test runners" before wiring them back in here.

# Front-end coverage via Node 23+'s built-in --experimental-test-coverage.
# Restricted to web/{quiz,walkthrough,shared}/*.js (runtime modules only;
# excludes test files, build scripts, and generated data.js).
test-coverage:
	node --test --experimental-test-coverage \
		--test-coverage-include='web/quiz/*.js' \
		--test-coverage-include='web/walkthrough/*.js' \
		--test-coverage-include='web/shared/*.js' \
		--test-coverage-exclude='web/*/data.js' \
		--test-coverage-exclude='web/*/build.js' \
		--test-coverage-exclude='web/*/tests.js' \
		$(JS_TESTS)

# Coverage + refactor-candidate survey. Reads coverage/.resultset.json
# (run `COVERAGE=1 bundle exec rspec` first to refresh) and walks web/
# for untested JS modules. See .claude/skills/coverage-survey/SKILL.md.
survey:
	bin/coverage-survey

# Regenerate docs/time-spent.md from git history.  Re-run any time the
# session table or churn numbers are stale; see the section at the
# bottom of the generated file for the heuristic + its limitations.
time-analysis:
	bin/time-analysis > docs/time-spent.md

deploy: build deploy-shared deploy-walkthrough deploy-quiz deploy-about

deploy-shared:
	aws s3 sync $(SHARED_DIR)/ "s3://$(BUCKET)/$(SHARED_SUBDIR)/" \
		$(SYNC_FLAGS)

deploy-walkthrough: build
	aws s3 sync $(WALKTHROUGH_DIR)/ "s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

deploy-quiz: build
	aws s3 sync $(QUIZ_DIR)/ "s3://$(BUCKET)/$(QUIZ_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

deploy-about:
	aws s3 sync $(ABOUT_DIR)/ "s3://$(BUCKET)/$(ABOUT_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

dry: build
	@echo "=== shared -> s3://$(BUCKET)/$(SHARED_SUBDIR)/ ==="
	aws s3 sync $(SHARED_DIR)/ "s3://$(BUCKET)/$(SHARED_SUBDIR)/" $(SYNC_FLAGS) --dryrun
	@echo
	@echo "=== walkthrough -> s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/ ==="
	aws s3 sync $(WALKTHROUGH_DIR)/ "s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES) --dryrun
	@echo
	@echo "=== quiz -> s3://$(BUCKET)/$(QUIZ_SUBDIR)/ ==="
	aws s3 sync $(QUIZ_DIR)/ "s3://$(BUCKET)/$(QUIZ_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES) --dryrun
	@echo
	@echo "=== about -> s3://$(BUCKET)/$(ABOUT_SUBDIR)/ ==="
	aws s3 sync $(ABOUT_DIR)/ "s3://$(BUCKET)/$(ABOUT_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES) --dryrun

verify:
	@echo "--- walkthrough ---"
	@for url in \
	  "https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
	  "https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/index.html" \
	  "https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/test.html" \
	  "https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/data.js"; do \
	  code=$$(curl -s -o /dev/null -w "%{http_code}" "$$url"); \
	  printf "  %-70s %s\n" "$$url" "$$code"; \
	done
	@echo "--- quiz ---"
	@for url in \
	  "https://$(BUCKET)/$(QUIZ_SUBDIR)/" \
	  "https://$(BUCKET)/$(QUIZ_SUBDIR)/index.html" \
	  "https://$(BUCKET)/$(QUIZ_SUBDIR)/data.js"; do \
	  code=$$(curl -s -o /dev/null -w "%{http_code}" "$$url"); \
	  printf "  %-70s %s\n" "$$url" "$$code"; \
	done
	@echo "--- shared ---"
	@for url in \
	  "https://$(BUCKET)/$(SHARED_SUBDIR)/tokens.css" \
	  "https://$(BUCKET)/$(SHARED_SUBDIR)/theme.js" \
	  "https://$(BUCKET)/$(SHARED_SUBDIR)/theme-toggle.css"; do \
	  code=$$(curl -s -o /dev/null -w "%{http_code}" "$$url"); \
	  printf "  %-70s %s\n" "$$url" "$$code"; \
	done
	@echo "--- about ---"
	@for url in \
	  "https://$(BUCKET)/$(ABOUT_SUBDIR)/" \
	  "https://$(BUCKET)/$(ABOUT_SUBDIR)/index.html"; do \
	  code=$$(curl -s -o /dev/null -w "%{http_code}" "$$url"); \
	  printf "  %-70s %s\n" "$$url" "$$code"; \
	done

clean:
	rm -f $(WALKTHROUGH_DIR)/data.js $(WALKTHROUGH_DIR)/rules.json $(WALKTHROUGH_DIR)/questions.json $(WALKTHROUGH_DIR)/scenarios.json
	rm -f $(QUIZ_DIR)/data.js $(QUIZ_DIR)/rules.json $(QUIZ_DIR)/scenarios.json
