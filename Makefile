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
IOS_LOG    := $(KMP)/build/xcodebuild.log
SWIFTLINT  := mise exec -- swiftlint
SWIFT_FORMAT := xcrun swift-format

.PHONY: help tools hooks harness-check guard-protected guard-ignored guard-toolchain \
        guard-suppressions kmp-test kmp-build kmp-test-all ios-build swiftlint-analyze fmt fmt-check lint verify check

## ---------------------------------------------------------------- overview
help: ## Show this help
	grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---------------------------------------------------------------- harness
tools: ## Install the exact toolchain versions pinned in mise.toml
	$(Q) tools mise install

hooks: ## Point git at the repository owned hooks (hooks/)
	$(Q) hooks sh scripts/hooks/install.sh

harness-check: ## The harness itself: tests of the guards (node --test scripts/**/*.test.ts)
	$(Q) harness-check:scripts sh -c 'node --test $$(find scripts -name "*.test.ts")'

guard-protected: ## Fail when a protected path changed relative to refs/harness/approved without an approved apply script (fails when no base exists)
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

ios-build: ## Clean-build iosApp for a generic iOS Simulator destination, unsigned; keeps the compiler log for swiftlint-analyze
	$(Q) ios-build sh -c "mkdir -p $(KMP)/build && cd $(KMP) && xcodebuild -project $(IOS_PROJ) -scheme $(IOS_SCHEME) \
	  -destination 'generic/platform=iOS Simulator' -derivedDataPath $(IOS_DERIVED) \
	  CODE_SIGNING_ALLOWED=NO clean build >$(IOS_LOG) 2>&1 || { cat $(IOS_LOG); exit 1; }"

# swiftlint's analyzer_rules need the compiler invocations, so this reads the
# log of the clean ios-build. SwiftLint silently analyses nothing when the
# paths it is given do not match the ones in the log (e.g. /tmp vs
# /private/tmp), so the source path is resolved physically and a run that
# analysed 0 files fails.
swiftlint-analyze: ios-build ## swiftlint analyze --strict over ios-build's compiler log; fails when no file was analysed
	$(Q) swiftlint-analyze sh -c 'src=$$(cd $(IOS_SRC) && pwd -P) && \
	  out=$$($(SWIFTLINT) analyze --strict --config quality/swift/swiftlint.yml --compiler-log-path $(IOS_LOG) "$$src" 2>&1); \
	  status=$$?; printf "%s\n" "$$out"; [ $$status -eq 0 ] || exit $$status; \
	  printf "%s\n" "$$out" | grep -Eq " in [1-9][0-9]* files?\.$$" || { echo "swiftlint analyze: no file analysed; $(IOS_LOG) has no compiler invocation for $$src"; exit 1; }'

## ---------------------------------------------------------------- formatting & static analysis
fmt: ## Reformat product code in place: ktlintFormat (Kotlin) + swift-format (Swift)
	$(Q) fmt:kotlin sh -c "cd $(KMP) && $(GRADLEW) ktlintFormat"
	$(Q) fmt:swift $(SWIFT_FORMAT) format --configuration quality/swift/swift-format.json --recursive --in-place $(IOS_SRC)

fmt-check: ## Check formatting without modifying: ktlintCheck (Kotlin) + swift-format lint --strict (Swift)
	$(Q) fmt-check:kotlin sh -c "cd $(KMP) && $(GRADLEW) ktlintCheck"
	$(Q) fmt-check:swift $(SWIFT_FORMAT) lint --strict --configuration quality/swift/swift-format.json --recursive $(IOS_SRC)

lint: guard-suppressions fmt-check ## Full static-analysis gate: formatting (fmt-check) + detekt + Android Lint + swiftlint --strict + guard-suppressions
	$(Q) lint:detekt sh -c "cd $(KMP) && $(GRADLEW) detektAll"
	$(Q) lint:android sh -c "cd $(KMP) && $(GRADLEW) lint"
	$(Q) lint:swiftlint $(SWIFTLINT) lint --strict --config quality/swift/swiftlint.yml $(IOS_SRC)

## ---------------------------------------------------------------- aggregate
verify: harness-check guard-protected guard-ignored guard-toolchain guard-suppressions fmt-check lint kmp-test ## Fast checks: harness, protection, formatting, static analysis, sharedLogic/sharedUI host tests. What the Claude Code Stop hook runs

check: verify kmp-build kmp-test-all ios-build swiftlint-analyze ## Every quality gate: verify, plus the Android and iOS builds, swiftlint analyze and the full sharedLogic test suite. Run before pushing
