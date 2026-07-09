# Selah MVP — User Story Map

> Epic: Selah iOS 極簡語言學習 App MVP
> 拆分模式：按工作流步驟 + 按複雜度遞進
> 估算體系：Fibonacci
> 團隊構成：iOS 開發 + 後端開發

---

## Story Map（用戶旅程 → Story 映射）

| 用戶旅程階段 | Story | 優先級 | Points |
|-------------|-------|--------|--------|
| 首次使用 | US-001, US-002, US-003 | P0 | 13 |
| 每日錄音 | US-004, US-005, US-006 | P0 | 13 |
| 聆聽學習 | US-007, US-008, US-009 | P0 | 11 |
| 練習回憶 | US-010, US-011 | P0 | 8 |
| 筆記管理 | US-012, US-013 | P1 | 5 |
| 寵物體驗 | US-014, US-015 | P1 | 8 |
| 體驗打磨 | US-016, US-017, US-018 | P1-P2 | 8 |
| **合計** | **18 Stories** | | **66 Points** |

---

## Sprint 1：基礎骨架（Week 1-2，13 Points）

### US-001：專案初始化與後端搭建

**角色**：作為開發者
**需求**：我希望搭建好 iOS 專案和 Supabase 後端環境
**價值**：以便後續所有功能有可運行的基礎
**優先級**：P0
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given Xcode 專案已創建, When 編譯運行, Then App 在模擬器上啟動且顯示空白頁面
- [ ] Given Supabase 專案已創建, When 執行 migration, Then User/Pet/Sentence/Vocab/Progress 表全部建好
- [ ] Given Edge Function 已部署, When 發送健康檢查請求, Then 返回 200 OK
- [ ] Given 環境變數已設定, When 後端調用 OpenAI API, Then 成功取得回應（STT/翻譯/TTS 均可達）
- [ ] Given CI/CD pipeline 已配置, When push 到 main 分支, Then TestFlight 自動構建

**依賴**：無
**技術備註**：使用 Swift Package Manager 管理依賴。GRDB for SQLite。Supabase Auth + Edge Functions。

---

### US-002：用戶註冊與登入

**角色**：作為新用戶
**需求**：我希望用 email 註冊帳號並登入
**價值**：以便我的學習數據可以跨設備同步
**優先級**：P0
**Story Points**：2

**Acceptance Criteria**：
- [ ] Given 用戶在註冊頁, When 輸入有效 email + 密碼（≥8 位）並提交, Then 帳號創建成功並自動登入
- [ ] Given 用戶已註冊, When 輸入正確 email + 密碼, Then 登入成功進入 Onboarding
- [ ] Given 用戶輸入錯誤密碼, When 提交登入, Then 顯示「email 或密碼錯誤」提示
- [ ] Given 用戶已完成 Onboarding, When 重新打開 App, Then 自動登入直接進入今日頁面
- [ ] Given Token 已過期, When 用戶操作, Then 自動 refresh token，用戶無感知

**依賴**：US-001
**技術備註**：Supabase Auth。Token 存在 Keychain。

---

### US-003：Onboarding 全流程

**角色**：作為新用戶
**需求**：我希望完成語言選擇、發音偏好、聲線選擇、寵物命名、種子句選擇的引導流程
**價值**：以便 App 根據我的偏好個性化學習體驗
**優先級**：P0
**Story Points**：8

**Acceptance Criteria**：
- [ ] Given 用戶首次登入, When 進入 Onboarding, Then 顯示語言選擇（English / 日本語・稍後）
- [ ] Given 用戶選擇 English, When 進入下一步, Then 顯示發音偏好（🇺🇸 美式 / 🇬🇧 英式）
- [ ] Given 用戶選擇發音偏好, When 進入下一步, Then 顯示聲線性別（♀ 女聲 / ♂ 男聲）+ 試聽按鈕
- [ ] Given 用戶選擇聲線, When 進入下一步, Then 顯示寵物命名輸入框 + 精靈蛋動畫
- [ ] Given 用戶輸入名字, When 進入下一步, Then 顯示 6 個種子句供選擇（最多選 3 個）
- [ ] Given 用戶選滿 3 句, When 點擊「孵化精靈」, Then 播放孵化動畫 → 進入今日頁面
- [ ] Given 用戶未完成 Onboarding 就關閉 App, When 重新打開, Then 回到上次停留的步驟
- [ ] Given Onboarding 完成, When 進入今日頁面, Then 3 個種子句已下載到本地（含音頻）

