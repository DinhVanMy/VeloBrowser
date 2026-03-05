// SearchSuggestionService.swift
// VeloBrowser
//
// Fetches autocomplete suggestions from search engines.

import Foundation

/// Provides search autocomplete suggestions from Google or DuckDuckGo.
@Observable
@MainActor
final class SearchSuggestionService {
    /// Current suggestions for the query.
    private(set) var suggestions: [String] = []

    /// Whether suggestions are loading.
    private(set) var isLoading: Bool = false

    /// Active fetch task (cancelled on new query).
    private var fetchTask: Task<Void, Never>?

    /// Minimum query length before fetching.
    private static let minQueryLength = 2

    /// Debounce interval in nanoseconds.
    private static let debounceNanos: UInt64 = 250_000_000

    /// Fetches suggestions for the given query, debounced.
    func fetchSuggestions(for query: String, engine: String = "Google") {
        fetchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minQueryLength else {
            suggestions = []
            isLoading = false
            return
        }

        isLoading = true
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: Self.debounceNanos)
            guard !Task.isCancelled else { return }

            let results = await performFetch(query: trimmed, engine: engine)
            guard !Task.isCancelled else { return }

            suggestions = results
            isLoading = false
        }
    }

    /// Clears suggestions and cancels pending fetches.
    func clear() {
        fetchTask?.cancel()
        suggestions = []
        isLoading = false
    }

    // MARK: - Private

    private func performFetch(query: String, engine: String) async -> [String] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let urlString: String
        switch engine {
        case "DuckDuckGo":
            urlString = "https://duckduckgo.com/ac/?q=\(encoded)&type=list"
        case "Bing":
            urlString = "https://api.bing.com/osjson.aspx?query=\(encoded)"
        default:
            urlString = "https://suggestqueries.google.com/complete/search?client=firefox&q=\(encoded)"
        }

        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            // Response format: ["query", ["suggestion1", "suggestion2", ...]]
            if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
               json.count >= 2,
               let results = json[1] as? [String] {
                // DuckDuckGo returns [{phrase: "..."}] format sometimes
                return Array(results.prefix(6))
            }

            // DuckDuckGo /ac/ returns [{phrase: "..."}]
            if let json = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                return Array(json.compactMap { $0["phrase"] }.prefix(6))
            }

            return []
        } catch {
            return []
        }
    }
}
