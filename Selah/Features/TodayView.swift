import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("今日", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                NotesView()
            }
            .tabItem {
                Label("筆記", systemImage: "book.fill")
            }
            .tag(1)
        }
        .tint(.selahCoral)
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: SelahSpacing.xl) {
                // Sprite
                if let companion = appState.activeCompanion {
                    PetView(
                        companion: companion,
                        todayStory: "小豆今天很想聽你說一句話 🌱"
                    )
                }

                // Time-aware greeting
                greetingSection

                // Smart recommendation card
                recommendationCard

                // Activity rows
                activityRows
            }
            .padding(.horizontal, SelahSpacing.page)
            .padding(.bottom, 20)
        }
        .background(Color.selahBgPrimary)
        .navigationTitle("今日")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.selahDisplayMedium)
            Text("慢慢來，今天有一句就很好")
                .selahBodyMedium()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:  return "早安 ☀️"
        case 12..<18: return "午安 ☀️"
        case 18..<22: return "晚安 🌙"
        default:      return "夜深了 🌙"
        }
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: SelahSpacing.sm) {
            HStack {
                Text("下一步")
                    .font(.selahLabelLarge)
                    .foregroundColor(.selahCoral)
                Spacer()
            }

            NavigationLink(destination: ListenView()) {
                HStack(spacing: SelahSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.selahLavenderSoft)
                            .frame(width: 44, height: 44)
                        Text("🎧")
                            .font(.system(size: 22))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("聆聽")
                            .selahHeadlineMedium()
                        Text("有 3 句昨晚看過，等你聽一次")
                            .selahBodySmall()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("→")
                        .font(.system(size: 20))
                        .foregroundColor(.selahLavender)
                }
                .padding(SelahSpacing.lg)
                .background(Color.selahCardPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                        .strokeBorder(Color.selahBorderLight, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Reason preview
            VStack(alignment: .leading, spacing: 4) {
                Text("為什麼是這一步？")
                    .font(.selahLabelSmall)
                    .foregroundColor(.selahTextTertiary)

                Text("這幾句已經有點熟了，現在讓耳朵接上。")
                    .selahBodySmall()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Activity Rows

    private var activityRows: some View {
        VStack(alignment: .leading, spacing: SelahSpacing.md) {
            // Manual entries header
            Button(action: {}) {
                HStack {
                    Text("自己選學習內容")
                        .font(.selahLabelSmall)
                        .foregroundColor(.selahTextTertiary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.selahTextTertiary)
                }
            }

            // Listen
            NavigationLink(destination: ListenView()) {
                rowContent(
                    icon: "🎧",
                    color: .selahLavender,
                    title: "聆聽",
                    subtitle: "聽、猜、拆、說"
                )
            }
            .buttonStyle(.plain)

            // Practice
            NavigationLink(destination: PracticeView()) {
                rowContent(
                    icon: "✏️",
                    color: .selahSage,
                    title: "練習",
                    subtitle: "翻卡回憶學過的句子"
                )
            }
            .buttonStyle(.plain)

            // Night Preview
            NavigationLink(destination: NightPreviewView()) {
                rowContent(
                    icon: "🌙",
                    color: .selahSky,
                    title: "夜間預覽",
                    subtitle: "先看一眼，明天聽起來更輕鬆"
                )
            }
            .buttonStyle(.plain)

            // Today Sentence (highlighted)
            NavigationLink(destination: TodaySentenceView()) {
                rowContent(
                    icon: "🎙️",
                    color: .selahCoral,
                    title: "今日一句",
                    subtitle: "說一句中文，變成你的英文"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func rowContent(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: SelahSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: SelahCornerRadius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(icon)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .selahHeadlineMedium()
                Text(subtitle)
                    .selahBodySmall()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("›")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.selahTextTertiary)
        }
        .padding(SelahSpacing.lg)
        .background(Color.selahCardPrimary)
        .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                .strokeBorder(Color.selahBorderLight, lineWidth: 1)
        )
    }
}

// MARK: - Placeholder Views (to be fully implemented in M0)

struct ListenView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStage = 1
    @State private var currentSentenceIndex = 0
    @State private var coachVisible = true

    let mockSentences = [
        "I was swamped at work today, but I still got off on time.",
        "My coworker's joke wasn't funny at all.",
        "I seriously can't take this weather anymore.",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: SelahSpacing.xl) {
                // Coach hint
                CoachHint(
                    text: "閉上眼睛，只用耳朵聽。聽到幾個詞就算進步！",
                    isVisible: $coachVisible
                )

                // Counter
                HStack {
                    Text("◀ 第 \(currentSentenceIndex + 1)/\(mockSentences.count) 句 ▶")
                        .selahBodyMedium()
                }

                // Stage bar
                StageBar(currentStage: currentStage, maxStage: 4)

                // Sentence area
                VStack(spacing: SelahSpacing.lg) {
                    if currentStage >= 3 {
                        Text(mockSentences[currentSentenceIndex])
                            .font(.selahHeadlineLarge)
                            .foregroundColor(.selahSage)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Stage content
                    stageContent
                }
                .frame(maxWidth: .infinity)
                .padding(SelahSpacing.xl)
                .background(Color.selahCardPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.xl))
            }
            .padding(SelahSpacing.page)
        }
        .background(Color.selahBgPrimary)
        .navigationTitle("🎧 聆聽")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private var stageContent: some View {
        switch currentStage {
        case 1:
            VStack(spacing: SelahSpacing.md) {
                Text("🎧").font(.system(size: 48))
                Text("閉上眼睛，聽 3 遍")
                    .selahHeadlineMedium()
                Button("播放 ▶") {
                    currentStage = 2
                }
                .buttonStyle(.borderedProminent)
                .tint(.selahLavender)
            }
        case 2:
            VStack(spacing: SelahSpacing.md) {
                Text("🧠").font(.system(size: 48))
                Text("猜猜這句話的英文是什麼？")
                    .selahHeadlineMedium()
                Button("我試著猜了") {
                    currentStage = 3
                }
                .buttonStyle(.borderedProminent)
                .tint(.selahLavender)
            }
        case 3:
            VStack(spacing: SelahSpacing.md) {
                Text("🔍").font(.system(size: 48))
                Text("看詞組怎麼用")
                    .selahHeadlineMedium()
                Badge(text: "swamped = 忙翻了", style: .amber)
                Badge(text: "got off on time = 準時下班", style: .amber)
                Button("理解了，繼續跟讀") {
                    currentStage = 4
                }
                .buttonStyle(.borderedProminent)
                .tint(.selahLavender)
            }
        case 4:
            VStack(spacing: SelahSpacing.md) {
                Text("🗣️").font(.system(size: 48))
                Text("看著英文，開口說")
                    .selahHeadlineMedium()
                Button("🎤 跟讀錄音") {}
                    .buttonStyle(.bordered)
                Button("完成本句") {
                    if currentSentenceIndex < mockSentences.count - 1 {
                        currentSentenceIndex += 1
                        currentStage = 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.selahSage)
            }
        default:
            EmptyView()
        }
    }
}

struct PracticeView: View {
    @State private var currentCardIndex = 0
    @State private var isComplete = false

    let mockCards = [
        (zh: "今天工作忙翻了，但還是準時下班了", en: "I was swamped at work today, but I still got off on time."),
        (zh: "同事說的笑話一點都不好笑", en: "My coworker's joke wasn't funny at all."),
        (zh: "我真的受不了這個天氣了", en: "I seriously can't take this weather anymore."),
    ]

    var body: some View {
        VStack(spacing: SelahSpacing.xl) {
            if isComplete {
                completeView
            } else {
                ProgressBar(progress: Double(currentCardIndex) / Double(mockCards.count))
                    .padding(.horizontal, SelahSpacing.page)

                Text("\(currentCardIndex + 1) / \(mockCards.count)")
                    .font(.selahLabelLarge)
                    .foregroundColor(.selahTextTertiary)

                QuizCard(
                    zhText: mockCards[currentCardIndex].zh,
                    enText: mockCards[currentCardIndex].en
                )

                AssessmentButtons(
                    onGood: { advance() },
                    onMid: { advance() },
                    onFail: { advance() }
                )
            }
        }
        .padding(SelahSpacing.page)
        .background(Color.selahBgPrimary)
        .navigationTitle("✏️ 練習")
    }

    private var completeView: some View {
        VStack(spacing: SelahSpacing.lg) {
            Text("🎉").font(.system(size: 64))
            Text("今天的練習完成了！")
                .font(.selahDisplayMedium)
            Text("休息一下，或者再留下今天的一句。")
                .selahBodyMedium()
        }
    }

    private func advance() {
        if currentCardIndex < mockCards.count - 1 {
            currentCardIndex += 1
        } else {
            isComplete = true
        }
    }
}

struct NightPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: SelahSpacing.lg) {
                Text("先看一眼就好，明天聽起來會更輕鬆。")
                    .selahBodyMedium()

                ForEach(1...3, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(i) · 句子 \(i)")
                            .selahHeadlineSmall()
                        Text("This is a preview sentence #\(i).")
                            .selahBodyLarge()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
                }

                Button("預習好了") {}
                    .buttonStyle(.borderedProminent)
                    .tint(.selahSage)
            }
            .padding(SelahSpacing.page)
        }
        .background(Color.selahBgPrimary)
        .navigationTitle("🌙 夜間預覽")
    }
}

