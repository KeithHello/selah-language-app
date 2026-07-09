# Selah iOS Design Spec — Design Tokens + Component Library

> 本文件定義 Selah iOS App 的視覺系統，作為 SwiftUI 開發的唯一設計參照。

---

## 一、Design Tokens

### 1.1 Colors

```swift
// Brand Colors
extension Color {
    static let bgPrimary    = Color(hex: "#FBF8F4")   // 暖白背景
    static let bgSecondary  = Color(hex: "#F8F5F0")   // 卡片替代背景
    static let cardPrimary  = Color(hex: "#FFFFFF")   // 白色卡片
    static let textPrimary  = Color(hex: "#1A1614")   // 主文字
    static let textSecondary = Color(hex: "#706B65")  // 次要文字
    static let textTertiary = Color(hex: "#A9A49E")   // 佔位符/標籤
    static let border       = Color(hex: "#EBE7E1")   // 邊框
    static let borderLight  = Color(hex: "#F3F0EC")   // 淺邊框
    
    // Accent Colors
    static let coral        = Color(hex: "#E06B54")   // 主強調（CTA、今日一句）
    static let coralSoft    = Color(hex: "#FEF0ED")   // 珊瑚淺色
    static let sage         = Color(hex: "#5A9E82")   // 成功/掌握
    static let sageSoft     = Color(hex: "#ECF7F1")   // 鼠尾草淺色
    static let amber        = Color(hex: "#E5A244")   // 學習中/警告
    static let amberSoft    = Color(hex: "#FDF5E6")   // 琥珀淺色
    static let lavender     = Color(hex: "#8B7FC7")   // 聆聽/音樂
    static let lavenderSoft = Color(hex: "#F0EEF8")   // 薰衣草淺色
    static let sky          = Color(hex: "#5B9FD4")   // 資訊
    static let skySoft      = Color(hex: "#EAF3FB")   // 天空淺色
}
```

### 1.2 Typography

```swift
// Font Scale (Plus Jakarta Sans)
extension Font {
    // Display
    static let displayLarge  = Font.custom("PlusJakartaSans-ExtraBold", size: 30)  // 標題 h1
    static let displayMedium = Font.custom("PlusJakartaSans-Bold", size: 22)       // 區段標題
    
    // Headline
    static let headlineLarge = Font.custom("PlusJakartaSans-Bold", size: 18)       // 卡片標題
    static let headlineMedium = Font.custom("PlusJakartaSans-SemiBold", size: 15)  // 行標題
    static let headlineSmall = Font.custom("PlusJakartaSans-SemiBold", size: 13)   // 子標題
    
    // Body
    static let bodyLarge     = Font.custom("PlusJakartaSans-Regular", size: 14)    // 正文
    static let bodyMedium    = Font.custom("PlusJakartaSans-Regular", size: 12)    // 輔助文字
    static let bodySmall     = Font.custom("PlusJakartaSans-Regular", size: 11)    // 小字
    
    // Label
    static let labelLarge    = Font.custom("PlusJakartaSans-SemiBold", size: 12)   // 按鈕/標籤
    static let labelMedium   = Font.custom("PlusJakartaSans-SemiBold", size: 10)   // 小標籤
    static let labelSmall    = Font.custom("PlusJakartaSans-SemiBold", size: 9)    // 極小標籤
    
    // Mono (for numbers/codes)
    static let monoMedium    = Font.custom("JetBrainsMono-Medium", size: 11)       // 等寬數字
}
```

### 1.3 Spacing

```swift
// Spacing Scale (4pt base)
enum Spacing {
    static let xs: CGFloat  = 4     // 圖標與文字間距
    static let sm: CGFloat  = 8     // 緊密元素間距
    static let md: CGFloat  = 12    // 卡片內部間距
    static let lg: CGFloat  = 16    // 卡片之間/區塊間距
    static let xl: CGFloat  = 20    // 區段間距
    static let xxl: CGFloat = 24    // 大區段間距
    static let page: CGFloat = 20   // 頁面左右 padding
}
```

