# TODO

`PRODUCT.md` §8 のステージを順に。ステージは、その基準が `make status` で pass し
`make check` が green になったら完了。

1. Foundation（完了: stage.txt = 1）
2. Recording money（完了: stage.txt = 2）
3. Reporting and calendar（実装済み。AC-B-301〜303・AC-F-301・302 のテストは pass。受け入れテスト `TestTwelveMonthTrend.kt` の detekt 違反2件（DocumentationOverPrivateProperty、FunctionNameMaxLength）で `make acceptance-shared` が赤: ハーネス側の修正待ち。その後 test-auditor で監査し stage.txt を 3 に）
4. Budget and savings
5. Photos and scanning
6. Receipts that do not add up
7. Needs-review records
8. Pace and notifications
9. Theme
10. Widget
11. Backup

## ハーネス

- 受け入れテストが遅い（AC-F-203 だけで約3分）。高速化する。
- `make acceptance-ios` は、テストが 0 件しか実行されなくても ok になる（2つの make を同時に走らせると結果バンドルが壊れて起きた）。0 件を失敗として扱うようにする。
