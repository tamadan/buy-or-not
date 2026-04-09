# App Store 審査で詰まったこと・解決策まとめ

イルカソレ v1.1 の審査提出で実際に詰まった問題と解決策の記録。

---

## 1. Upload Symbols Failed（警告）

### 症状
Xcode Organizer でDistribute App後、以下の警告が出た：
```
Upload Symbols Failed
The archive did not include a dSYM for the GoogleMobileAds.framework
The archive did not include a dSYM for the UserMessagingPlatform.framework
```

### 原因
GoogleMobileAds（AdMob）がdSYMファイルを同梱していないため。サードパーティのフレームワーク起因。

### 解決策
**無視してOK。** アップロード自体は成功している。App Storeの配信にも影響なし。

---

## 2. App Tracking Transparency（ATT）未実装による却下

### 症状
```
Guideline 5.1.2(i) - Legal - Privacy - Data Use and Sharing
The app privacy information indicates the app collects data to track the user,
but the app does not use App Tracking Transparency to request permission.
```

### 原因
- プライバシーラベルで「製品の操作」「広告データ」をトラッキング目的として申告していた
- しかしATT（AppTrackingTransparency）フレームワークを実装していなかった

### 解決策
1. `Info.plist` に `NSUserTrackingUsageDescription` を追加
2. アプリ起動時にATTダイアログを表示（`ATTrackingManager.requestTrackingAuthorization`）
3. ビュー表示後0.5秒の遅延を挟むとダイアログが確実に表示される

```swift
// BuyOrNotApp.swift
.task {
    try? await Task.sleep(for: .milliseconds(500))
    await withCheckedContinuation { continuation in
        ATTrackingManager.requestTrackingAuthorization { _ in
            continuation.resume()
        }
    }
    AdManager.shared.initialize() // ATT取得後に広告SDKを初期化
}
```

### 教訓
- AdMobを導入した時点でATT実装は必須
- プライバシーラベルでトラッキングを申告するならATTダイアログも必ずセットで実装する
- 広告SDKの初期化はATT許可取得「後」に行う

---

## 3. IAP（サブスクリプション）が審査に提出されていない

### 症状
```
Guideline 2.1(b) - Performance - App Completeness
We are unable to complete the review because one or more In-App Purchase
products have not been submitted for review.
```

### 原因（複数）

#### 原因1: 有料アプリ契約（Paid Apps Agreement）が未承認
- App Store Connectの「ビジネス」→「契約」で有料アプリ契約が「新規」のままだった
- 契約が有効でないと、IAPの価格情報が審査端末で読み込めない
- 契約が「新規」の状態では、バージョンページの「アプリ内課金とサブスクリプション」セクションにIAPを追加するUIが表示されない

#### 原因2: W-8BEN（米国税務フォーム）が未提出
- 有料アプリ契約に署名するには「法人情報」の入力が必要
- 個人開発者でも同じフォームで対応可能
- W-8BENとU.S. Certificate of Foreign Status of Beneficial Ownerの両方が必要

#### 原因3: サブスクリプショングループのローカリゼーション未設定
- 個別のサブスクリプション商品にはローカリゼーションを設定していたが、**グループ自体**のローカリゼーションが未設定
- グループのローカリゼーションがないとステータスが「メタデータが不足」になる

### 解決策

1. **有料アプリ契約の締結**
   - App Store Connect → ビジネス → 契約
   - 「法人を編集」から個人情報を入力
   - W-8BENフォームを記入・送信（Titleは「Owner」）
   - Part II（Tax Treaty）: Article 14、Rate 0%、Income from the sale of applications

2. **サブスクリプショングループにローカリゼーションを追加**
   - サブスクリプション → グループ名をクリック → ローカリゼーション → 作成
   - 日本語・グループ表示名を入力

3. **有料アプリ契約が有効になるとバージョンページのIAP追加UIが表示される**

### 教訓
- **IAPを含むアプリを初めて申請する前に有料アプリ契約を必ず締結する**
- W-8BEN提出から有効化まで最長24時間かかる場合があるが、即日有効になることもある
- サブスクリプションは「商品」と「グループ」の両方にローカリゼーションが必要

---

## 4. サブスクリプション購入画面の規約リンク不足

### 症状
```
Guideline 3.1.2(c) - Business - Payments - Subscriptions
1) The following information needs to be included within the app:
   - A functional link to the Terms of Use (EULA)
   - A functional link to the privacy policy
2) The following information needs to be included in the App Store metadata:
   - A functional link to the Terms of Use (EULA)
```

### 解決策
1. **PaywallView**にリンクを追加：
```swift
HStack(spacing: 16) {
    Link("プライバシーポリシー", destination: URL(string: "https://your-privacy-policy-url/")!)
    Text("・")
    Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
}
.font(.caption2)
```

2. **App Storeの説明文**末尾に追記：
```
利用規約: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

※ Apple標準EULAを使う場合のURL: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

### 教訓
- サブスクリプションを含むアプリは購入画面にプライバシーポリシーとEULAのリンクが必須
- App Storeの説明文にもEULAリンクが必要（アプリ内だけでは不十分）

---

## 5. プライバシーラベルの設定

### AdMobを使う場合にチェックすべき項目

| データ種別 | 用途 | トラッキング |
|---|---|---|
| 製品の操作 | サードパーティ広告・製品のパーソナライズ | はい |
| 広告データ | サードパーティ広告 | はい |
| クラッシュデータ | アプリの機能 | いいえ |
| パフォーマンスデータ | アプリの機能 | いいえ |

### 教訓
- トラッキング「はい」を申告した項目があれば、ATT実装が必須になる
- 迷ったら「トラッキング」をいいえにして、ATT実装を避ける選択肢もある（ただしAdMobの広告効果は下がる）

---

## 6. App Review へのメモ記載

### 有効だった記載内容（英語推奨）
```
The App Tracking Transparency permission dialog appears approximately 0.5 seconds
after app launch. It will be shown on a fresh install or after resetting tracking
permissions in Settings.

Subscription testing is available via Sandbox account.
```

### 教訓
- App Reviewへの返信・メモは英語で書く方が確実に伝わる
- ATTやサブスクリプションなど審査員が確認しにくい機能は、どこで・どうやって確認できるかを明記する

---

## Claudeメモリ記載用プロンプト

以下を `MEMORY.md` に追記することを推奨：

```markdown
- [App Store審査前チェックリスト](app-store-review-checklist.md) — IAPを含むアプリ提出前に有料アプリ契約・W-8BEN・ATT実装・規約リンクを必ず確認する
- AdMobを使うアプリはATT実装必須 — プライバシーラベルでトラッキングを申告した場合、NSUserTrackingUsageDescriptionの追加とATTrackingManager.requestTrackingAuthorizationの呼び出しが必要。広告SDKの初期化はATT取得後に行う。
- サブスクリプションアプリの審査前確認事項 — (1)有料アプリ契約が有効か (2)W-8BEN提出済みか (3)グループ・商品両方のローカリゼーション設定済みか (4)購入画面にプライバシーポリシー・EULAリンクがあるか (5)App Store説明文にEULAリンクがあるか
```
