# TODO

`PRODUCT.md` §8 のステージを順に。ステージは、その基準が `make status` で pass し
`make check` が green になったら完了。

1. Foundation（完了: stage.txt = 1）
2. Recording money（完了: stage.txt = 2）
3. Reporting and calendar（完了: stage.txt = 3）
4. Budget and savings（完了: stage.txt = 4）
5. Photos and scanning（完了: stage.txt = 5。iOS と共有ロジックのみ。Android の画面（ML Kit の書類スキャナー・文字認識・Gemini Nano、進行中の通知、モジュール導入）は未着手）
6. Receipts that do not add up（完了: stage.txt = 6。iOS と共有ロジックのみ。Android の画面は未着手）
7. Needs-review records（完了: stage.txt = 7。iOS と共有ロジックのみ。Android の画面は未着手）
8. Pace and notifications（次: 未決事項を Claude Design で提示する）
9. Theme
10. Widget
11. Backup（締めの記録 month_closes・month_close_carries、読み取りの scan_jobs・drafts・draft_items を RecordSnapshot に入れる。ステージ4・5で先送りした分）

## ハーネス

- 受け入れテストが遅い（AC-F-203 だけで約3分）。高速化する。
- `make acceptance-ios` は、テストが 0 件しか実行されなくても ok になる（2つの make を同時に走らせると結果バンドルが壊れて起きた）。0 件を失敗として扱うようにする。
- テスト専用の仕組みが製品のソースにある（監査の指摘、重さ低）。どれも Release からは届かない。Debug 専用のソースセット・ターゲットへ移すか検討する。
  - Kotlin: UI テスト用の入口（`sharedLogic/src/iosMain/.../di/UiTestSupport.kt`。要確認の2件の投入を含む）、印を付ける `data/ReviewMarks.kt`（そのため `LocalStore.database` を internal にした）、ジョブの1段送り（`sharedLogic/src/commonMain/.../scan/ScanPacer.kt` の `Stepped`）。
  - Swift: モジュール導入と進み具合の表示の偽物（`iosApp/iosApp/State/UITestScanning.swift` の `UITestModuleInstaller`・`UITestProgressSurface` など。`#if DEBUG` の中）。
- Stop フック: サブエージェントが自分の実行したテストの完了を待つ間は SubagentStop が発火して目印が外れ、作業途中の未追跡ファイルでメインが止められる。メインの Stop フックの make とサブエージェントの make が重なり、Gradle のテスト結果のファイルを取り合って落ちることもある。待機中も目印を残す方法を検討する。
- 受け入れテストの確かめ漏れ（監査の指摘、重さ低）:
  - AC-F-501: `日付` と各品目の `カテゴリ` が編集できること、確定時に弁当が分類なしで保存されることを見ていない（`draft-date` は契約では text field だが実装は Button）。
  - AC-E-501: 表示中の月 `2026年2月` を直接見ていない。
  - AC-F-502: 記録後の明細の中身（差額を足した3件、受け入れた 980 の 唐揚げ弁当・緑茶・差額 150、合計だけの分かれていない 980）を見ていない。画面が通る `ScanEditor.confirmDraft(form, acceptMismatch)` は単体テストだけが確かめている。
  - `XCUIApplication+Scrolling.swift` の説明（シートの中では上方向へドラッグしない）と食い違い、AC-F-502 は下書きのシートを開いたまま `collectRows` を呼ぶ。今は下書きのシートがドラッグで閉じないので通る。
- 不安定な UI テスト: AC-F-501（まれに落ち、再実行では通る）、`TabNavigationUITests.testHomeScrollPositionAndStateAreRetainedAcrossTabSwitch`、`RecordSheetAccessibilityUITests`、AC-F-301 の「Timed out while synthesizing event」（再実行では通る）。シミュレーターの状態が汚れると AC-F-203 が落ちる（erase で回復）。

## 読み取り

- 精度の調整は受け身にする（2026-10-06 のユーザーの決定）。外れたレシートは開発用の版の「読み取った文字を見る」で文字を受け取り、何件かたまったらまとめて素材と規則に足す。本格的な改善は v2 のサーバー側の、写真を読む LLM で検討する。
- 実機で、写真ライブラリのレシートが補正されて読めるか確かめる。書類スキャナーのページが補正されないことも。
- 端末内 LLM の答えが明細の和と合計を合わせないことがある（数量・値引き・外税）。答えが合わないときにルールベース解析の結果と比べるかを決める（自動で切り替えないこと）。

## 画面

- 記録の修正画面（明細を分けた記録）にも、下書きと同じ形（案A: 一覧は読むだけ、品目はシートで直す、スワイプで消す）を入れるか。ユーザーの返事待ち。
- 右下の記録ボタン（＋）が、各タブの一覧の下端（予算タブの分類の行など）に重なる。スクロールすれば見えるが、一覧の下にボタンの分の余白を足す。
- 下書きの破棄（discard）が断られると、理由が出ないまま下書きのシートごと閉じうる（`ScanStore.failureMessage` を下の画面のアラートが拾うため）。確定は直した。
- 全体の分類がアーカイブ済みの下書きで、全体の `カテゴリ` のメニューが「未選択（その他）」と表示される（確定は断られ、選び直せば記録できる）。`その他` 自体がアーカイブされた場合の扱いは未確認。