### 1.4 Corner Radius

```swift
enum CornerRadius {
    static let xs: CGFloat  = 6     // 小標籤
    static let sm: CGFloat  = 10    // 按鈕/chip
    static let md: CGFloat  = 12    // 小卡片/input
    static let lg: CGFloat  = 16    // 標準卡片
    static let xl: CGFloat  = 22    // 大卡片/quiz card
    static let pill: CGFloat = 999  // pill 形狀
}
```

### 1.5 Shadows

```swift
enum Shadow {
    // Small (卡片預設)
    static let sm = (color: Color.black.opacity(0.04), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    // Medium (hover/active)
    static let md = (color: Color.black.opacity(0.06), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    // Large (modal/floating)
    static let lg = (color: Color.black.opacity(0.08), radius: CGFloat(20), x: CGFloat(0), y: CGFloat(10))
}
```

---

## 二、Component Library

### 2.1 iOSRow（列表行）

```
結構：[icon 40x40 rounded 12] [title + subtitle flex] [arrow ›]
背景：cardPrimary
邊框：1px borderLight
圓角：lg (16)
Padding：16
Touch target：≥44pt 高度
Hover：shadowMd
Active：scale(0.98)
```

**States：**
- Default：正常顯示
- Disabled（如夜間預覽未到時間）：opacity(0.5)
- Highlighted（如今日一句）：1.5px dashed coral border + coralSoft bg

### 2.2 Badge（標籤）

```
結構：pill shape, labelMedium font
Padding：4px 10px
```

**Variants：**
- `badge-coral`：coralSoft bg + coral text（起步）
- `badge-sage`：sageSoft bg + sage text（已掌握）
- `badge-amber`：amberSoft bg + amber text（學習中）
- `badge-lavender`：lavenderSoft bg + lavender text（聆聽相關）

### 2.3 SmartRecCard（智能推薦卡）

```
結構：[icon 44x44 rounded 14] [title + subtitle flex] [arrow ›]
背景：cardPrimary
邊框：1px borderLight
圓角：lg
Padding：16
可點擊：推送到對應頁面
```

### 2.4 CatChip（分類篩選 chip）

```
結構：emoji + label, pill shape
背景：cardPrimary
邊框：1.5px borderLight
圓角：pill
Padding：8px 14px
Font：labelLarge
```

**States：**
- Default：borderLight border
- Active：coral border + coralSoft bg

### 2.5 QuizCard（翻卡）

```
結構：
  正面：badge(分類) + quiz-zh(中文大字)
  背面：reveal-area(dashed border → 揭示後 solid sage border)
  底部：三個評估按鈕（good/mid/fail）

背景：cardPrimary
圓角：xl (22)
Padding：20
Shadow：md
```

**Reveal Button States：**
- Hidden：dashed border + 「點擊揭示答案」
- Revealed：solid sage border + sageSoft bg + 英文文字淡入

**Assessment Buttons：**
- Good：sage bg + white text
- Mid：amberSoft bg + amber text + amber border
- Fail：bgSecondary bg + textSecondary text + border

### 2.6 DeconstructBlock（句子拆解）

```
結構：
  英文句子（帶可點擊詞組 chips）
  解釋列表（詞組 + 中文 + 用法說明）
  「理解了，繼續跟讀 →」按鈕

背景：sageSoft
圓角：lg
Padding：16
```

**Word Chips：**
- Phrase type：amberSoft bg + amber text + amber border
- Pattern type：lavenderSoft bg + lavender text + lavender border
- Tap：彈出 vocab popup

### 2.7 VocabPopup（詞彙浮層）

```
結構：
  word (headlineLarge, lavender)
  meaning (bodyLarge)
  [加入生詞本 button] [知道了 button]

背景：cardPrimary
圓角：md
Shadow：lg
Max width：260pt
動畫：fadeInUp 0.3s
定位：被點擊詞組下方
```

