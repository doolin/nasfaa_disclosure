# Deployment Makefile for the NASFAA web pages.
#
# Mirrors the pattern used by the sister project ../cantilever-fea/:
# static assets synced to a per-app subdirectory of the blurbpress.com
# S3 bucket using the blurbpress_deploy profile.
#
# Targets:
#   make build              regenerate data.js + JSON for both pages
#   make deploy             deploy-walkthrough + deploy-quiz (full ship)
#   make deploy-walkthrough deploy just the walkthrough page
#   make deploy-quiz        deploy just the quiz page
#   make dry                show what `make deploy` would upload, change nothing
#   make verify             curl the deployed pages and check HTTP 200

BUCKET   := blurbpress.com
PROFILE  := blurbpress_deploy

WALKTHROUGH_SUBDIR := nasfaa-disclose-or-not
QUIZ_SUBDIR        := nasfaa-disclosure-quiz

WALKTHROUGH_DIR := web/walkthrough
QUIZ_DIR        := web/quiz

# Files in each page directory that are source-only and must NOT ship.
# lambda.js is stale (blurbpress is S3 static, not Lambda).
# *.rb / *.mjs / verify_* are diagnostic; README.md is internal.
COMMON_EXCLUDES := \
	--exclude '*.rb' \
	--exclude '*.mjs' \
	--exclude 'lambda.js' \
	--exclude 'verify_*' \
	--exclude 'README.md' \
	--exclude 'build.js' \
	--exclude '.DS_Store'

SYNC_FLAGS := --delete --cache-control no-store --profile $(PROFILE)

.PHONY: build deploy deploy-walkthrough deploy-quiz dry verify clean

build:
	cd $(WALKTHROUGH_DIR) && ruby build.rb
	cd $(QUIZ_DIR) && node build.js

deploy: build deploy-walkthrough deploy-quiz

deploy-walkthrough: build
	aws s3 sync $(WALKTHROUGH_DIR)/ "s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

deploy-quiz: build
	aws s3 sync $(QUIZ_DIR)/ "s3://$(BUCKET)/$(QUIZ_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES)

dry: build
	@echo "=== walkthrough -> s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/ ==="
	aws s3 sync $(WALKTHROUGH_DIR)/ "s3://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES) --dryrun
	@echo
	@echo "=== quiz -> s3://$(BUCKET)/$(QUIZ_SUBDIR)/ ==="
	aws s3 sync $(QUIZ_DIR)/ "s3://$(BUCKET)/$(QUIZ_SUBDIR)/" \
		$(SYNC_FLAGS) $(COMMON_EXCLUDES) --dryrun

verify:
	@echo "--- walkthrough ---"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/                %{http_code}\n" \
		"https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/index.html      %{http_code}\n" \
		"https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/index.html"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/tokens.css      %{http_code}\n" \
		"https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/tokens.css"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/data.js         %{http_code}\n" \
		"https://$(BUCKET)/$(WALKTHROUGH_SUBDIR)/data.js"
	@echo "--- quiz ---"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(QUIZ_SUBDIR)/                       %{http_code}\n" \
		"https://$(BUCKET)/$(QUIZ_SUBDIR)/"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(QUIZ_SUBDIR)/index.html             %{http_code}\n" \
		"https://$(BUCKET)/$(QUIZ_SUBDIR)/index.html"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(QUIZ_SUBDIR)/tokens.css             %{http_code}\n" \
		"https://$(BUCKET)/$(QUIZ_SUBDIR)/tokens.css"
	curl -s -o /dev/null -w "  https://$(BUCKET)/$(QUIZ_SUBDIR)/data.js                %{http_code}\n" \
		"https://$(BUCKET)/$(QUIZ_SUBDIR)/data.js"

clean:
	rm -f $(WALKTHROUGH_DIR)/data.js $(WALKTHROUGH_DIR)/rules.json $(WALKTHROUGH_DIR)/questions.json $(WALKTHROUGH_DIR)/scenarios.json
	rm -f $(QUIZ_DIR)/data.js $(QUIZ_DIR)/rules.json $(QUIZ_DIR)/scenarios.json
