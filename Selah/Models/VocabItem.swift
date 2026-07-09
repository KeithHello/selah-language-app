import Foundation
import SwiftData

/// Vocabulary item — always tied to a source sentence.
/// Internal state machine: new → learning → familiar → owned.
/// User-facing display collapses to two groups: "仍在關注" / "已比較熟".
@Model
final class VocabItem {
    @Attribute(.unique) var id: UUID

    var sentenceID: UUID
    var surfaceText: String        // English word/phrase
    var meaningInContext: String   // Meaning in this sentence's context
    var helpStateRaw: String       // VocabHelpState raw value
    var manuallyAdded: Bool
    var successCount: Int
    var failureCount: Int
    var activeHelpVisible: Bool
    var lastSeenAt: Date?
    var lastUsedAt: Date?          // set when user naturally uses this word in a new sentence
    var createdAt: Date

    // MARK: - Convenience

    var helpState: VocabHelpState {
        get { VocabHelpState(rawValue: helpStateRaw) ?? .new }
        set { helpStateRaw = newValue.rawValue }
    }

    /// User-facing display group.
    var userFacingGroup: String {
        helpState.userFacingGroup
    }

    /// Status hint text for Notes display.
    var statusHint: String {
        switch helpState {
        case .new:       return "句子拆解中"
        case .learning:  return "下一次還想再看"
        case .familiar:  return "不再主動拆解"
        case .owned:     return "你已經用出來過"
        }
    }

    var isOwned: Bool { helpState == .owned }

    init(
        id: UUID = UUID(),
        sentenceID: UUID,
        surfaceText: String,
        meaningInContext: String,
        helpState: VocabHelpState = .new,
        manuallyAdded: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sentenceID = sentenceID
        self.surfaceText = surfaceText
        self.meaningInContext = meaningInContext
        self.helpStateRaw = helpState.rawValue
        self.manuallyAdded = manuallyAdded
        self.successCount = 0
        self.failureCount = 0
        self.activeHelpVisible = helpState == .new || helpState == .learning
        self.createdAt = createdAt
    }

    /// Called when the word is encountered and the user seems comfortable.
    func markEncounter(success: Bool) {
        lastSeenAt = Date()
        if success {
            successCount += 1
            // Transition to familiar when user shows comfort
            if helpState == .learning && successCount >= 2 {
                helpState = .familiar
                activeHelpVisible = false
            }
        } else {
            failureCount += 1
            // Fall back to learning if familiar word causes trouble
            if helpState == .familiar || helpState == .owned {
                if failureCount >= 2 {
                    helpState = .learning
                    activeHelpVisible = true
                    failureCount = 0
                }
            }
        }
    }

    /// Called when user naturally uses this word in a new sentence.
    func markUsed() {
        lastUsedAt = Date()
        helpState = .owned
        activeHelpVisible = false
    }

    /// User manually re-adds to active focus.
    func reAddToFocus() {
        helpState = .learning
        activeHelpVisible = true
        failureCount = 0
    }
}
