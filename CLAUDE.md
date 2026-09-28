# CLAUDE.md

- Kotlin Multiplatform アプリ
- `.gitignore` は deny by default。追跡するファイルは `!` で許可する
- 完了 = `make verify` が green
- ハーネス（`quality/protected-paths.txt` のパス）は hook で保護される。回避しない
- 実装は `implementer`、レビューは `reviewer` サブエージェントに委譲する

## コミット

- Conventional Commits 準拠
- 接頭辞: `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore`
- メッセージは日本語（接頭辞は英語）
