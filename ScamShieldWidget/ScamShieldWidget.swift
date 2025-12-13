import WidgetKit
import SwiftUI

// MARK: - Shared Data
struct LastScanResult: Codable {
    let verdict: String // "high_scam", "suspicious", "no_obvious_scam"
    let summary: String
    let timestamp: String // ISO8601 formatted date string

    var date: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ScamShieldEntry {
        ScamShieldEntry(date: Date(), lastScan: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScamShieldEntry) -> ()) {
        let entry = ScamShieldEntry(date: Date(), lastScan: loadLastScan())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = ScamShieldEntry(date: Date(), lastScan: loadLastScan())
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadLastScan() -> LastScanResult? {
        guard let defaults = UserDefaults(suiteName: "group.com.scamshield.shared"),
              let data = defaults.data(forKey: "lastScanResult"),
              let result = try? JSONDecoder().decode(LastScanResult.self, from: data) else {
            return nil
        }
        return result
    }
}

// MARK: - Entry
struct ScamShieldEntry: TimelineEntry {
    let date: Date
    let lastScan: LastScanResult?
}

// MARK: - Widget Colors (Standalone - can't use main app's extensions)
extension Color {
    static let widgetMidnight = Color(red: 4/255, green: 8/255, blue: 18/255)
    static let widgetNavy = Color(red: 21/255, green: 34/255, blue: 56/255)
    static let widgetSunrise = Color(red: 232/255, green: 194/255, blue: 127/255)
    static let widgetEmber = Color(red: 214/255, green: 124/255, blue: 69/255)
    static let widgetCloud = Color(red: 196/255, green: 212/255, blue: 224/255)
    static let widgetDanger = Color(red: 220/255, green: 38/255, blue: 38/255)
    static let widgetWarning = Color(red: 217/255, green: 119/255, blue: 6/255)
    static let widgetSafe = Color(red: 22/255, green: 163/255, blue: 74/255)
}

// MARK: - Lock Screen Widget (accessoryCircular)
struct LockScreenWidgetView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "shield.checkered")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Home Screen Widget (systemSmall)
struct SmallWidgetView: View {
    let entry: ScamShieldEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.widgetMidnight, .widgetNavy],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 8) {
                // Shield icon
                Image(systemName: "shield.checkered")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.widgetSunrise, .widgetEmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Scam Shield")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text("Tap to scan")
                    .font(.system(size: 10))
                    .foregroundColor(.widgetCloud.opacity(0.7))
            }
        }
        .widgetURL(URL(string: "scamshield://scan"))
    }
}

// MARK: - Home Screen Widget (systemMedium)
struct MediumWidgetView: View {
    let entry: ScamShieldEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.widgetMidnight, .widgetNavy],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 16) {
                // Left side - Shield icon
                VStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.widgetSunrise, .widgetEmber],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Scam Shield")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                // Right side - Last scan or prompt
                VStack(alignment: .leading, spacing: 6) {
                    if let lastScan = entry.lastScan {
                        // Show last scan result
                        HStack(spacing: 4) {
                            Circle()
                                .fill(verdictColor(for: lastScan.verdict))
                                .frame(width: 8, height: 8)
                            Text(verdictText(for: lastScan.verdict))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(verdictColor(for: lastScan.verdict))
                        }

                        Text(lastScan.summary)
                            .font(.system(size: 11))
                            .foregroundColor(.widgetCloud)
                            .lineLimit(2)

                        Spacer()

                        Text(timeAgo(from: lastScan.date))
                            .font(.system(size: 10))
                            .foregroundColor(.widgetCloud.opacity(0.6))
                    } else {
                        // No recent scan
                        Text("Stay Protected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Tap to scan a suspicious message")
                            .font(.system(size: 11))
                            .foregroundColor(.widgetCloud.opacity(0.7))
                            .lineLimit(2)

                        Spacer()

                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                            Text("Scan Now")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.widgetSunrise)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .widgetURL(URL(string: "scamshield://scan"))
    }

    private func verdictColor(for verdict: String) -> Color {
        switch verdict {
        case "high_scam": return .widgetDanger
        case "suspicious": return .widgetWarning
        default: return .widgetSafe
        }
    }

    private func verdictText(for verdict: String) -> String {
        switch verdict {
        case "high_scam": return "DANGER"
        case "suspicious": return "SUSPICIOUS"
        default: return "SAFE"
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Widget Configuration
struct ScamShieldWidget: Widget {
    let kind: String = "ScamShieldWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                SmallWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Scam Shield")
        .description("Quick access to scan suspicious messages.")
        .supportedFamilies([.systemSmall])
    }
}

struct ScamShieldMediumWidget: Widget {
    let kind: String = "ScamShieldMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                MediumWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MediumWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Scam Shield")
        .description("View your last scan result and quickly start a new scan.")
        .supportedFamilies([.systemMedium])
    }
}

struct ScamShieldLockScreenWidget: Widget {
    let kind: String = "ScamShieldLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetView()
        }
        .configurationDisplayName("Scam Shield")
        .description("Quick access from your lock screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Widget Bundle
@main
struct ScamShieldWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScamShieldWidget()
        ScamShieldMediumWidget()
        ScamShieldLockScreenWidget()
    }
}

// MARK: - Previews
#Preview("Small Widget", as: .systemSmall) {
    ScamShieldWidget()
} timeline: {
    ScamShieldEntry(date: .now, lastScan: nil)
}

#Preview("Medium Widget - No Scan", as: .systemMedium) {
    ScamShieldMediumWidget()
} timeline: {
    ScamShieldEntry(date: .now, lastScan: nil)
}

#Preview("Medium Widget - With Scan", as: .systemMedium) {
    ScamShieldMediumWidget()
} timeline: {
    ScamShieldEntry(
        date: .now,
        lastScan: LastScanResult(
            verdict: "suspicious",
            summary: "This message contains urgency tactics and requests personal information.",
            timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        )
    )
}

#Preview("Lock Screen", as: .accessoryCircular) {
    ScamShieldLockScreenWidget()
} timeline: {
    ScamShieldEntry(date: .now, lastScan: nil)
}
