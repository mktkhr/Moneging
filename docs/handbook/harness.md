# ハーネスガイド

Moneging の Repository Harness は3層で品質と保護ルールを強制する。

## 3層

1. **PreToolUse（ツール実行前）**: `scripts/guard/tool-policy.ts` が Edit/Write/
   NotebookEdit/Bash を検査する。保護パス（下記）への書き込みは、メインセッション
   を含むすべてのセッションで拒否される。`--no-verify`、`core.hooksPath` の書き換え、
   `git push --force`、`git add -f`、`MONEGING_ALLOW_HARNESS_CHANGE` の使用なども
   常に拒否される。`reviewer` サブエージェントはリポジトリ内に何も書き込めない。
2. **Stop（ターン終了時）**: `scripts/guard/stop-gate.sh` が未追跡ファイルの有無
   を確認し、`make -k verify` を実行する。`harness-check` はベースラインに関係
   なく常にグリーンでなければならない。それ以外のゲートは、前のターンで通って
   いたものが新たに落ちた場合だけターンを止める。3回連続で拒否すると諦めて
   ユーザーに伝える（その判定は同一のツリー状態にキャッシュされ、ツリーが変わ
   るまで再判定しない）。サブエージェントの実行中（`scripts/guard/subagent-mark.sh`
   が SubagentStart/SubagentStop で置く目印のうち2時間以内のものがある間）は判定
   しない。拒否の直後の停止（`stop_hook_active`）で、ツリーが拒否したときのまま
   なら、再び拒否せずにユーザーに伝える。
3. **git hooks**: `hooks/pre-commit` はステージ済みの保護パス変更を拒否し
   （`MONEGING_ALLOW_HARNESS_CHANGE=1` が無い限り）、Kotlin/Swift の整形を確認
   する。`hooks/pre-push` は `make check` をフルで実行する。`make guard-protected`
   は `refs/harness/approved` からの保護パスの差分を検出する。

## 何が保護されているか

`quality/protected-paths.txt` に列挙: `quality/` `hooks/` `scripts/guard/`
`scripts/hooks/` `scripts/quiet.sh` `scripts/status*.ts`
`scripts/ios-ui-test.sh` `Makefile` `mise.toml` `.claude/`
`CLAUDE.md` `.gitignore` `clients/kmp/.gitignore`、Gradle の一部設定ファイル、
`clients/kmp/build-logic` `clients/kmp/.editorconfig`
`clients/kmp/iosApp/Configuration/Config.xcconfig`、スキーム
`iosAppAcceptance.xcscheme`、`PRODUCT.md` `acceptance/`。
`.git` と `.claude/settings.local.json` も常に拒否される。

## ハーネスの変え方（変更スクリプト）

ハーネスはセッションが直接編集しない。変更は、リポジトリの外に置く変更一式で
1回で入れる。

1. セッションが変更一式をリポジトリの外（例: `~/.cache/moneging-harness/<名前>/`）
   に作る。中身は差し替えるファイル一式と `apply.sh`。
2. `apply.sh` は、想定した HEAD であることの確認 → ファイルのコピー →
   `make harness-check` → `MONEGING_ALLOW_HARNESS_CHANGE=1` でのコミット →
   `refs/harness/approved` の更新、を1回で行う。途中で失敗したら何も残さない。
3. セッションは内容を説明して止まる。人間が確認し、実行を許可する
   （`apply.sh` を含むコマンドは、`.claude/settings.json` の `permissions.ask` により
   毎回確認される）。

受け入れテスト（`acceptance/`）と `PRODUCT.md` も同じ手順で変更する。

## 初回セットアップ

```sh
mise install   # mise.toml に固定した node/java を導入（make tools でも可）
make hooks     # git hooks を hooks/ に向ける
```

## 主な make ターゲット

- `make verify` — 高速チェック一式（harness-check, guard-protected,
  guard-ignored, guard-toolchain, guard-suppressions, fmt-check, lint,
  kmp-test）。Stop hook が実行するのと同じ。
- `make check` — verify に加え、Android/iOS のビルド、`swiftlint analyze`、
  フルテストスイート、iOS UI テスト（`ios-ui-test`）、受け入れテスト
  （`acceptance`）。push 前に実行する。
- `make status` — `make -k check` を実行し、実際に走った結果から
  `test-results/STATUS.md` を書く。進捗はこの1行で報告する。
- `make fmt` / `make fmt-check` — Kotlin（ktlintFormat/ktlintCheck）と
  Swift（`xcrun swift-format`）を、その場で直すか（fmt）検査だけするか
  （fmt-check）。
- `make lint` — 静的解析一式。下記「lint ゲート」を参照。
- `make tools` — mise.toml のバージョンをインストール。
- `make hooks` — git hooks を配線する。

## 受け入れテストとステージ

`PRODUCT.md` §7 の基準ごとに、実装より前に書く実行可能なテストが
`acceptance/` にある（保護パス。構成は `acceptance/README.md`）。

