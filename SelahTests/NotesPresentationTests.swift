import XCTest
@testable import Selah

final class NotesPresentationTests: XCTestCase {
    func testSummaryExcludesArchivedAndCountsMasteredSentences() {
        let newSentence = Sentence(sourceText: "新句", targetText: "New")
        newSentence.reviewState = ReviewState(sentenceID: newSentence.id, state: .new)

        let mastered = Sentence(sourceText: "熟悉", targetText: "Familiar")
        mastered.reviewState = ReviewState(sentenceID: mastered.id, state: .familiar)

        let archived = Sentence(sourceText: "封存", targetText: "Archived", archived: true)
        archived.reviewState = ReviewState(sentenceID: archived.id, state: .quiet)

        let summary = NotesPresentation.summary(
            sentences: [newSentence, mastered, archived]
        )

        XCTAssertEqual(summary.total, 2)
        XCTAssertEqual(summary.mastered, 1)
    }

    func testCategoryFilterExcludesArchivedSentences() {
        let work = Sentence(sourceText: "工作", targetText: "Work", category: .work)
        let friend = Sentence(sourceText: "朋友", targetText: "Friend", category: .friends)
        let archivedWork = Sentence(
            sourceText: "舊工作",
            targetText: "Old work",
            category: .work,
            archived: true
        )

        XCTAssertEqual(
            NotesPresentation.visibleSentences(
                [work, friend, archivedWork],
                category: .work
            ).map(\.id),
            [work.id]
        )
    }

    func testOnlyUnlockedMemoriesAreVisible() {
        let companionID = UUID()
        let locked = SpriteMemory(
            companionID: companionID,
            memoryKey: "locked",
            title: "未解鎖",
            descriptionText: "",
            icon: "🔒"
        )
        let unlocked = SpriteMemory(
            companionID: companionID,
            memoryKey: "unlocked",
            title: "已解鎖",
            descriptionText: "",
            icon: "🌱"
        )
        unlocked.unlock()

        XCTAssertEqual(
            NotesPresentation.visibleMemories([locked, unlocked]).map(\.id),
            [unlocked.id]
        )
    }
}