**依賴**：US-001, US-002
**技術備註**：種子句音頻從 CDN 下載。寵物名字存本地 + 同步 Supabase。

---

## Sprint 2：錄音核心（Week 3-4，13 Points）

### US-004：錄音頁面與話題引導

**角色**：作為用戶
**需求**：我希望在錄音頁面選擇話題方向並看到起始提示
**價值**：以便我知道該說什麼，不會面對空白輸入框不知所措
**優先級**：P0
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 用戶點擊「今日一句」, When 進入錄音頁面, Then 顯示 6 個話題 chip（工作/朋友/吐槽/心裡話/想法/生活）
- [ ] Given 用戶選擇一個話題, When chip 高亮, Then textarea placeholder 變為對應提示 + 下方出現 4 個 starter 句
- [ ] Given 用戶點擊一個 starter 句, When 觸發, Then 句子的前半段自動填入 textarea
- [ ] Given 用戶未選擇任何話題, When 直接開始錄音, Then 使用通用 placeholder
- [ ] Given 免費用戶今日已錄音 1 次, When 再次進入錄音頁, Then 顯示「今日次數已用完」+ 升級提示

**依賴**：US-003
**技術備註**：話題和 starters 數據硬編碼在客戶端。

---

### US-005：錄音 → STT → AI 翻譯 → TTS 全流程

**角色**：作為用戶
**需求**：我希望說一句中文後，App 自動幫我轉成英文並生成語音
**價值**：以便我獲得一句屬於自己的英文學習材料
**優先級**：P0
**Story Points**：8

**Acceptance Criteria**：
- [ ] Given 用戶點擊麥克風按鈕, When 開始錄音, Then 顯示波形動畫 + 計時器 + 麥克風按鈕變為停止
- [ ] Given 用戶停止錄音（≥2 秒）, When 音頻上傳成功, Then 顯示 STT 辨識的中文文字（可編輯）
- [ ] Given 錄音 <2 秒, When 停止錄音, Then Toast「錄音太短了，再說一次？」
- [ ] Given 用戶確認中文文字, When 點擊「產生英文」, Then 調用後端 → 顯示英文翻譯 + 拆解數據 + 詞彙候選
- [ ] Given 後端處理中, When 等待, Then 顯示載入動畫（精靈思考中⋯⋯）
- [ ] Given 後端返回成功, When 收到音頻 bytes, Then 音頻存入本地 + 可播放
- [ ] Given STT 失敗, When 返回錯誤, Then Toast「聽不清楚，可以再說一次嗎？」+ 保留錄音可重試
- [ ] Given AI 翻譯失敗, When 返回錯誤, Then Toast「精靈暫時想不到英文」+ 顯示「重試」按鈕
- [ ] Given TTS 失敗, When 返回錯誤, Then 句子保存但不含音頻 + 顯示「生成語音」按鈕供後續補生成
- [ ] Given 離線狀態, When 點擊麥克風, Then Toast「錄音需要網路連線」+ 麥克風按鈕禁用

**依賴**：US-001, US-004
**技術備註**：後端 /api/recording/process 一步完成 STT+翻譯+TTS。音頻 Base64 返回。客戶端存本地 FileManager。

---

### US-006：錄音結果詞彙選擇與存檔

**角色**：作為用戶
**需求**：我希望從 AI 翻譯結果中選擇想加入生詞本的詞組
**價值**：以便我自主決定哪些詞值得記住，而不是被系統強制灌入
**優先級**：P0
**Story Points**：2