- `acceptance/shared/` — AC-B。`sharedLogic` に対する Kotlin テスト。
  Gradle の `:acceptanceShared`（`-Pmoneging.acceptance` の時だけ build に入る。
  未実装の API を参照して `make verify` を壊さないため）。Android host と
  iOS simulator の両方で走る。`make acceptance-shared`。
- `acceptance/ios/` — AC-F/AC-E の XCUITest。`iosAppAcceptanceTests` ターゲット
  （同期フォルダ）と `iosAppAcceptance` スキームで走る。テスト名に
  `AC_F_102` の形で ID を含める。`make acceptance-ios`。
- Android の受け入れテストは未配線。

`quality/stage.txt` は開いているステージ（§8）の番号。`make acceptance-gate`
は 1..その番号 の全基準が pass であることを要求する（0 なら何も要求しない）。
下げない。`make acceptance` = 両スイート + gate で、`make check` に含まれ
`make verify` には含まれない。`make status` は JUnit XML
（`clients/kmp/build/acceptance-shared/test-results`）と xcresult
（`test-results/acceptance/ios.xcresult`）を読んで基準ごとに
PASS/FAIL/MISSING を書く。

`make ios-ui-test` は iosApp スキームの既定テストプランを
`build-for-testing` → `test-without-building`（並列テスト有効、
`IOS_TEST_WORKERS`、既定 2。並列化の単位はテストクラス）で走らせる。
依存するファイル（iosApp、sharedLogic、acceptance/ios、Gradle 設定）が
前回の成功時から変わっていなければ `ok: ios-ui-test (skipped: unchanged)` で
飛ばす（`.cache/ios-ui-test`）。`make ios-ui-test FORCE=1` で常に実行。
シミュレータは `IOS_TEST_DEVICE`（既定 `iPhone 17`）。UI テストと受け入れ
テストのランナーには `UITestDisableAnimations=YES` が渡る
（`TEST_RUNNER_` 経由）。テストは起動するアプリに
`-UITestDisableAnimations YES` として渡す
（`XCUIApplication.launchedForAcceptance(arguments:)`）。

進捗は `make status` の1行で報告する。`TODO.md`（次にやること）と
`DECISIONS.md`（なぜ。`PRODUCT.md` に反しない）を止める前に更新する。
ステージを閉じる前に `test-auditor` サブエージェントで監査する。

## lint ゲート

すべて警告=エラー、ベースライン無し。抑制・ゲートを弱める設定は
`quality/suppressions.allow` に登録が無い限り `guard-suppressions`
（`scripts/guard/suppressions.ts`）が拒否する（対象の一覧は同ファイル冒頭）。
Kotlin 側の厳格さの設定はすべて convention plugin
`clients/kmp/build-logic`（`id("moneging.quality")`）にあり、各モジュールの
build.gradle.kts はそれを適用するだけ。

| 対象 | ツール | 設定 | 実行 |
| --- | --- | --- | --- |
| Kotlin 整形 | ktlint 1.8.0（`ktlint_official`） | `clients/kmp/.editorconfig` | `make fmt` / `make fmt-check` |
| Kotlin 静的解析 | detekt 2.0.0-alpha.6（全ルール、テストも対象） | `quality/kotlin/detekt.yml` | `make lint`（`detektAll`） |
| Kotlin コンパイラ | `allWarningsAsErrors` | build-logic | ビルド時 |
| Android Lint | 全チェック・警告=エラー（全3モジュール） | `quality/kotlin/android-lint.xml` | `make lint`（`lint`） |
| Swift 静的解析 | SwiftLint 0.65.1 `--strict` | `quality/swift/swiftlint.yml` | `make lint`、`make check`（`swiftlint analyze`） |
| Swift 整形 | `xcrun swift-format` | `quality/swift/swift-format.json` | `make fmt` / `make fmt-check` |
| Swift コンパイラ | `SWIFT_TREAT_WARNINGS_AS_ERRORS` | `clients/kmp/iosApp/Configuration/Config.xcconfig` | `make check`（`ios-build`） |

`make lint` は `fmt-check` を前提に含む。既知の範囲の制約:

- detekt の型解決は Android/JVM コンパイル（commonMain + androidMain、
  テスト、androidApp、build-logic）のみ。iosMain/iosTest は detekt 2.0.0-alpha.6
  が Kotlin/Native を型解決できないため、型解決なしのルールだけが掛かる。
- Android Lint の新バージョン検出3種（`AndroidGradlePluginVersion`、
  `GradleDependency`、`NewerVersionAvailable`）は無効。上流のリリースで同じ
  コミットが翌日落ちるため。バージョン更新は専用の変更で行う。

`hooks/pre-commit` はステージ済みの Kotlin/Swift ファイルの内容（インデックス）
を一時ディレクトリへ書き出し、mise 固定の ktlint と `xcrun swift-format lint`
で検査する高速版。完全な静的解析は `make lint` / `make check`
（`hooks/pre-push` で強制）で行う。
