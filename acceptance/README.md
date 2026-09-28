# acceptance

Executable acceptance criteria. Every criterion in `PRODUCT.md` §7 has exactly
one test here that carries its identifier:

- **`shared/`** — `AC-B` criteria: Kotlin tests of the shared logic in
  `shared/src/commonTest/kotlin`, compiled against `clients/kmp/sharedLogic`
  and run on the Android host and the iOS simulator (`make acceptance-shared`).
  The test is the class or function named in the criterion's Test column
  (`TestCreateLedger`); it must pass on both targets.
- **`ios/`** — `AC-F` and `AC-E` criteria on iOS: XCUITests compiled into the
  `iosAppAcceptanceTests` target and run by the `iosAppAcceptance` scheme
  (`make acceptance-ios`). The identifier is in the test's class or method
  name, `AC_F_102` since Swift names cannot hold `-` (`ios/README.md`).
- Android (`AC-F` / `AC-E` as Compose UI tests) is not wired yet; until it is,
  a criterion counts as passing on its iOS test alone.

These tests are written before the implementation, from the criterion's
Given/When/Then, and are part of the protected harness: the session that
implements the product does not edit them. A test asserts the concrete values
the criterion names, never only that something exists, that a call happened,
or that a list is empty.

`shared/` joins the Gradle build (`clients/kmp`, project `:acceptanceShared`)
only when `-Pmoneging.acceptance` is given, which `make acceptance-shared`
does: a test written ahead of the code does not compile yet, and must not
break `make verify`. The same target runs ktlint, detekt and Android Lint over
it. To format it: `cd clients/kmp && ./gradlew -Pmoneging.acceptance
:acceptanceShared:ktlintFormat`.

`make acceptance` (part of `make check`, not of `make verify`) runs both
suites, then `make acceptance-gate`: every criterion of the stages up to
`quality/stage.txt` must pass. `make status` runs `make -k check`, reads the
machine-readable results of these suites (JUnit XML, the xcresult bundle) and
writes `test-results/STATUS.md`.
