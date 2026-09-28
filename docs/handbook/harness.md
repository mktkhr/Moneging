# ハーネスガイド

Moneging の Repository Harness は3層で品質と保護ルールを強制する。

## 3層

1. **PreToolUse（ツール実行前）**: `scripts/guard/tool-policy.ts` が Edit/Write/
   NotebookEdit/Bash を検査する。書き込めるパスは呼び出し元の役割で決まる
   （下の表）。`--no-verify`、`core.hooksPath` の書き換え、`git push --force`、
   `git add -f` などハーネスを回避する Bash コマンドは、役割に関わらず常に拒否
   される。
2. **Stop（ターン終了時）**: `scripts/guard/stop-gate.sh` が未追跡ファイルの有無
   を確認し、`make -k verify` を実行する。`harness-check` はベースラインに関係
   なく常にグリーンでなければならない。それ以外のゲートは、前のターンで通って
   いたものが新たに落ちた場合だけターンを止める。3回連続で拒否すると諦めて
   ユーザーに伝える（その判定は同一のツリー状態にキャッシュされ、ツリーが変わ
   るまで再判定しない）。
3. **git hooks**: `hooks/pre-commit` はステージ済みの Kotlin/Swift の整形を確認
   する。`hooks/pre-push` は `make check` をフルで実行する。

## 役割ごとの書き込み範囲

役割は hook 入力の `agent_id` / `agent_type` で判定する（`scripts/guard/roles.ts`）。
名前の無いサブエージェントは実装者と同じ扱い。

| 役割 | ハーネス・`PRODUCT.md` | `acceptance/` | それ以外 | コミット |
|---|---|---|---|---|
| メインセッション | 可（ユーザーの承認後） | 可 | 可 | 可 |
| 実装者・その他のサブエージェント | 不可 | 不可 | 可 | 作業ツリーに不可のパスの変更があると拒否 |
| `acceptance-writer` | 不可 | 可 | 不可 | 作業ツリーに不可のパスの変更があると拒否 |
| `reviewer` | 不可 | 不可 | 不可 | 不可 |

`.git` と `.claude/settings.local.json` は全員に対して常に拒否される。
サブエージェントは `git reset --hard` / `clean` / `stash` / `checkout .` も使えない
（メインセッションの未コミットの変更を消さないため）。

## 何が保護されているか

`quality/protected-paths.txt` に列挙: `quality/` `hooks/` `scripts/guard/`
`scripts/hooks/` `scripts/quiet.sh` `Makefile` `mise.toml` `.claude/`
`CLAUDE.md` `.gitignore` `clients/kmp/.gitignore`、Gradle の一部設定ファイル、
`clients/kmp/build-logic` `clients/kmp/.editorconfig`
`clients/kmp/iosApp/Configuration/Config.xcconfig` `PRODUCT.md` `acceptance/`。

ハーネスを変えるときは、メインセッションが変更内容を提示し、ユーザーが会話で
承認してから変更・コミットする。

## 初回セットアップ

```sh
mise install   # mise.toml に固定した node/java を導入（make tools でも可）
make hooks     # git hooks を hooks/ に向ける
```

## 主な make ターゲット

- `make verify` — 高速チェック一式（harness-check,
  guard-ignored, guard-toolchain, guard-suppressions, fmt-check, lint,
  kmp-test）。Stop hook が実行するのと同じ。
- `make check` — verify に加え、Android/iOS のビルド、`swiftlint analyze`、
  フルテストスイート。
  push 前に実行する。
- `make fmt` / `make fmt-check` — Kotlin（ktlintFormat/ktlintCheck）と
  Swift（`xcrun swift-format`）を、その場で直すか（fmt）検査だけするか
  （fmt-check）。
- `make lint` — 静的解析一式。下記「lint ゲート」を参照。
- `make tools` — mise.toml のバージョンをインストール。
- `make hooks` — git hooks を配線する。

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
