# Selah

iOS-native minimal language learning app. Turn your real-life Chinese sentences into natural English you can hear, understand, recall, and eventually say.

## Current Status

**Core package implemented; product integration in progress**

The repository currently builds as a macOS Swift Package and contains the SwiftUI,
SwiftData, Supabase, learning-engine, audio, and reliability core. It is not yet a
runnable iOS application because the Xcode iOS target and several real service/data
flows are still being integrated. See `ROADMAP.md` for the evidence-based status.

## Tech Stack

- **Frontend**: SwiftUI (iOS 17+)
- **Persistence**: SwiftData
- **Speech Recognition**: SFSpeechRecognizer (iOS native)
- **Backend**: Supabase Edge Functions + Postgres/RLS
- **Translation**: OpenAI through server-side Edge Functions
- **TTS**: OpenAI TTS through server-side Edge Functions

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
├── seed-sentences.json         # 30 seed sentences with full learning data
└── llm-translation-prompt-v8.md  # LLM system prompt for translation
```

## Getting Started

The current verified build is the Swift Package core:

```bash
swift package resolve
swift build
swift test
```

The runnable iOS target is tracked as active work in `ROADMAP.md`; do not treat the
package build as an iOS simulator or TestFlight build.

## Design Documents

- `archive/selah-v8-unified-design-spec.md` — Product design source of truth
- `archive/selah-v8-ios-architecture.md` — iOS architecture design
- `selah-ios-design-spec.md` — Design tokens and component library
- `ROADMAP.md` — Development roadmap

## License

Private — all rights reserved.