**Acceptance Criteria**：
- [ ] Given 翻譯結果顯示, When 看到詞彙候選 chips, Then 每個 chip 可勾選/取消（打勾 = 加入生詞本）
- [ ] Given 用戶勾選了 2 個詞, When 點擊「存入筆記」, Then 句子 + 音頻存本地 + 2 個詞加入生詞本 + Toast「已存入！加入 2 個新詞」
- [ ] Given 用戶未勾選任何詞, When 點擊「存入筆記」, Then 句子存本地 + Toast「已存入！」
- [ ] Given 用戶點擊英文句子中的某個詞, When 該詞不在候選列表中, Then 彈出浮層顯示詞義 + 「加入生詞本」按鈕
- [ ] Given 句子已存入, When 返回今日頁面, Then 今日一句列更新為最新句子

**依賴**：US-005

---

## Sprint 3：聆聽系統（Week 5-6，11 Points）

### US-007：聆聽 Step 1-2（盲聽 + 預測）

**角色**：作為用戶
**需求**：我希望閉眼聽 3 遍英文後，猜猜這句話的中文是什麼
**價值**：以便訓練耳朵辨識聲音，並在猜測中激活主動回憶
**優先級**：P0
**Story Points**：5

**Acceptance Criteria**：
- [ ] Given 用戶進入聆聽頁面, When 頁面載入, Then 顯示 playlist 計數器（第 1/N 句）+ 播放按鈕 + 速度切換（0.85x → 1.0x → 1.2x → 0.7x）
- [ ] Given 用戶點擊播放, When 音頻播放, Then 播放 1 遍 + 計數器更新 + 按鈕變暫停
- [ ] Given 聽滿 3 遍, When 最後一遍結束, Then Step 2（預測）解鎖 + 顯示 coach hint（首次）
- [ ] Given Step 2 解鎖, When 用戶點擊「我想到了」, Then 開始 3 秒倒數 + 按鈕文字變為「再想想？⏱️ 3秒後可揭示」
- [ ] Given 倒數中用戶再次點擊, When <3 秒, Then Toast「再想想！還沒到 3 秒 🤔」
- [ ] Given 倒數結束, When 用戶點擊, Then 揭示中英文文字 + Step 3 解鎖
- [ ] Given 今日無聆聽句子, When 進入聆聽頁面, Then 空狀態「還沒有句子可以聽。先說一句中文吧！」
- [ ] Given 本地音頻文件丟失, When 嘗試播放, Then 自動重新生成 TTS（顯示「重新生成中⋯⋯」）

**依賴**：US-005（需要有句子和音頻）
**技術備註**：速度切換透過 AVAudioPlayer.rate 實現。predictStartTime 需正確重置。

---

### US-008：聆聽 Step 3（句子拆解）

**角色**：作為用戶
**需求**：我希望看到句子的詞組拆解和用法解釋
**價值**：以便理解英文句子的結構和關鍵詞組的用法
**優先級**：P0
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given Step 3 解鎖, When 頁面顯示, Then 拆解區域從佔位符變為實際內容（英文句子 + 詞組 chips + 解釋）
- [ ] Given 用戶點擊一個詞組 chip, When 觸發, Then 彈出浮層顯示詞義 + 用法說明 + 「加入生詞本」按鈕
- [ ] Given 用戶在浮層中點擊「加入生詞本」, When 確認, Then 詞組加入生詞本 + Toast + 浮層關閉
- [ ] Given 用戶點擊「理解了，繼續跟讀」, When 觸發, Then Step 4 解鎖
- [ ] Given coach hint 未dismiss, When Step 3 首次顯示, Then 顯示拆解 coach hint

**依賴**：US-007

---

### US-009：聆聽 Step 4（跟讀 + 完成）

**角色**：作為用戶
**需求**：我希望看著英文開口跟讀，並聽聽原生發音比對
**價值**：以便透過輸出鞏固所學，並自我校正發音
**優先級**：P0
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given Step 4 解鎖, When 頁面顯示, Then 英文句子可見 + 麥克風按鈕可用 + coach hint（首次）
- [ ] Given 用戶點擊麥克風, When 錄音中, Then 麥克風變紅 + 脈衝動畫 + 2.5 秒後自動停止
- [ ] Given 跟讀錄音結束, When 自動停止, Then 顯示「聽聽原生發音」按鈕
- [ ] Given 用戶點擊原生發音按鈕, When 播放, Then 播放 TTS 音頻 + 按鈕顯示「播放中⋯⋯」
- [ ] Given 用戶點擊「完成本句」, When 非最後一句, Then 切換到下一句 + 重置所有步驟
- [ ] Given 用戶點擊「完成本句」, When 是最後一句, Then Toast「今天的聆聽全部完成！」→ 自動返回今日頁面
- [ ] Given 完成聆聽, When 返回今日頁面, Then 進度更新 + 精靈播放 listen-complete 動畫

