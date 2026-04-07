# イルカソレ (BuyOrNot) - Claude向け開発ルール

## ✅ 必須: コード変更後は必ずビルドを実行すること

Swift ファイルを変更した場合は、必ず以下のコマンドでビルドを実行し、
error・warning がないことを確認してから完了を報告すること。

```bash
xcodebuild build \
  -project BuyOrNot.xcodeproj \
  -scheme BuyOrNot \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  2>&1 | grep -E "error:|warning:|BUILD"
```

error が出た場合はその場で修正し、BUILD SUCCEEDED になるまでループすること。
warning も可能な限り解消すること。

---

## ⚠️ 既知の型衝突: StoreKit.Product vs アプリの Product モデル

アプリ独自の `Product` モデル (`Models/Product.swift`) と
StoreKit の `Product` 型が同名で衝突する。

**注意事項:**
- `StoreKit.Product` のプロダクトIDは **`.id`**（`.productID` ではない）
- `StoreKit.Transaction` のプロダクトIDは **`.productID`**（正しい）
- `StoreKit.Product` を使う箇所では必ず `StoreKit.Product` と明示修飾する

---

## 🔍 StoreKit デバッグ: 原因解明が遅れた反省と教訓

### 今回起きたこと
StoreKit Local Testing で `Product.products(for:)` が空配列を返し続け、
解決まで長時間かかった。根本原因は **iOS 26 で古い形式の .storekit ファイルが無視されていたこと**。

### なぜ時間がかかったか（失敗の連鎖）

#### ❌ 失敗1: 実行環境の確認を怠った
- 「実機では .storekit が動かない」と誤診し、シミュレーターであることを確認せずに回答した
- **教訓: 最初に必ずログで `isSimulator` と `SIMULATOR_RUNTIME_VERSION` を確認する**

#### ❌ 失敗2: Storefront を最初に確認していなかった
- `Storefront.current` の `countryCode` を見れば、Local Testing が有効かどうか一発でわかる
- `.storekit` に `JPN` を設定しているのに `USA` が返る = Local Testing が無効 = ファイルが読まれていない
- この診断を後回しにしたため、パス修正・シミュレーターリセット等の無駄な試行を繰り返した
- **教訓: StoreKit 問題の第一確認事項は `Storefront.countryCode`**

#### ❌ 失敗3: xcscheme の直接編集を信頼しすぎた
- Xcode は xcscheme ファイルの手動編集を反映しないことがある
- Edit Scheme UI での設定が唯一確実な方法だった
- **教訓: Xcode の設定変更は必ず UI から行い、ファイル直接編集は補助手段に留める**

#### ❌ 失敗4: ビルドせずにコードを提出した
- `StoreKit.Product.productID` という存在しないプロパティ（正しくは `.id`）を書いてしまい、
  ユーザーがビルドして初めてエラーを発見した
- **教訓: Swift ファイル変更後は必ず xcodebuild でビルド確認してから完了報告する（CLAUDE.md 参照）**

#### ❌ 失敗5: iOS バージョンを考慮しなかった
- `SIMULATOR_RUNTIME_VERSION: 26.4` というログを見ていたのに iOS 26 固有の問題を疑わなかった
- 古い Xcode で作った .storekit ファイルは iOS 26 では動作しないケースがある
- **教訓: ログの OS バージョンを確認し、互換性の問題を早期に疑う**

### StoreKit 問題の正しい診断フロー（次回から使う）

```
1. Storefront.countryCode を確認
   → .storekit に設定した国コードと一致する？
     YES → Local Testing は有効。別の問題。
     NO  → Local Testing が無効。以下を確認:
           a) Edit Scheme > Run > Options > StoreKit Configuration に .storekit が設定されているか
           b) "Sync this file with an app in App Store Connect" がオフか
           c) .storekit ファイルを Xcode で新規作成し直す（旧 OS で作ったファイルは使えないことがある）

2. プロダクトが空配列の場合
   → Product ID が .storekit ファイルと完全一致しているか確認（バイト列まで）
   → subscriptionGroups 内に正しく定義されているか確認

3. エラーが throw される場合
   → StoreKitError の種類を確認（networkError / systemError / notAvailableInStorefront 等）
```

---

## プロジェクト概要

- **アプリ名**: イルカソレ
- **概要**: 衝動買いを止めるイルカキャラクターのiOSアプリ
- **技術スタック**: SwiftUI, SwiftData, StoreKit2, WidgetKit
- **プロダクトID**: `com.irukasore.app.premium.monthly`
- **App Group**: `group.com.irukasore.app`
