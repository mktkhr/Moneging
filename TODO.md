# TODO

`PRODUCT.md` §8 のステージを順に。ステージは、その基準が `make status` で pass し
`make check` が green になったら完了。

1. Foundation（完了: stage.txt = 1）
2. Recording money（完了: stage.txt = 2）
3. Reporting and calendar（完了: stage.txt = 3）
4. Budget and savings（完了: stage.txt = 4）
5. Photos and scanning（iOS と共有ロジックは実装済み。残り: 受け入れテスト側の Android Lint・detekt 違反の修正（ハーネス変更）、stage.txt を 5 に上げる、test-auditor の監査。Android の画面（ML Kit の書類スキャナー・文字認識・Gemini Nano、進行中の通知、モジュール導入）は未着手）
6. Receipts that do not add up
7. Needs-review records
8. Pace and notifications
9. Theme
10. Widget
11. Backup（締めの記録 month_closes・month_close_carries、読み取りの scan_jobs・drafts・draft_items を RecordSnapshot に入れる。ステージ4・5で先送りした分）

## ハーネス

- 受け入れテストが遅い（AC-F-203 だけで約3分）。高速化する。
- `make acceptance-ios` は、テストが 0 件しか実行されなくても ok になる（2つの make を同時に走らせると結果バンドルが壊れて起きた）。0 件を失敗として扱うようにする。
- UI テスト用の入口（`sharedLogic/src/iosMain/.../di/UiTestSupport.kt`）は Release から除いてあるが、置き場所は製品のソースのまま（監査の指摘、重さ低）。Debug 専用のソースセットへ移すか検討する。

## ハーネス（ステージ5）

- Widget Extension（`clients/kmp/iosApp/MonegingWidgets`）が `make lint` / `fmt-check` の対象（IOS_SRC = iosApp/iosApp）に入っていない。Makefile の対象に足す。

## 画面

- 下書きの日付の DatePicker は端末の言語で表示される（入力シートと同じ）。

- 右下の記録ボタン（＋）が、各タブの一覧の下端（予算タブの分類の行など）に重なる。スクロールすれば見えるが、一覧の下にボタンの分の余白を足す。
