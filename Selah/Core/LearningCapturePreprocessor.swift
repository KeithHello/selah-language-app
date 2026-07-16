import Foundation

struct CaptureSegmentSuggestion: Codable, Identifiable, Equatable {
    let id: UUID
    let orderIndex: Int
    let originalText: String
    var sourceText: String
    let removedText: [String]
    var selected: Bool

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        originalText: String,
        sourceText: String,
        removedText: [String] = [],
        selected: Bool = true
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.originalText = originalText
        self.sourceText = sourceText
        self.removedText = removedText
        self.selected = selected
    }
}

struct CapturePreparation: Codable, Equatable {
    let rawTranscript: String
    let normalizedTranscript: String
    let segments: [CaptureSegmentSuggestion]
    let preparationVersion: String
}

struct LearningCapturePreprocessor {
    static let defaultMaxSelectedSegments = 5

    func prepare(
        transcript: String,
        maxSelectedSegments: Int = Self.defaultMaxSelectedSegments
    ) -> CapturePreparation {
        let normalized = normalize(transcript)
        let chunks = splitIntoChunks(normalized)
        let suggestions = chunks.enumerated().map { index, chunk in
            let cleaned = clean(chunk)
            return CaptureSegmentSuggestion(
                orderIndex: index,
                originalText: chunk,
                sourceText: cleaned.text,
                removedText: cleaned.removed,
                selected: index < maxSelectedSegments
            )
        }
        return CapturePreparation(
            rawTranscript: transcript,
            normalizedTranscript: normalized,
            segments: suggestions,
            preparationVersion: "local-v1"
        )
    }

    func normalize(_ transcript: String) -> String {
        transcript
            .split { $0.isWhitespace }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitIntoChunks(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if "。！？!?；;\n".contains(character) {
                let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { chunks.append(value) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { chunks.append(tail) }
        return chunks.isEmpty && !text.isEmpty ? [text] : chunks
    }

    private func clean(_ chunk: String) -> (text: String, removed: [String]) {
        var value = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        var removed: [String] = []
        let leadingFillers = ["呃呃", "嗯嗯", "呃", "嗯"]
        for filler in leadingFillers where value.hasPrefix(filler) {
            value.removeFirst(filler.count)
            removed.append(filler)
            break
        }
        while let first = value.first, "，,、".contains(first) {
            value.removeFirst()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value, removed)
    }
}