struct TodaySentenceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModelHolder = TodaySentenceViewModelHolder()
    @State private var chineseText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: SelahSpacing.xl) {
                Text("說一句中文\n它會變成你之後會聽、會練的英文")
                    .font(.selahDisplayMedium)
                    .multilineTextAlignment(.center)

                if let vm = viewModelHolder.viewModel {
                    VoiceProfilePicker(selected: Binding(
                        get: { vm.selectedVoiceProfile },
                        set: { vm.selectedVoiceProfile = $0 }
                    ))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    flowContent(vm: vm)
                }
            }
            .padding(SelahSpacing.page)
        }
        .background(Color.selahBgPrimary)
        .navigationTitle("🎙️ 今日一句")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModelHolder.setup(
                speechService: appState.speechService ?? MockSpeechRecognitionService(),
                sentenceService: appState.sentenceGenService ?? MockSentenceGenerationService(),
                audioService: appState.audioGenService ?? MockAudioGenerationService(),
                modelContext: modelContext,
                defaultVoiceProfile: appState.preferences.voiceProfile
            )
        }
    }

    @ViewBuilder
    private func flowContent(vm: TodaySentenceViewModel) -> some View {
        switch vm.flowState {
        case .idle: idleState(vm: vm)
        case .recording, .recognizingText: recordingState(vm: vm)
        case .confirmingChinese(let transcript): confirmingChineseState(vm: vm, transcript: transcript)
        case .translating: translatingState
        case .reviewingResult(let result): reviewingResultState(vm: vm, result: result)
        case .saving: savingState
        case .done: doneState(vm: vm)
        case .error(let message): errorState(vm: vm, message: message)
        }
    }

    // MARK: - Idle
    private func idleState(vm: TodaySentenceViewModel) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SelahSpacing.sm) {
                    ForEach(SentenceCategory.allCases, id: \.self) { cat in
                        CatChip(category: cat, isSelected: vm.selectedCategory == cat, action: {
                            vm.selectedCategory = vm.selectedCategory == cat ? nil : cat
                        })
                    }
                }
            }

            Button(action: { vm.startRecording() }) {
                VStack(spacing: SelahSpacing.sm) {
                    ZStack {
                        Circle().fill(Color.selahCoral.opacity(0.12)).frame(width: 72, height: 72)
                        Image(systemName: "mic.fill").font(.system(size: 28)).foregroundColor(.selahCoral)
                    }
                    Text("按住說中文").selahBodyMedium()
                }
            }.buttonStyle(.plain)

            VStack(spacing: SelahSpacing.sm) {
                Text("或者直接打字").selahLabelSmall()
                TextEditor(text: $chineseText)
                    .font(.selahBodyLarge).frame(minHeight: 80).padding(SelahSpacing.md)
                    .background(Color.selahCardPrimary).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: SelahCornerRadius.md).strokeBorder(Color.selahBorderLight, lineWidth: 1))
                Button(action: { vm.translate(chineseText: chineseText) }) {
                    Text("產生英文 ->").font(.selahHeadlineMedium).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.md)
                        .background(chineseText.isEmpty ? Color.selahTextTertiary : Color.selahCoral)
                        .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
                }.disabled(chineseText.isEmpty)
            }
        }
    }

    // MARK: - Recording
    private func recordingState(vm: TodaySentenceViewModel) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            ZStack {
                Circle().fill(Color.selahCoral.opacity(0.2)).frame(width: 80, height: 80).scaleEffect(1.1)
                Image(systemName: "mic.fill").font(.system(size: 32)).foregroundColor(.selahCoral)
            }
            Text("正在聽你說話⋯⋯").selahHeadlineMedium()
            Text("放開結束錄音").selahBodySmall()
            Button("取消") { vm.cancel() }.foregroundColor(.selahTextTertiary)
        }.frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.xxl)
    }

    // MARK: - Confirming Chinese
    private func confirmingChineseState(vm: TodaySentenceViewModel, transcript: String) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            Text("確認你的中文").selahLabelLarge().frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: Binding(get: { transcript }, set: { vm.flowState = .confirmingChinese(transcript: $0) }))
                .font(.selahBodyLarge).frame(minHeight: 80).padding(SelahSpacing.md)
                .background(Color.selahCardPrimary).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
                .overlay(RoundedRectangle(cornerRadius: SelahCornerRadius.md).strokeBorder(Color.selahCoral.opacity(0.3), lineWidth: 1))
            HStack(spacing: SelahSpacing.md) {
                Button("重錄") { vm.cancel() }.buttonStyle(.bordered)
                Button(action: { vm.translate(chineseText: transcript) }) {
                    Text("確認 -> 翻譯").font(.selahHeadlineMedium).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.md)
                        .background(Color.selahCoral).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
                }
            }
        }
    }

    // MARK: - Translating
    private var translatingState: some View {
        VStack(spacing: SelahSpacing.md) {
            ProgressView().scaleEffect(1.5).tint(.selahCoral)
            Text("正在轉成自然英文⋯⋯").selahHeadlineMedium()
            Text("根據網路狀況可能需要幾秒鐘").selahBodySmall()
        }.frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.xxl)
    }

    // MARK: - Reviewing Result
    private func reviewingResultState(vm: TodaySentenceViewModel, result: GeneratedSentenceResult) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            VStack(spacing: SelahSpacing.sm) {
                Text("英文").selahLabelLarge().frame(maxWidth: .infinity, alignment: .leading)
                Text(result.targetText).font(.selahHeadlineLarge).foregroundColor(.selahSage)
                    .multilineTextAlignment(.center).padding().frame(maxWidth: .infinity)
                    .background(Color.selahSageSoft).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
            }
            if !result.deconstruction.isEmpty {
                VStack(alignment: .leading, spacing: SelahSpacing.sm) {
                    Text("拆解").selahLabelLarge()
                    ForEach(result.deconstruction, id: \.surfaceText) { item in
                        HStack(spacing: SelahSpacing.sm) {
                            Text(item.surfaceText).selahBodyMedium().foregroundColor(.selahCoral)
                            Text("=").foregroundColor(.selahTextTertiary)
                            Text(item.meaning).selahBodySmall()
                        }.padding(SelahSpacing.sm).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.selahCardPrimary).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.xs))
                    }
                }
            }
            if !result.vocabulary.isEmpty {
                VStack(alignment: .leading, spacing: SelahSpacing.sm) {
                    Text("生詞候選").selahLabelLarge()
                    ForEach(result.vocabulary, id: \.surfaceText) { vocab in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(vocab.surfaceText) - \(vocab.meaningInContext)").selahBodyMedium()
                            Text("建議狀態：\(vocab.suggestedHelpState.userFacingGroup)").selahBodySmall()
                        }.padding(SelahSpacing.sm).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.selahCardPrimary).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.xs))
                    }
                }
            }
            Button(action: {
                if case .confirmingChinese(let transcript) = vm.flowState {
                    vm.save(result: result, sourceText: transcript)
                } else if !chineseText.isEmpty {
                    vm.save(result: result, sourceText: chineseText)
                }
            }) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("存入筆記")
                }.font(.selahHeadlineMedium).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.md)
                    .background(Color.selahSage).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }
            Button("不要了，重來") { vm.cancel() }.foregroundColor(.selahTextTertiary)
        }
    }

    // MARK: - Saving
    private var savingState: some View {
        VStack(spacing: SelahSpacing.md) {
            ProgressView().scaleEffect(1.5).tint(.selahSage)
            Text("正在保存⋯⋯").selahHeadlineMedium()
            Text("英文語音正在背景生成").selahBodySmall()
        }.frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.xxl)
    }

    // MARK: - Done
    private func doneState(vm: TodaySentenceViewModel) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            Text("🌱").font(.system(size: 48))
            Text("存好了！").font(.selahDisplayMedium)
            Text("語音正在背景準備，好了會通知你。").selahBodyMedium()
            Button(action: { vm.cancel(); dismiss() }) {
                Text("回到今日").font(.selahHeadlineMedium).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.md)
                    .background(Color.selahCoral).clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }
        }.frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.xxl)
    }

    // MARK: - Error
    private func errorState(vm: TodaySentenceViewModel, message: String) -> some View {
        VStack(spacing: SelahSpacing.lg) {
            Text("😅").font(.system(size: 48))
            Text("出了點問題").selahHeadlineMedium()
            Text(message).selahBodySmall().multilineTextAlignment(.center)
            Button("再試一次") { vm.dismissError() }.buttonStyle(.borderedProminent).tint(.selahCoral)
        }.frame(maxWidth: .infinity).padding(.vertical, SelahSpacing.xxl)
    }
}

