# Selah

iOS-native minimal language learning app. Turn your real-life Chinese sentences into natural English you can hear, understand, recall, and eventually say.

## Current Status

**M0 — Native Prototype Shell (in progress)**

Design frozen (v8). Swift source code written. Ready for Xcode compilation on a Mac.

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Persistence**: SwiftData
- **Speech Recognition**: SFSpeechRecognizer (iOS native)
- **Backend**: TBD (Supabase Edge Functions / Cloudflare Workers)
- **Translation**: LLM Provider TBD
- **TTS**: Provider TBD

## Project Structure

```
Selah/
├── SelahApp.swift              # App entry point
├── Models/                     # SwiftData models (9 entities)
│   ├── SelahTypes.swift        # All enums and type definitions
│   ├── Sentence.swift          # Core learning unit
│   ├── VocabItem.swift         # Vocabulary byproduct
│   ├── ReviewState.swift       # Internal review scheduling
│   ├── AudioAsset.swift        # Audio cache tracking
│   ├── GenerationJob.swift     # Retry queue entries
│   ├── Companion.swift         # Sprite companion
│   ├── SpriteMemory.swift      # Learning milestones
│   ├── UserPreference.swift    # Settings
│   └── LearningEvent.swift     # Append-only event log
├── DesignTokens/               # Visual design system
│   ├── Colors.swift
│   ├── Fonts.swift
│   └── SpacingAndShadows.swift
├── Core/
│   ├── Protocols/              # Service and repository interfaces
│   │   ├── SentenceGenerationService.swift
│   │   ├── AudioGenerationService.swift
│   │   ├── SpeechRecognitionService.swift
│   │   ├── AudioPlaybackService.swift
│   │   ├── RecommendationEngine.swift
│   │   ├── ReviewScheduler.swift
│   │   ├── GenerationRetryQueue.swift
│   │   ├── CompanionRepository.swift
│   │   └── RepositoryProtocols.swift
│   ├── Services/Mock/          # Mock implementations for prototyping
│   │   ├── MockSentenceGenerationService.swift
│   │   ├── MockAudioGenerationService.swift
│   │   └── MockSpeechRecognitionService.swift
│   ├── RecommendationEngineImpl.swift
│   ├── ReviewSchedulerImpl.swift
│   ├── GenerationRetryQueueImpl.swift
│   ├── VocabularyHelpUseCaseImpl.swift
│   └── SpriteMemoryPresets.swift
├── Components/                 # Reusable UI components
│   ├── iOSRow.swift            # List row + Badge + CatChip
│   ├── PetView.swift           # Sprite display with animations
│   ├── QuizCard.swift          # Flip card + assessment buttons
│   └── CoachHint.swift         # Coach hints + progress bar + stage bar + toast
└── Features/
    └── TodayView.swift         # All screens: Today, Listen, Practice,
                                  NightPreview, TodaySentence, Notes, Onboarding

SeedContent/
├── seed-sentences.json         # 20 seed sentences with full learning data
└── llm-translation-prompt-v8.md  # LLM system prompt for translation
```

## Getting Started

1. Open Xcode 15.4+ on macOS 14+
2. Create a new iOS project named "Selah" with SwiftUI, targeting iOS 17+
3. Add the source files from this repository into the project
4. Add "Plus Jakarta Sans" font to the project (or replace with system font)
5. Build and run on simulator or device

## Design Documents

- `archive/selah-v8-unified-design-spec.md` — Product design source of truth
- `archive/selah-v8-ios-architecture.md` — iOS architecture design
- `selah-ios-design-spec.md` — Design tokens and component library
- `ROADMAP.md` — Development roadmap

## License

Private — all rights reserved.
