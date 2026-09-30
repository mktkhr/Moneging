# TODO

`PRODUCT.md` §8 のステージを順に。ステージは、その基準が `make status` で pass し
`make check` が green になったら完了。

1. Foundation（完了: stage.txt = 1）
2. Recording money（完了: stage.txt = 2）
3. Reporting and calendar（完了: stage.txt = 3）
4. Budget and savings（完了: stage.txt = 4）
5. Photos and scanning（完了: stage.txt = 5。iOS と共有ロジックのみ。Android の画面（ML Kit の書類スキャナー・文字認識・Gemini Nano、進行中の通知、モジュール導入）は未着手）
6. Receipts that do not add up（次: 未決事項を Claude Design で提示する）
7. Needs-review records
8. Pace and notifications
9. Theme
10. Widget
11. Backup（締めの記録 month_closes・month_close_carries、読み取りの scan_jobs・drafts・draft_items を RecordSnapshot に入れる。ステージ4・5で先送りした分）

## ハーネス

- 受け入れテストが遅い（AC-F-203 だけで約3分）。高速化する。
- `make acceptance-ios` は、テストが 0 件しか実行されなくても ok になる（2つの make を同時に走らせると結果バンドルが壊れて起きた）。0 件を失敗として扱うようにする。
- テスト専用の仕組みが製品のソースにある（監査の指摘、重さ低）。UI テスト用の入口（`sharedLogic/src/iosMain/.../di/UiTestSupport.kt`）と、ジョブの1段送り（`sharedLogic/src/commonMain/.../scan/ScanPacer.kt` の `Stepped`）。どちらも Release からは届かない。Debug 専用のソースセットへ移すか検討する。
- Stop フック: サブエージェントが自分の実行したテストの完了を待つ間は SubagentStop が発火して目印が外れ、作業途中の未追跡ファイルでメインが止められる（ステージ5で発生）。待機中も目印を残す方法を検討する。
- 受け入れテストの確かめ漏れ（監査の指摘、重さ低）: AC-F-501 で `日付` と各品目の `カテゴリ` が編集できること、確定時に弁当が分類なしで保存されることを見ていない（`draft-date` は契約では text field だが実装は Button）。AC-E-501 で表示中の月 `2026年2月` を直接見ていない。
- 不安定な UI テスト: `TabNavigationUITests.testHomeScrollPositionAndStateAreRetainedAcrossTabSwitch`、`RecordSheetAccessibilityUITests`（再実行では通る）。シミュレーターの状態が汚れると AC-F-203 が落ちる（erase で回復）。

## 画面

- 右下の記録ボタン（＋）が、各タブの一覧の下端（予算タブの分類の行など）に重なる。スクロールすれば見えるが、一覧の下にボタンの分の余白を足す。
