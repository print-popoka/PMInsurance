import Foundation
import Combine

/// One entry in the chatbot cache. A query maps to a verified ChatResponse.
/// Loosely modeled on the MobileGPT memory idea.
struct CachedChatEntry: Sendable {
    let query: String
    let response: ChatResponse
    let timestamp: Date
    var hitCount: Int
}

/// Response cache. Only verified answers go in, so bad answers don't
/// stack up. Repeat questions skip the LLM entirely. A thumbs-down from
/// the user clears the entry and forces a fresh model call next time.
@MainActor
final class ChatMemory: ObservableObject {
    @Published private(set) var entries: [String: CachedChatEntry] = [:]

    func lookup(query: String) -> CachedChatEntry? {
        let key = Self.normalize(query)
        guard var entry = entries[key] else { return nil }
        entry.hitCount += 1
        entries[key] = entry
        return entry
    }

    func remember(query: String, response: ChatResponse) {
        let key = Self.normalize(query)
        entries[key] = CachedChatEntry(
            query: query,
            response: response,
            timestamp: Date(),
            hitCount: 0
        )
    }

    func forget(query: String) {
        let key = Self.normalize(query)
        entries.removeValue(forKey: key)
    }

    func reset() {
        entries.removeAll()
    }

    var totalEntries: Int { entries.count }
    var totalHits: Int { entries.values.reduce(0) { $0 + $1.hitCount } }

    /// Normalize query — trim, lowercase, drop punctuation and double spaces.
    static func normalize(_ q: String) -> String {
        var s = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let strip: [Character] = ["?", "!", ".", ",", "。", "?", "!", "·"]
        s.removeAll { strip.contains($0) }
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s
    }
}
