import AppKit
import Darwin
import Foundation
import SwiftUI
import WidgetKit

private let nfcURLScheme = "newfilecreation2"
private let nfcSupportFolder = "New File Creation 2"
private let nfcWidgetKind = "NewFileTemplateWidget"

// MARK: - Configuration

private enum NFWidgetHome {
    /// Sandboxed extensions see their container as the home directory, so ask
    /// the password database for the real account home instead.
    static var directory: URL {
        if let entry = getpwuid(getuid()), let path = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: path), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var configURL: URL {
        directory
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(nfcSupportFolder, isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }
}

private struct NFStoredSettings: Decodable {
    let favoritesFirst: Bool?
    let sortMode: String?
}

private struct NFStoredTemplate: Decodable {
    let id: String
    let fileName: String
    let displayName: String?
    let category: String?
    let enabled: Bool?
    let favorite: Bool?
    let sortIndex: Int?
    let useCount: Int?
    let lastUsedAt: String?
}

private struct NFStoredConfig: Decodable {
    let settings: NFStoredSettings?
    let templates: [NFStoredTemplate]?
}

// MARK: - Model

struct NFWidgetTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let fileName: String
    let category: String
    let isFavorite: Bool
    let sortIndex: Int
    let useCount: Int
    let lastUsed: Date?

    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    var createURL: URL? {
        var components = URLComponents()
        components.scheme = nfcURLScheme
        components.host = "create"
        components.queryItems = [
            URLQueryItem(name: "template", value: id),
            URLQueryItem(name: "unique", value: "1"),
        ]
        return components.url
    }

    var symbolName: String {
        switch fileExtension {
        case "pdf":
            return "doc.richtext"
        case "xls", "xlsx", "csv", "numbers", "tsv":
            return "tablecells"
        case "ppt", "pptx", "key":
            return "rectangle.on.rectangle"
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tif", "tiff", "bmp", "psd", "svg":
            return "photo"
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return "film"
        case "mp3", "wav", "aiff", "aif", "m4a", "flac", "ogg":
            return "waveform"
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return "archivebox"
        case "swift", "m", "mm", "h", "c", "cc", "cpp", "hpp", "py", "js", "ts",
             "jsx", "tsx", "html", "css", "scss", "json", "xml", "yml", "yaml", "sh", "rb", "go", "rs":
            return "chevron.left.forwardslash.chevron.right"
        case "app":
            return "app"
        case "sketch", "fig", "xd":
            return "square.on.circle"
        default:
            return "doc.text"
        }
    }

    var tint: Color {
        switch fileExtension {
        case "pdf":
            return .red
        case "xls", "xlsx", "csv", "numbers", "tsv":
            return .green
        case "ppt", "pptx", "key":
            return .orange
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tif", "tiff", "bmp", "psd", "svg":
            return .purple
        case "mov", "mp4", "m4v", "avi", "mkv", "webm", "mp3", "wav", "aiff", "aif", "m4a", "flac", "ogg":
            return .pink
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz":
            return .brown
        case "swift", "m", "mm", "h", "c", "cc", "cpp", "hpp", "py", "js", "ts",
             "jsx", "tsx", "html", "css", "scss", "json", "xml", "yml", "yaml", "sh", "rb", "go", "rs":
            return .teal
        default:
            return .accentColor
        }
    }
}

private enum NFWidgetSortMode: String {
    case manual
    case name
    case category
    case fileType
    case lastUsed
    case mostUsed

    init(rawValue: String?) {
        self = NFWidgetSortMode(rawValue: rawValue ?? "") ?? .manual
    }
}

private struct NFWidgetConfiguration {
    let templates: [NFWidgetTemplate]
    let favoritesFirst: Bool
    let sortMode: NFWidgetSortMode