struct NotesView: View {
    @State private var selectedCategory: SentenceCategory? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SelahSpacing.xl) {
                    // Stats
                    HStack {
                        Text("📝 我的筆記")
                            .font(.selahDisplayMedium)
                        Spacer()
                        Text("0 句 · 掌握 0 句")
                            .selahBodySmall()
                    }

                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: SelahSpacing.sm) {
                            ForEach(SentenceCategory.allCases, id: \.self) { cat in
                                CatChip(
                                    category: cat,
                                    isSelected: selectedCategory == cat,
                                    action: {
                                        selectedCategory = selectedCategory == cat ? nil : cat
                                    }
                                )
                            }
                        }
                    }

                    // Empty state
                    VStack(spacing: SelahSpacing.md) {
                        Text("🌱")
                            .font(.system(size: 48))
                        Text("還沒有句子")
                            .selahHeadlineMedium()
                        Text("開始說你的第一句中文吧！")
                            .selahBodyMedium()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.xxl)

                    // Vocab section
                    vocabSection

                    // Memories section
                    memoriesSection
                }
                .padding(SelahSpacing.page)
            }
            .background(Color.selahBgPrimary)
            .navigationTitle("筆記")
        }
    }

    private var vocabSection: some View {
        VStack(alignment: .leading, spacing: SelahSpacing.md) {
            Text("生詞")
                .font(.selahHeadlineLarge)

            Text("生詞不分類別，是你在學習中自然累積的")
                .selahBodySmall()

            Text("還沒有生詞。在預覽和拆解中點擊詞組即可加入。")
                .selahBodySmall()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, SelahSpacing.lg)
        }
    }

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: SelahSpacing.md) {
            Text("小豆的回憶")
                .font(.selahHeadlineLarge)

            Text("這些是學習旅程中，小豆記得的事")
                .selahBodySmall()

            Text("還沒有回憶。開始學習後，小豆會記下你和句子之間的故事。")
                .selahBodySmall()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, SelahSpacing.lg)
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0
    @State private var petName = ""

    var body: some View {
        VStack(spacing: SelahSpacing.xxl) {
            Spacer()

            switch step {
            case 0:
                languageStep
            case 1:
                nameStep
            case 2:
                seedStep
            case 3:
                hatchStep
            default:
                EmptyView()
            }

            Spacer()
        }
        .padding(SelahSpacing.page)
        .background(Color.selahBgPrimary)
    }

    private var languageStep: some View {
        VStack(spacing: SelahSpacing.xl) {
            Text("你想學什麼語言？")
                .font(.selahDisplayMedium)

            VStack(spacing: SelahSpacing.md) {
                Button(action: { step = 1 }) {
                    HStack {
                        Text("🇺🇸")
                        Text("英文")
                        Spacer()
                        Text("→")
                    }
                    .font(.selahHeadlineMedium)
                    .foregroundColor(.selahTextPrimary)
                    .padding(SelahSpacing.lg)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                }

                Button(action: {}) {
                    HStack {
                        Text("🇯🇵")
                        Text("日文 · 敬請期待")
                        Spacer()
                    }
                    .font(.selahHeadlineMedium)
                    .foregroundColor(.selahTextTertiary)
                    .padding(SelahSpacing.lg)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                }
                .disabled(true)
            }
        }
    }

    private var nameStep: some View {
        VStack(spacing: SelahSpacing.xl) {
            // Egg animation (simplified)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.selahAmber, Color.selahAmber.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(Text("🥚").font(.system(size: 36)))

            Text("幫你的語言精靈取個名字")
                .font(.selahDisplayMedium)

            TextField("精靈的名字", text: $petName)
                .font(.selahHeadlineMedium)
                .multilineTextAlignment(.center)
                .padding(SelahSpacing.md)
                .background(Color.selahCardPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))

            Button(action: { step = 2 }) {
                Text("繼續 →")
                    .font(.selahHeadlineMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(petName.isEmpty ? Color.selahTextTertiary : Color.selahCoral)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }
            .disabled(petName.isEmpty)
        }
    }

    private var seedStep: some View {
        VStack(spacing: SelahSpacing.xl) {
            Text("選 3 句你可能想說的話")
                .font(.selahDisplayMedium)

            Text("不用緊張，之後你的句子會慢慢取代它們")
                .selahBodySmall()

            // Simplified seed selection
            ForEach(["今天過得怎麼樣？", "工作好累但還是完成了", "想約朋友吃飯"], id: \.self) { seed in
                HStack {
                    Text(seed)
                        .selahBodyLarge()
                    Spacer()
                    Image(systemName: "circle")
                        .foregroundColor(.selahBorder)
                }
                .padding(SelahSpacing.md)
                .background(Color.selahCardPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.md))
            }

            Button(action: { step = 3 }) {
                Text("孵化精靈 →")
                    .font(.selahHeadlineMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(Color.selahCoral)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }
        }
    }

    private var hatchStep: some View {
        VStack(spacing: SelahSpacing.xl) {
            // Hatch animation placeholder
            VStack(spacing: SelahSpacing.md) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.selahAmber, Color.selahAmber.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text("正在孵化⋯⋯")
                    .selahBodyMedium()
            }
            .padding(.vertical, SelahSpacing.xxl)

            Button(action: {
                appState.preferences.onboardingCompleted = true
            }) {
                Text("開始學習！")
                    .font(.selahHeadlineMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SelahSpacing.md)
                    .background(Color.selahCoral)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.sm))
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SelahSpacing.xl) {
                // Learning preferences
                VStack(alignment: .leading, spacing: SelahSpacing.md) {
                    Text("學習偏好")
                        .font(.selahHeadlineLarge)

                    // Default voice profile
                    VStack(alignment: .leading, spacing: SelahSpacing.sm) {
                        Text("默認聲線")
                            .selahLabelLarge()
                        Text(appState.preferences.voiceProfile.displayName)
                            .selahBodyMedium()
                        Text(appState.preferences.voiceProfile.description)
                            .selahBodySmall()
                    }
                    .padding(SelahSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                            .strokeBorder(Color.selahBorderLight, lineWidth: 1)
                    )

                    // Playback speed
                    VStack(alignment: .leading, spacing: SelahSpacing.sm) {
                        Text("播放速度")
                            .selahLabelLarge()
                        Text(appState.preferences.playbackSpeed.displayName)
                            .selahBodyMedium()
                    }
                    .padding(SelahSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                            .strokeBorder(Color.selahBorderLight, lineWidth: 1)
                    )
                }

                // About
                VStack(alignment: .leading, spacing: SelahSpacing.md) {
                    Text("關於")
                        .font(.selahHeadlineLarge)

                    VStack(alignment: .leading, spacing: SelahSpacing.sm) {
                        Text("Selah v0.1.0 (M1)")
                            .selahBodyMedium()
                        Text("用你說的話，學你需要的英文")
                            .selahBodySmall()
                    }
                    .padding(SelahSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.selahCardPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SelahCornerRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: SelahCornerRadius.lg)
                            .strokeBorder(Color.selahBorderLight, lineWidth: 1)
                    )
                }
            }
            .padding(SelahSpacing.page)
        }
        .background(Color.selahBgPrimary)
        .navigationTitle("設定")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
