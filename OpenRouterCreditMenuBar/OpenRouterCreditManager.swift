//
//  OpenRouterCreditManager.swift
//  OpenRouterCreditMenuBar
//

import Foundation

struct ModelUsage: Identifiable {
    let id = UUID()
    let model: String
    let tokens: Int
    let cost: Double

    var shortName: String {
        model.split(separator: "/").last.map(String.init) ?? model
    }
}

class OpenRouterCreditManager: ObservableObject {
    @Published var currentCredit: Double?
    @Published var totalUsage: Double?
    @Published var modelUsages: [ModelUsage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userDefaults = UserDefaults.standard
    private var refreshTimer: Timer?

    var apiKey: String {
        get {
            userDefaults.string(forKey: "openrouter_api_key") ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: "openrouter_api_key")
        }
    }

    var isEnabled: Bool {
        get {
            userDefaults.bool(forKey: "app_enabled")
        }
        set {
            userDefaults.set(newValue, forKey: "app_enabled")
        }
    }

    var refreshInterval: Double {
        get {
            let interval = userDefaults.double(forKey: "refresh_interval")
            return interval > 0 ? interval : 300  // default 5 minutes
        }
        set {
            userDefaults.set(newValue, forKey: "refresh_interval")
            setupTimer()
        }
    }

    init() {
        setupTimer()
    }

    private func setupTimer() {
        refreshTimer?.invalidate()

        guard isEnabled && !apiKey.isEmpty else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await self.fetchCredit()
            }
        }
    }

    func startMonitoring() {
        setupTimer()
        Task {
            await fetchCredit()
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchCredit() async {
        guard !apiKey.isEmpty && isEnabled else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let credit = try await fetchCreditFromAPI()
            let usages = await fetchModelUsageFromAPI()
            await MainActor.run {
                self.currentCredit = credit.total_credits - credit.total_usage
                self.totalUsage = credit.total_usage
                self.modelUsages = usages
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchCreditFromAPI() async throws -> CreditData {
        guard let url = URL(string: "https://openrouter.ai/api/v1/credits") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw URLError(.badServerResponse)
        }

        let creditResponse = try JSONDecoder().decode(CreditResponse.self, from: data)
        return creditResponse.data
    }

    private func fetchModelUsageFromAPI() async -> [ModelUsage] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/usage") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let usageResponse = try? JSONDecoder().decode(UsageResponse.self, from: data)
        else {
            return []
        }

        return usageResponse.data.map { entry in
            ModelUsage(model: entry.model, tokens: entry.tokens, cost: entry.cost)
        }
    }
}

struct CreditResponse: Codable {
    let data: CreditData
}

struct CreditData: Codable {
    let total_credits: Double
    let total_usage: Double
}

struct UsageResponse: Codable {
    let data: [UsageEntry]
}

struct UsageEntry: Codable {
    let model: String
    let tokens: Int
    let cost: Double
}
