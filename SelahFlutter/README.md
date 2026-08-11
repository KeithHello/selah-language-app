# Selah Flutter 客户端

Selah 是「用中文想、用英文說」的陪伴式語言學習 App。本目錄是基於 SwiftUI 版本
平行開發的 Flutter 客戶端，遵守以下邊界：

- 現有 SwiftUI 工程（`../Selah`、`../SelahTests`、`../SelahWidget`）保持不變。
- Supabase schema、RLS、Edge Functions、Seed 與 Storage 一律不改動，只透過
  既有 7 個 Edge Functions 通訊。
- 本階段使用 `FixtureSelahApiClient` 進行離線開發與測試，不產生真實 TTS 費用。

## 目錄結構

```text
lib/
├── app/          # 路由、容器（Riverpod provider）、應用入口
├── design/       # 品牌 token：顏色、間距、圓角、陰影、字體、動效、主題
│   └── widgets/  # 卡片、按鈕、輸入框等品牌元件
├── domain/       # 實體、Repository 介面、Use Case、領域枚舉
├── data/         # SQLite（SwiftData V3 對應）、DTO、Fixture Gateway
└── features/     # onboarding、today、settings、companion（精靈）
```

## 設計系統

沿用 SwiftUI 版 Selah 品牌 token（`Quiet Growth`，暖米色基底）：

- 背景 `#FBF8F4`，卡片 `#FFFFFF`，文字 `#1A1614`
- 主色珊瑚 `#E06B54`，輔色薰衣草 `#8B7FC7`／鼠尾草 `#5A9E82`／琥珀 `#E5A244`
- 字體 Plus Jakarta Sans（30/22/18/15/14/12/11 階）
- 4pt 間距網格、6–22pt 圓角、柔和低透明度陰影
- 動效 200/350/500ms，Reduce Motion 全支持

詳細決策記錄於 `../design-system/selah/MASTER.md`。

## 運行與驗證

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome      # Web 視覺預覽
flutter run -d <android>   # Android 模擬器
flutter build apk --debug  # Android APK
```

Windows 本機無法建 iOS；iOS 建置與驗證由 macOS CI／真機完成。

## 精靈素材

`assets/sprites/` 為 SwiftUI 版 `Assets.xcassets` 的 3x PNG 副本（9 身體姿態 +
2 眼神覆蓋層），用於 Flutter 分層渲染；原始素材不改動。
