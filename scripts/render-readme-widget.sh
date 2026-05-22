#!/bin/bash
# Render the medium WidgetKit widget from its SwiftUI source for the README.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/NewFileCreation2Widget/NewFileCreation2Widget.swift"
OUTPUT="${1:-$ROOT/docs/images/new-file-creation-2-widget.png}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/nfc-widget-render.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# The widget extension's @main bundle cannot be linked into a command-line
# renderer. Keep every declaration before it so the renderer uses the real
# widget view instead of a copy.
awk '/^@main/{exit} {print}' "$SOURCE" > "$TMP/WidgetView.swift"

cat > "$TMP/render.swift" <<'SWIFT'
import AppKit
import SwiftUI

@main
struct Renderer {
    @MainActor
    static func main() throws {
        let output = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "new-file-creation-2-widget.png"
        let now = Date()
        let templates = [
            NFWidgetTemplate(id: "text", name: "Text File", fileName: "Text.txt", category: "Text",
                             isFavorite: true, sortIndex: 0, useCount: 4, lastUsed: now),
            NFWidgetTemplate(id: "markdown", name: "Markdown", fileName: "Notes.md", category: "Text",
                             isFavorite: false, sortIndex: 1, useCount: 2, lastUsed: now),
            NFWidgetTemplate(id: "spreadsheet", name: "Spreadsheet", fileName: "Sheet.xlsx",
                             category: "Spreadsheets", isFavorite: false, sortIndex: 2,
                             useCount: 1, lastUsed: now),
            NFWidgetTemplate(id: "folder", name: "Folder", fileName: "Folder", category: "Other",
                             isFavorite: false, sortIndex: 3, useCount: 0, lastUsed: nil),
            NFWidgetTemplate(id: "presentation", name: "Presentation", fileName: "Slides.key",
                             category: "Presentations", isFavorite: false, sortIndex: 4,
                             useCount: 0, lastUsed: nil),
            NFWidgetTemplate(id: "pdf", name: "PDF", fileName: "Document.pdf", category: "Documents",
                             isFavorite: false, sortIndex: 5, useCount: 0, lastUsed: nil),
        ]
        let entry = NFWidgetEntry(date: now, templates: templates)
        let content = NFWidgetView(entry: entry)
            .frame(width: 329, height: 155)
            .background(
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor),
                             Color(nsColor: .controlBackgroundColor)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 4
        guard let cgImage = renderer.cgImage else {
            throw NSError(domain: "render", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not render the widget"])
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "render", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not encode the widget PNG"])
        }
        try data.write(to: URL(fileURLWithPath: output))
    }
}
SWIFT

mkdir -p "$(dirname "$OUTPUT")"
ARCH="$(uname -m)"
xcrun swiftc -parse-as-library -swift-version 5 \
    -target "${ARCH}-apple-macos14.0" \
    -framework SwiftUI -framework AppKit -framework WidgetKit \
    -o "$TMP/render" "$TMP/WidgetView.swift" "$TMP/render.swift"
"$TMP/render" "$OUTPUT"
echo "Wrote $OUTPUT"