    static func load() -> NFWidgetConfiguration {
        guard let data = try? Data(contentsOf: NFWidgetHome.configURL),
              let stored = try? JSONDecoder().decode(NFStoredConfig.self, from: data) else {
            return NFWidgetConfiguration(templates: [], favoritesFirst: true, sortMode: .manual)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let templates = (stored.templates ?? []).compactMap { raw -> NFWidgetTemplate? in
            guard raw.enabled ?? true, !raw.fileName.isEmpty else {
                return nil
            }
            let trimmedName = raw.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = trimmedName.isEmpty ? raw.fileName : trimmedName
            let category = raw.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return NFWidgetTemplate(
                id: raw.id,
                name: name,
                fileName: raw.fileName,
                category: category,
                isFavorite: raw.favorite ?? false,
                sortIndex: raw.sortIndex ?? 0,
                useCount: raw.useCount ?? 0,
                lastUsed: raw.lastUsedAt.flatMap { formatter.date(from: $0) }
            )
        }

        let favoritesFirst = stored.settings?.favoritesFirst ?? true
        let sortMode = NFWidgetSortMode(rawValue: stored.settings?.sortMode)
        let sorted = templates.sorted { lhs, rhs in
            if favoritesFirst, lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
            switch sortMode {
            case .manual:
                if lhs.sortIndex != rhs.sortIndex {
                    return lhs.sortIndex < rhs.sortIndex
                }
            case .name:
                break
            case .category:
                let result = lhs.category.localizedCaseInsensitiveCompare(rhs.category)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
            case .fileType:
                let result = lhs.fileExtension.localizedCaseInsensitiveCompare(rhs.fileExtension)
                if result != .orderedSame {
                    return result == .orderedAscending
                }
            case .lastUsed:
                let left = lhs.lastUsed ?? .distantPast
                let right = rhs.lastUsed ?? .distantPast
                if left != right {
                    return left > right
                }
            case .mostUsed:
                if lhs.useCount != rhs.useCount {
                    return lhs.useCount > rhs.useCount
                }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return NFWidgetConfiguration(templates: sorted, favoritesFirst: favoritesFirst, sortMode: sortMode)
    }
}

// MARK: - Timeline

struct NFWidgetEntry: TimelineEntry {
    let date: Date
    let templates: [NFWidgetTemplate]
}

private struct NFWidgetProvider: TimelineProvider {
    private static let sample = [
        NFWidgetTemplate(id: "text", name: "Text File", fileName: "Text.txt", category: "Text",
                         isFavorite: true, sortIndex: 0, useCount: 4, lastUsed: Date()),
        NFWidgetTemplate(id: "markdown", name: "Markdown", fileName: "Notes.md", category: "Text",
                         isFavorite: false, sortIndex: 1, useCount: 2, lastUsed: Date()),
        NFWidgetTemplate(id: "spreadsheet", name: "Spreadsheet", fileName: "Sheet.xlsx", category: "Spreadsheets",
                         isFavorite: false, sortIndex: 2, useCount: 1, lastUsed: Date()),
        NFWidgetTemplate(id: "folder", name: "Folder", fileName: "Folder", category: "Other",
                         isFavorite: false, sortIndex: 3, useCount: 0, lastUsed: nil),
        NFWidgetTemplate(id: "presentation", name: "Presentation", fileName: "Slides.key", category: "Presentations",
                         isFavorite: false, sortIndex: 4, useCount: 0, lastUsed: nil),
        NFWidgetTemplate(id: "pdf", name: "PDF", fileName: "Document.pdf", category: "Documents",
                         isFavorite: false, sortIndex: 5, useCount: 0, lastUsed: nil),
    ]

    func placeholder(in context: Context) -> NFWidgetEntry {
        NFWidgetEntry(date: Date(), templates: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NFWidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(NFWidgetEntry(date: Date(), templates: NFWidgetConfiguration.load().templates))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NFWidgetEntry>) -> Void) {
        let entry = NFWidgetEntry(date: Date(), templates: NFWidgetConfiguration.load().templates)
        let next = Date().addingTimeInterval(5 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

private struct NFWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    @ViewBuilder
    func nfcWidgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(for: .widget) {
                NFWidgetBackground()
            }
        } else {
            background(NFWidgetBackground())
        }
    }
}

struct NFWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NFWidgetEntry

    private var columnCount: Int {
        switch family {
        case .systemSmall:
            return 1
        case .systemLarge:
            return 3
        default:
            return 2
        }
    }

    private var rowCount: Int {
        family == .systemSmall || family == .systemLarge ? 4 : 3
    }

    private var capacity: Int {
        columnCount * rowCount
    }

    private var visibleTemplates: [NFWidgetTemplate] {
        Array(entry.templates.prefix(capacity))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if visibleTemplates.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount),
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(visibleTemplates) { template in
                        templateLink(template)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .nfcWidgetBackground()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("New File")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let quickURL = URL(string: "\(nfcURLScheme)://quick") {
                Link(destination: quickURL) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Quick New File…"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.secondary)
            Text("New File Creation 2")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            if let settingsURL = URL(string: "\(nfcURLScheme)://settings") {
                Link(destination: settingsURL) {
                    Text("Open Settings")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func templateLink(_ template: NFWidgetTemplate) -> some View {
        if let url = template.createURL {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: template.symbolName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(template.tint)
                        .frame(width: 15)
                    Text(template.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(template.name))
        }
    }
}

// MARK: - Widget

struct NewFileTemplateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: nfcWidgetKind, provider: NFWidgetProvider()) { entry in
            NFWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("New File"))
        .description(Text("New File Creation 2 keeps your reusable templates in one place and creates a fresh copy wherever you are working. Everything runs locally on your Mac."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct NewFileCreation2WidgetBundle: WidgetBundle {
    var body: some Widget {
        NewFileTemplateWidget()
    }
}
