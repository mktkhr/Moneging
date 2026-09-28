# アーキテクチャ

Moneging のクライアント（`clients/kmp`）の構成と、状態・ライフサイクルの規則。

## 全体像

```mermaid
flowchart LR
    subgraph iOS["iOS（SwiftUI）"]
        V1[View] --> A1["@Observable アダプタ"]
    end
    subgraph Android["Android（Jetpack Compose）"]
        V2[Composable]
    end
    subgraph shared["sharedLogic（Kotlin）"]
        VM["AppState（アプリ生存期間）\nStateFlow&lt;UiState&gt;"] --> UC[ユースケース]
        UC --> R[リポジトリ]
        R --> DB[(SQLDelight)]
    end
    A1 -- "SKIE（AsyncSequence）" --> VM
    V2 --> VM
```

- アプリ全体の状態（現在の月・家計簿の選択など）は `AppState`（`sharedLogic`、`androidx.lifecycle.ViewModel` ではない素の状態保持クラス）が1つの `StateFlow<AppUiState>` で公開する。UI は操作を `AppState.onIntent` に送り、新しい状態を受け取るだけ（単方向）。
  `AppState` は Koin のシングルトンとしてアプリの生存期間ずっと生き続ける。`ViewModel` はライフサイクルオーナー（`onCleared()` を呼ぶ側）があって初めて意味を持つ型で、
  アプリ生存期間のシングルトンにオーナーは存在しないため、`AppState` は明示的な `CoroutineScope` を自分で持つ素のクラスにしている。
- 画面ごとの状態（今後実装される個々の画面）は、これとは別のライフサイクル: 各画面（`NavigationStack` の遷移先）がオーナーとなる、通常の `androidx.lifecycle.ViewModel` を使う。
- iOS は SKIE で Flow を `AsyncSequence` として受け取る。
- データは端末内の SQLDelight。更新はリポジトリが Flow で流す。
- 依存関係は Koin で組み立てる。

## 対象

- iOS 26 以上（Liquid Glass のタブバー、`tabViewBottomAccessory`、Foundation Models）
- Android 14（API 34）以上

## 状態とライフサイクルの規則

1. 依存関係のコンテナはアプリ起動時に1回だけ作る。
2. タブは標準の `TabView`（`Tab` API）。各タブが自分の `NavigationStack` を持ち、
   遷移の状態はアプリ全体の状態として保持する。タブを切り替えても画面を作り直さない。
3. 状態を持つオブジェクトは画面ごとに1回だけ生成して `@State` に置く。`body` の中で
   生成しない。タブの最初の画面の分はアプリの生存期間中ずっと保持する。
4. データは DB の変更を監視して流す。画面が表示されるたびに取り直さない。
5. UI/UX に関わる変更は、シミュレーターでアプリを実際に操作して確認してから完了とする。
