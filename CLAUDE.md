# CLAUDE.md

- Kotlin Multiplatform アプリ
- `.gitignore` は deny by default。追跡するファイルは `!` で許可する
- 完了 = `make verify` が green
- ハーネス（`quality/protected-paths.txt` のパス）は hook で保護される。回避しない。変更はリポジトリ外の変更スクリプト（apply.sh）を作って説明し、ユーザーの実行許可を待つ（docs/handbook/harness.md）
- 実装は `implementer`、受け入れテストは `acceptance-writer`、レビューは `reviewer` サブエージェントに委譲する

## コミット

- Conventional Commits 準拠
- 接頭辞: `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore`
- メッセージは日本語（接頭辞は英語）
