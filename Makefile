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
#   make deploy             deploy-shared + deploy-walkthrough + deploy-quiz
#   make deploy-shared      sync web/shared/ (no build dependency)
#   make deploy-walkthrough deploy just the walkthrough page
#   make deploy-quiz        deploy just the quiz page
#   make dry                show what `make deploy` would upload, change nothing
#   make verify             curl the deployed pages and check HTTP 200
#   make clean              remove generated data.js / *.json

BUCKET   := blurbpress.com
PROFILE  := blurbpress_deploy

WALKTHROUGH_SUBDIR := nasfaa/disclose-or-not
QUIZ_SUBDIR        := nasfaa/disclosure-quiz
SHARED_SUBDIR      := nasfaa/shared

WALKTHROUGH_DIR := web/walkthrough
QUIZ_DIR        := web/quiz
SHARED_DIR      := web/shared

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

.PHONY: build test deploy deploy-shared deploy-walkthrough deploy-quiz dry verify clean

build:
	cd $(WALKTHROUGH_DIR) && ruby build.rb
	cd $(QUIZ_DIR) && node build.js

test:
	node --test $(QUIZ_DIR)/test-citation.mjs
	# TODO: walkthrough's run-tests-node.mjs and run-dag-cross-verify.mjs are
	# broken under current Node (ESM/CJS interop). See ROADMAP "Restore
	# walkthrough Node test runners" before wiring them back in here.

deploy: build deploy-shared deploy-walkthrough deploy-quiz

deploy-shared:
	aws s3 sync $(SHARED_DIR)/ "s3://$(BUCKET)/$(SHARED_SUBDIR)/" \
		$(SYNC_FLAGS)

deploy-walkthrough: build
	aws s3 sync $(WALKTHROUGH_DIR)/ "s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

deploy-quiz: build
	aws s3 sync $(QUIZ_DIR)/ "s3://$(BUCKET)/$(QUIZ_SUBDIR)/" \
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

clean:
	rm -f $(WALKTHROUGH_DIR)/data.js $(WALKTHROUGH_DIR)/rules.json $(WALKTHROUGH_DIR)/questions.json $(WALKTHROUGH_DIR)/scenarios.json
	rm -f $(QUIZ_DIR)/data.js $(QUIZ_DIR)/rules.json $(QUIZ_DIR)/scenarios.json
