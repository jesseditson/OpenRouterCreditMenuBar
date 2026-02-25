import SwiftUI

struct UsageHistogramView: View {
    let modelUsages: [ModelUsage]
    let remainingCredit: Double?

    private var sortedUsages: [ModelUsage] {
        modelUsages.sorted { $0.cost > $1.cost }
    }

    private var maxCost: Double {
        sortedUsages.first?.cost ?? 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let credit = remainingCredit {
                HStack {
                    Image(systemName: "wallet.bifold")
                        .foregroundColor(.green)
                    Text("Remaining Credits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(String(format: "%.4f", credit))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }

            Divider()

            if sortedUsages.isEmpty {
                Text("No usage data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                Text("Token Usage This Cycle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(sortedUsages) { usage in
                    ModelUsageRow(usage: usage, maxCost: maxCost)
                }
            }
        }
    }
}

struct ModelUsageRow: View {
    let usage: ModelUsage
    let maxCost: Double

    private var barFraction: Double {
        maxCost > 0 ? min(usage.cost / maxCost, 1.0) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(usage.shortName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("$\(String(format: "%.4f", usage.cost))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.75))
                        .frame(width: geometry.size.width * barFraction, height: 14)
                    Text("\(formatTokens(usage.tokens))")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(.leading, 4)
                }
            }
            .frame(height: 14)
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM tok", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK tok", Double(tokens) / 1_000)
        } else {
            return "\(tokens) tok"
        }
    }
}

#Preview {
    UsageHistogramView(
        modelUsages: [
            ModelUsage(model: "anthropic/claude-3.5-sonnet", tokens: 150_000, cost: 1.35),
            ModelUsage(model: "openai/gpt-4o", tokens: 80_000, cost: 0.80),
            ModelUsage(model: "google/gemini-pro-1.5", tokens: 200_000, cost: 0.40),
            ModelUsage(model: "meta-llama/llama-3.1-8b-instruct", tokens: 500_000, cost: 0.05),
        ],
        remainingCredit: 97.40
    )
    .padding()
    .frame(width: 280)
}