**依賴**：US-008

---

## Sprint 4：練習 + 預覽 + 筆記（Week 7-8，13 Points）

### US-010：Quiz 翻卡練習

**角色**：作為用戶
**需求**：我希望用翻卡方式回憶已學過的句子
**價值**：以便透過主動回憶加深記憶
**優先級**：P0
**Story Points**：5

**Acceptance Criteria**：
- [ ] Given 用戶進入練習頁面, When 有可複習句子, Then 顯示中文 + 「點擊揭示答案」 + 進度條（1/N）
- [ ] Given 用戶點擊揭示區域, When 觸發, Then 英文答案淡入 + 三點自評按鈕解鎖
- [ ] Given 用戶選「記得很清楚 ✅」, When 觸發, Then 下一張卡 + 精靈 quiz-good 動畫
- [ ] Given 用戶選「差一點 🤔」, When 觸發, Then 下一張卡 + 精靈 quiz-mid 動畫
- [ ] Given 用戶選「完全不會 😵」, When 觸發, Then 下一張卡 + 精靈 quiz-fail 動畫（溫柔鼓勵）
- [ ] Given 連續 2 題「完全不會」, When 第 2 題評完, Then 精靈播放 encouragement 動畫
- [ ] Given 全部卡片完成, When 最後一張評完, Then 顯示完成畫面 + 精靈 quiz-complete 動畫
- [ ] Given 無可複習句子, When 進入練習頁面, Then 空狀態「先完成聆聽，句子才會出現在這裡」

**依賴**：US-009（句子需先完成聆聽才能出 Quiz）
**技術備註**：Quiz 選題邏輯：從 mastery_status='learning' 的句子中按間隔重複算法選取。

---

### US-011：夜間預覽

**角色**：作為用戶
**需求**：我希望在睡前看看明天要學的句子
**價值**：以便提前熟悉內容，降低明天聆聽時的認知負荷
**優先級**：P0
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 時間 ≥21:00, When 今日頁面顯示, Then 夜間預覽列顯示「開放中」+ 可點擊
- [ ] Given 時間 <21:00, When 今日頁面顯示, Then 夜間預覽列顯示「21:00 後開放」+ 半透明 + 不可點擊
- [ ] Given 用戶進入預覽頁面, When 載入, Then 顯示明日新句（2-3 句）+ 舊句複習（1-2 句）
- [ ] Given 用戶點擊句中高亮詞組, When 觸發, Then 彈出浮層顯示詞義 + 「加入生詞本」按鈕
- [ ] Given 用戶點擊「預習好了」, When 觸發, Then Toast + 自動返回今日頁面
- [ ] Given 智能推薦為夜間預覽（21:00+）, When 點擊推薦卡, Then 進入預覽頁面

**依賴**：US-005（需要有明日句子）

---

### US-012：筆記頁面 — 句子列表與分類篩選

**角色**：作為用戶
**需求**：我希望瀏覽我所有的句子並按分類篩選
**價值**：以便回顧自己的學習歷程
**優先級**：P1
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 用戶切到筆記 Tab, When 頁面載入, Then 顯示所有句子（按時間倒序）+ 頂部統計（N 句 · 掌握 M 句）
- [ ] Given 用戶滑動分類 chip, When 點擊一個分類, Then 列表只顯示該分類的句子 + chip 高亮
- [ ] Given 用戶再次點擊已選 chip, When 觸發, Then 取消篩選，顯示全部
- [ ] Given 某分類無句子, When 篩選該分類, Then 顯示空狀態「這個分類還沒有句子」
- [ ] Given 句子列表為空, When 進入筆記頁, Then 空狀態「還沒有句子。開始說你的第一句中文吧！」

**依賴**：US-005

---

### US-013：生詞本管理

