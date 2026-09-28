# Moneging — Repository Harness entry points.
#
# These targets are the only interface an agent (or a human) needs. Every
# check is an error, never a warning; if a target fails, fix the code.
# Output is deliberately terse: "ok: <target>" on success, the diagnostics on
# failure (scripts/quiet.sh; MONEGING_VERBOSE=1 shows everything).

SHELL := /bin/sh
.DEFAULT_GOAL := help
.SILENT:

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
Q    := sh $(ROOT)/scripts/quiet.sh

KMP        := $(ROOT)/clients/kmp
GRADLEW    := ./gradlew
IOS_PROJ   := iosApp/iosApp.xcodeproj
IOS_SCHEME := iosApp
IOS_DERIVED := $(ROOT)/clients/kmp/build/DerivedData
IOS_SRC    := $(KMP)/iosApp/iosApp
SWIFTLINT  := mise exec -- swiftlint
SWIFT_FORMAT := xcrun swift-format

.PHONY: help tools hooks harness-approve harness-check guard-protected guard-ignored guard-toolchain \
        guard-suppressions kmp-test kmp-build kmp-test-all ios-build fmt fmt-check lint verify check

## ---------------------------------------------------------------- overview
help: ## Show this help
	grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---------------------------------------------------------------- harness
tools: ## Install the exact toolchain versions pinned in mise.toml
	$(Q) tools mise install

hooks: ## Point git at the repository owned hooks (hooks/) and anchor refs/harness/approved
	$(Q) hooks sh scripts/hooks/install.sh

harness-approve: ## Human-only: record the current HEAD as the last harness state the human reviewed and approved
	if [ -n "$${CLAUDECODE:-}" ] || [ -n "$${CLAUDE_PROJECT_DIR:-}" ]; then \
	  echo "harness-approve: refusing to run inside a Claude Code session (CLAUDECODE/CLAUDE_PROJECT_DIR is set)." >&2; \
	  echo "This records the human's own review; run it from the human's own shell, outside any session." >&2; \
	  exit 1; \
	fi
	git update-ref refs/harness/approved HEAD
	echo "harness: approved state moved to $$(git rev-parse --short HEAD)"

harness-check: ## The harness itself: tests of the guards and the harness lock (node --test scripts/**/*.test.ts)
	$(Q) harness-check:scripts sh -c 'node --test $$(find scripts -name "*.test.ts")'

guard-protected: ## Fail when a protected path changed relative to the base while LOCKED (fails when no base exists)
	$(Q) guard-protected sh scripts/guard/protected-paths.sh

guard-ignored: ## Fail when a protected path is git-ignored
	$(Q) guard-ignored sh scripts/guard/ignored-paths.sh

guard-toolchain: ## Fail when the running node/java major does not match mise.toml
	$(Q) guard-toolchain node scripts/guard/toolchain.ts

guard-suppressions: ## Every lint suppression (Kotlin, Swift, Gradle escape hatches) must be registered in quality/suppressions.allow
	$(Q) guard-suppressions sh scripts/guard/suppressions.sh

## ---------------------------------------------------------------- clients/kmp (Kotlin Multiplatform)
kmp-test: ## Fast Android host unit tests of sharedLogic and sharedUI
	$(Q) kmp-test:sharedLogic sh -c "cd $(KMP) && $(GRADLEW) :sharedLogic:testAndroidHostTest"
	$(Q) kmp-test:sharedUI sh -c "cd $(KMP) && $(GRADLEW) :sharedUI:testAndroidHostTest"

kmp-build: ## Assemble the debug Android app
	$(Q) kmp-build sh -c "cd $(KMP) && $(GRADLEW) :androidApp:assembleDebug"

kmp-test-all: ## Every sharedLogic test target (Android host + iOS simulator klibs)
	$(Q) kmp-test-all sh -c "cd $(KMP) && $(GRADLEW) :sharedLogic:allTests"

ios-build: ## Build iosApp for a generic iOS Simulator destination, unsigned
	$(Q) ios-build sh -c "cd $(KMP) && xcodebuild -project $(IOS_PROJ) -scheme $(IOS_SCHEME) \
	  -destination 'generic/platform=iOS Simulator' -derivedDataPath $(IOS_DERIVED) \
	  CODE_SIGNING_ALLOWED=NO build"

## ---------------------------------------------------------------- formatting & static analysis
fmt: ## Reformat product code in place: ktlintFormat (Kotlin) + swift-format (Swift)
	$(Q) fmt:kotlin sh -c "cd $(KMP) && $(GRADLEW) ktlintFormat"
	$(Q) fmt:swift $(SWIFT_FORMAT) format --configuration quality/swift/swift-format.json --recursive --in-place $(IOS_SRC)

fmt-check: ## Check formatting without modifying: ktlintCheck (Kotlin) + swift-format lint --strict (Swift)
	$(Q) fmt-check:kotlin sh -c "cd $(KMP) && $(GRADLEW) ktlintCheck"
	$(Q) fmt-check:swift $(SWIFT_FORMAT) lint --strict --configuration quality/swift/swift-format.json --recursive $(IOS_SRC)

lint: guard-suppressions ## Full static-analysis gate: detekt + ktlint check + Android Lint + swiftlint --strict + swift-format lint --strict + guard-suppressions
	$(Q) lint:ktlint sh -c "cd $(KMP) && $(GRADLEW) ktlintCheck"
	$(Q) lint:detekt sh -c "cd $(KMP) && $(GRADLEW) detekt"
	$(Q) lint:detekt-kmp sh -c "cd $(KMP) && $(GRADLEW) :sharedLogic:check :sharedUI:check -x testAndroidHostTest -x allTests -x iosSimulatorArm64Test"
	$(Q) lint:android sh -c "cd $(KMP) && $(GRADLEW) :androidApp:lint"
	$(Q) lint:swiftlint $(SWIFTLINT) lint --strict --config quality/swift/swiftlint.yml $(IOS_SRC)
	$(Q) lint:swift-format $(SWIFT_FORMAT) lint --strict --configuration quality/swift/swift-format.json --recursive $(IOS_SRC)

## ---------------------------------------------------------------- aggregate
verify: harness-check guard-protected guard-ignored guard-toolchain guard-suppressions fmt-check lint kmp-test ## Fast checks: harness, protection, formatting, static analysis, sharedLogic/sharedUI host tests. What the Claude Code Stop hook runs

check: verify kmp-build kmp-test-all ios-build ## Every quality gate: verify, plus the Android and iOS builds and the full sharedLogic test suite. Run before pushing