### 2.8 RecVocabSelectable（可勾選詞組 chip）

```
結構：[check icon 14x14 circle] word + meaning
背景：cardPrimary
邊框：1.5px border
圓角：pill
Padding：5px 12px
```

**States：**
- Unselected：border color, textSecondary
- Selected：sage border + sageSoft bg + sage text + check filled

### 2.9 CoachHint（學習教練提示）

```
結構：[💡 icon] [提示文字 + 「知道了」dismiss link]
背景：sageSoft
邊框：1px sage 20% opacity
圓角：md
Padding：10px 14px
Font：bodySmall
動畫：fadeInUp 0.5s
```

### 2.10 Toast（通知）

```
結構：文字居中, pill-like
定位：頁面頂部（safe area 下方 60pt）
圓角：md
Padding：12px 16px
動畫：slideIn from top 0.4s → 停留 2.5s → slideOut 0.4s
```

**Variants：**
- Success：sage bg + white text
- Info：lavender bg + white text

### 2.11 ProgressBar（進度條）

```
結構：background track + fill
高度：5px
圓角：3px
背景：borderLight
填充：sage（預設）
動畫：width transition 0.5s
```

### 2.12 StageBar（步驟指示器）

```
結構：4 個 tab（各 flex:1, height 4px）+ 4 個 label
Tab 圓角：2px
Tab 間距：4px
Label font：labelSmall
```

**States：**
- Inactive：borderLight tab + textTertiary label
- Active：lavender tab + lavender label
- Locked：borderLight tab + textTertiary label + 🔒 icon

### 2.13 PetView（精靈顯示）

```
結構：
  pet-stage (100x100, centered)
    └── pet-body (60pt, amber gradient circle)
        ├── eyes (2x 6pt black dots)
        ├── smile (arc, 3px stroke)
        └── blush (2x coral 15% opacity circles)
  name (headlineMedium)
  mood (bodyMedium, textSecondary)
  today-story (card, centered, max-width 280pt)
```

**Decoration Stages：**
- none：純種子
- sprout：+小葉芽（Day 4）
- leaf：+大葉子（Day 7）
- bud：+花苞（Day 10）
- bloom：+花朵（Day 14）

---

## 三、Screen Specifications

### 3.1 Onboarding（4 步）

| Step | 畫面 | 組件 |
|------|------|------|
| 1 | 語言選擇 | 2 個 LangButton + 精靈蛋動畫 |
| 2 | 發音偏好 | 2 個 LangButton（美/英）|
| 3 | 聲線性別 | 2 個 GenderButton + 試聽按鈕 |
| 4 | 寵物命名 | NameInput + 精靈蛋（縮小）|
| 5 | 種子句選擇 | SeedList（6 項，選 3）+ 孵化按鈕 |
| 6 | 孵化動畫 | 全屏 overlay → 轉場到今日頁面 |

### 3.2 Today（今日 Tab）

```
Layout（由上到下）：
  PetView（精靈 + 名字 + 心情 + 今日小故事）
  GreetingSection（問候語 + Day N + 子標題）
  SmartRecCard（智能推薦，根據時段）
  TaskRows：
    - 聆聽（iOSRow）→ 可能被智能推薦隱藏
    - 練習（iOSRow）→ 可能被智能推薦隱藏
    - 夜間預覽（iOSRow, 21:00+ 可用）
  TodayRecording（iOSRow, dashed coral border）→ Push 錄音頁

TabBar（底部固定，2 tabs）：
  🏠 今日（active）  📝 筆記
```

### 3.3 Listen（聆聽 Push 頁面）

```
Layout：
  PushNav（← 返回 + 「🎧 聆聽」標題）
  CoachHint（首次顯示）
  PlaylistCounter（◀ 第 1/N 句 ▶）
  StageBar（①②③④ + 進度條）
  SentenceArea（中英文 + blind hint，初始隱藏）
  
  Stage1-Listen：
    ListenStage icon + Play controls + Speed toggle
  Stage2-Predict（locked until 3 plays）：
    CoachHint + Predict button + Predict result
  Stage3-Deconstruct（locked until predict）：
    CoachHint + DeconstructBlock + Continue button
  Stage4-Shadow（locked until deconstruct）：
    CoachHint + ShadowCard (EN text + mic + native play + complete btn)
```