**角色**：作為用戶
**需求**：我希望查看和管理我收集的生詞
**價值**：以便追蹤自己的詞彙積累進度
**優先級**：P1
**Story Points**：2

**Acceptance Criteria**：
- [ ] Given 筆記頁底部, When 滾動到生詞區域, Then 顯示所有生詞 + 說明文字「生詞不分類別，是你在學習中自然累積的」
- [ ] Given 每個生詞項, When 顯示, Then 顯示英文詞組 + 中文釋義 + 來源句子 + 掌握狀態
- [ ] Given 生詞 mastery='mastered', When 顯示, Then 顯示「✓ 已使用 N 次」綠色標籤
- [ ] Given 用戶長按一個生詞, When 觸發, Then 顯示「刪除」選項 → 確認後刪除
- [ ] Given 生詞本為空, When 顯示, Then 「還沒有生詞。在預覽和拆解中點擊詞組即可加入。」

**依賴**：US-006, US-008, US-011

---

## Sprint 5：寵物 + 體驗打磨（Week 9-10，16 Points）

### US-014：寵物精靈基礎 + 漸進裝飾

**角色**：作為用戶
**需求**：我希望看到一個可愛的種子精靈，它會隨著我的使用逐漸長出葉子和花
**價值**：以便我有一個溫暖的陪伴感，而不是冷冰冰的工具
**優先級**：P1
**Story Points**：5

**Acceptance Criteria**：
- [ ] Given 今日頁面頂部, When 載入, Then 顯示精靈（單一形態）+ 名字 + 心情文字 + 今日小故事
- [ ] Given Day 1-3, When 精靈顯示, Then 純種子形態（無裝飾）
- [ ] Given Day 4, When 精靈顯示, Then 頭頂出現小葉芽（漸進出現，非突然切換）
- [ ] Given Day 7, When 精靈顯示, Then 葉子變大 + 出現葉脈紋路
- [ ] Given Day 10, When 精靈顯示, Then 葉旁出現小花苞
- [ ] Given Day 14, When 精靈顯示, Then 花苞綻放成珊瑚色小花
- [ ] Given 用戶連續 3 天活躍, When 精靈 mood, Then mood='happy' + 活潑動畫
- [ ] Given 用戶 3+ 天未活躍, When 精靈 mood, Then mood='quiet' + 安靜漂浮 + 亮度降低
- [ ] Given 用戶回歸（缺席 1+ 天）, When 打開 App, Then 精靈播放 welcome-back 動畫

**依賴**：US-003
**技術備註**：使用 SwiftUI 動畫或 Lottie。裝飾階段由 Day 數計算，不存儲「階段」狀態。

---

### US-015：寵物動畫系統（P0 動畫）

**角色**：作為用戶
**需求**：我希望精靈對我的學習行為有即時的動畫反應
**價值**：以便感受到精靈是「活的」，增加情感連結
**優先級**：P1
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 用戶在聆聽播放音頻, When 音頻播放中, Then 精靈播放 listen-playing 動畫（微震動）
- [ ] Given 用戶 Quiz 選「記得很清楚」, When 觸發, Then 精靈播放 quiz-good 動畫（跳躍+旋轉）
- [ ] Given 用戶 Quiz 選「完全不會」, When 觸發, Then 精靈播放 quiz-fail 動畫（下沉+閉眼+恢復）
- [ ] Given 用戶錄音完成, When 觸發, Then 精靈播放 rec-done 動畫（回正+葉子舉高）
- [ ] Given 用戶完成全部聆聽, When 觸發, Then 精靈播放 listen-complete 動畫
- [ ] Given 無操作 3-8 秒, When idle 觸發, Then 精靈隨機播放一個 idle 動畫
- [ ] Given 深夜時段（22:00-5:59）, When 精靈顯示, Then 所有動畫幅度減半 + 亮度降低

**依賴**：US-014

---

### US-016：智能推薦 + 去重

**角色**：作為用戶
**需求**：我希望首頁根據時段推薦最適合的學習活動，且不與下方列表重複
**價值**：以便我不用思考「接下來該做什麼」
**優先級**：P1
**Story Points**：2

