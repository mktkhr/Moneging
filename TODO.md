# TODO

`PRODUCT.md` §8 のステージを順に。ステージは、その基準が `make status` で pass し
`make check` が green になったら完了。

1. Foundation（完了: stage.txt = 1）
2. Recording money（実装済み・受け入れ全通過。stage.txt はまだ 1。閉じる前に残り: 定期の修正・終了・削除の画面、金額入力中のカンマ区切り → その後 stage.txt を 2 に上げる変更一式）
3. Reporting and calendar
4. Budget and savings
5. Photos and scanning
6. Receipts that do not add up
7. Needs-review records
8. Pace and notifications
9. Theme
10. Widget
11. Backup

## ハーネス

- Stop フック（scripts/guard/stop-gate.sh）がサブエージェント実行中の未コミットファイルでメインを止める。「3回であきらめる」が作業ツリーのキー単位なので、ツリーが変わり続けると再発する。案: SubagentStart/SubagentStop フックで目印を置き、実行中は通す（古い目印は無視）＋ stop_hook_active が真なら続けて止めない。ユーザー未承認。
- 受け入れテストが遅い（AC-F-203 だけで約3分）。ステージ2を閉じた後に高速化。