### 3.4 Quiz（練習 Push 頁面）

```
Layout：
  PushNav（← 返回 + 「✏️ 練習」標題）
  CoachHint（首次顯示）
  ProgressBar + count
  QuizCard（正面中文 + 揭示區域）
  AssessmentButtons（good/mid/fail，揭示後解鎖）

Completion State：
  🎉 慶祝畫面 + 引導錄音
```

### 3.5 Preview（夜間預覽 Push 頁面）

```
Layout：
  PushNav（← 返回 + 「🌙 夜間預覽」）
  說明文字 + vocab tip
  舊句複習（2 句 PreviewCard）
  新句學習（3 句 PreviewCard）
  「預習好了」按鈕
```

### 3.6 Record（錄音 Push 頁面）

```
Layout：
  PushNav（← 返回 + 「🎙️ 今日一句」）
  標題 + 副標題
  CoachHint（首次顯示）
  TopicChips（6 個分類 chip）
  RecStarters（選話題後顯示 4 個 starter）
  RecMic（大圓形麥克風按鈕）
  RecWave（錄音中波形動畫）
  RecTextarea（輸入/修正中文）
  RecResult（AI 翻譯結果 + 可選詞彙）
  SubmitButton（存入筆記）
```

### 3.7 Notes（筆記 Tab）

```
Layout：
  SectionTitle（📝 我的筆記 + 統計）
  CatScroll（6 個分類 chip，水平滾動）
  SentenceList（CorpusCard 列表）
  VocabSection：
    標題 + 說明文字
    VocabItem 列表
  PetMemories（小豆的回憶時間軸）

TabBar（底部固定）：
  🏠 今日  📝 筆記（active）
```

### 3.8 Settings（設定頁面，從筆記頁入口）

```
Layout：
  PushNav（← 返回 + 「⚙️ 設定」）
  VoiceSection：
    當前聲線 + 切換列表（4 選項 + 試聽）
  NotificationSection：
    通知開關 + 時間選擇
  AccountSection：
    帳號資訊 + 登出
```

---

## 四、Animation Tokens

### 4.1 Transition Durations

| 類型 | 時長 | 用途 |
|------|------|------|
| quick | 0.2s | 按鈕狀態、chip 選中 |
| standard | 0.35s | 卡片 hover、頁面元素 |
| slow | 0.5s | 頁面轉場、Coach hint |
| push | 0.4s | Push navigation slide |

### 4.2 Easing Curves

| 名稱 | 值 | 用途 |
|------|---|------|
| easeOut | cubic-bezier(0.32, 0.72, 0, 1) | 進入動畫（元素出現） |
| easeIn | cubic-bezier(0.42, 0, 1, 1) | 離開動畫 |
| spring | iOS default spring | Push 轉場、彈跳 |
| bounce | spring(damping: 0.6) | 精靈跳躍、慶祝 |

### 4.3 Haptic Feedback

| 操作 | 反饋類型 |
|------|---------|
| 完成聆聽 | UIImpactFeedbackGenerator(.medium) |
| Quiz 翻卡 | UIImpactFeedbackGenerator(.light) |
| Quiz「記得很清楚」 | UINotificationFeedbackGenerator(.success) |
| Quiz「完全不會」 | UINotificationFeedbackGenerator(.warning) |
| 錄音開始 | UIImpactFeedbackGenerator(.heavy) |
| 錄音結束 | UINotificationFeedbackGenerator(.success) |
| 存入筆記 | UINotificationFeedbackGenerator(.success) |
| 加入生詞本 | UIImpactFeedbackGenerator(.light) |
| Tab 切換 | UISelectionFeedbackGenerator |