**Acceptance Criteria**：
- [ ] Given 早晨（6-12 點）, When 今日頁面載入, Then 智能推薦顯示「聆聽」+ 下方聆聽列隱藏
- [ ] Given 下午（12-18 點）, When 今日頁面載入, Then 智能推薦顯示「練習」+ 下方練習列隱藏
- [ ] Given 晚上（18-21 點）, When 今日頁面載入, Then 智能推薦顯示「聆聽」+ 下方聆聽列隱藏
- [ ] Given 深夜（21+ 點）, When 今日頁面載入, Then 智能推薦顯示「夜間預覽」+ 不隱藏任何列
- [ ] Given 智能推薦指向聆聽, When 下方列表有聆聽列, Then 聆聽列隱藏（避免重複）

**依賴**：US-003

---

### US-017：設定頁面 + 聲線切換

**角色**：作為用戶
**需求**：我希望切換語音聲線和通知設定
**價值**：以便根據個人偏好調整學習體驗
**優先級**：P1
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 用戶進入設定頁面, When 載入, Then 顯示聲線選擇 + 通知開關 + 通知時間
- [ ] Given 用戶切換聲線, When 選擇新聲線, Then 播放試聽音頻 + 確認後更新 voice_id
- [ ] Given 聲線已切換, When 下次生成 TTS, Then 使用新聲線
- [ ] Given 用戶開啟通知, When 設定通知時間, Then 排程本地通知（每日提醒學習）
- [ ] Given 用戶關閉通知, When 保存, Then 取消所有已排程通知
- [ ] Given 已有句子使用舊聲線, When 切換聲線後, Then 舊句子保持原聲線（不重新生成）

**依賴**：US-002

---

### US-018：學習教練提示

**角色**：作為首次使用的用戶
**需求**：我希望在前 5 次使用每個功能時看到步驟引導
**價值**：以便我理解每個學習步驟的目的，而不是盲目操作
**優先級**：P2
**Story Points**：3

**Acceptance Criteria**：
- [ ] Given 用戶首次進入聆聽頁面, When Step 1 顯示, Then coach hint「閉上眼睛，只用耳朵聽⋯⋯」+ 「知道了」dismiss
- [ ] Given coach hint 已 dismiss, When 再次進入, Then 不再顯示
- [ ] Given 用戶首次進入預測步驟, When 解鎖, Then coach hint「試著猜猜⋯⋯猜的過程本身就是學習」
- [ ] Given 用戶首次進入拆解步驟, When 顯示, Then coach hint「注意看詞組的用法⋯⋯」
- [ ] Given 用戶首次進入跟讀步驟, When 解鎖, Then coach hint「開口跟著說！⋯⋯」
- [ ] Given 用戶首次進入 Quiz, When 載入, Then coach hint「先試著在腦中想出英文⋯⋯」
- [ ] Given 用戶首次進入錄音, When 載入, Then coach hint「不用想英文！用你最自然的中文⋯⋯」
- [ ] Given 每個 coach hint 獨立計算, When dismiss 一個, Then 不影響其他 hint

**依賴**：US-007, US-010, US-004

---

## 依賴關係圖

```
US-001 (專案初始化)
  ├── US-002 (註冊登入)
  │     └── US-003 (Onboarding)
  │           ├── US-004 (話題引導)
  │           │     └── US-005 (錄音全流程) ← 核心
  │           │           ├── US-006 (詞彙選擇)
  │           │           ├── US-007 (盲聽+預測)
  │           │           │     ├── US-008 (拆解)
  │           │           │     │     └── US-009 (跟讀)
  │           │           │     └── US-010 (Quiz)
  │           │           └── US-011 (夜間預覽)
  │           ├── US-012 (句子列表)
  │           ├── US-014 (寵物基礎)
  │           │     └── US-015 (寵物動畫)
  │           └── US-016 (智能推薦)
  └── US-017 (設定)

US-013 (生詞本) ← 依賴 US-006 + US-008 + US-011
US-018 (教練提示) ← 依賴 US-007 + US-010 + US-004
```

**可並行開發的 Story 組合：**
- US-004 + US-012 + US-014（獨立模塊，無數據依賴）
- US-007 + US-011（同層級，可 Mock 數據並行）
- US-015 + US-016 + US-017（Sprint 5 內部可並行）
