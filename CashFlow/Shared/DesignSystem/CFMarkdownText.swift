import SwiftUI

/// Lightweight Markdown renderer for short AI summaries.
/// Supports headings (#, ##, ###, ####), bullet lines (`* `, `- `),
/// numbered lists (`1. `, `2. `), and inline bold/italic/links.
/// Fenced code blocks and tables fall back to plain paragraphs.
struct CFMarkdownText: View {
    let text: String
    var paragraphSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: paragraphSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Block {
        enum Kind {
            case paragraph
            case bullet
            case numbered(String)
            case heading(Int)
        }
        let kind: Kind
        let content: String
    }

    private var blocks: [Block] {
        text.components(separatedBy: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }

            if let heading = parseHeading(line) {
                return heading
            }
            if line.hasPrefix("* ") {
                return Block(kind: .bullet, content: String(line.dropFirst(2)))
            }
            if line.hasPrefix("- ") {
                return Block(kind: .bullet, content: String(line.dropFirst(2)))
            }
            if let numbered = parseNumbered(line) {
                return numbered
            }
            return Block(kind: .paragraph, content: line)
        }
    }

    private func parseHeading(_ line: String) -> Block? {
        var level = 0
        var iterator = line.startIndex
        while iterator < line.endIndex, line[iterator] == "#", level < 6 {
            level += 1
            iterator = line.index(after: iterator)
        }
        guard level > 0, iterator < line.endIndex, line[iterator] == " " else { return nil }
        let content = String(line[line.index(after: iterator)...]).trimmingCharacters(in: .whitespaces)
        return Block(kind: .heading(level), content: content)
    }

    private func parseNumbered(_ line: String) -> Block? {
        var digits = ""
        var iterator = line.startIndex
        while iterator < line.endIndex, line[iterator].isNumber {
            digits.append(line[iterator])
            iterator = line.index(after: iterator)
        }
        guard !digits.isEmpty,
              iterator < line.endIndex,
              line[iterator] == ".",
              line.index(after: iterator) < line.endIndex,
              line[line.index(after: iterator)] == " "
        else { return nil }
        let content = String(line[line.index(iterator, offsetBy: 2)...])
        return Block(kind: .numbered(digits), content: content)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block.kind {
        case .paragraph:
            Text(inlineMarkdown(block.content))
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.accent)
                Text(inlineMarkdown(block.content))
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .numbered(let label):
            HStack(alignment: .top, spacing: 8) {
                Text("\(label).")
                    .font(CFTheme.body().weight(.semibold))
                    .foregroundStyle(CFTheme.accent)
                    .monospacedDigit()
                Text(inlineMarkdown(block.content))
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .heading(let level):
            Text(inlineMarkdown(block.content))
                .font(headingFont(level))
                .foregroundStyle(CFTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, level <= 2 ? 4 : 0)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 22, weight: .bold)
        case 2: return .system(size: 19, weight: .semibold)
        case 3: return .system(size: 17, weight: .semibold)
        default: return .system(size: 15, weight: .semibold)
        }
    }

    private func inlineMarkdown(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}

extension String {
    /// Strips block-level markers (headings, bullet/numbered prefixes) and inline
    /// `**`/`__` markers. Used by `CFTypewriter` to animate clean text before
    /// swapping to the fully rendered Markdown.
    func cfStrippingMarkdown() -> String {
        let withoutInline = self
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")

        return withoutInline
            .components(separatedBy: "\n")
            .map { line -> String in
                let leading = line.prefix { $0 == " " || $0 == "\t" }
                let rest = line.dropFirst(leading.count)

                // Headings: drop the leading `#`s and following space.
                if rest.first == "#" {
                    var iterator = rest.startIndex
                    var hashes = 0
                    while iterator < rest.endIndex, rest[iterator] == "#", hashes < 6 {
                        hashes += 1
                        iterator = rest.index(after: iterator)
                    }
                    if iterator < rest.endIndex, rest[iterator] == " " {
                        return String(leading) + String(rest[rest.index(after: iterator)...])
                    }
                }

                // Bullets: `* foo`, `- foo` → `• foo`.
                if rest.hasPrefix("* ") || rest.hasPrefix("- ") {
                    return String(leading) + "• " + String(rest.dropFirst(2))
                }

                // Numbered: `1. foo` → keep as is (already readable).
                return line
            }
            .joined(separator: "\n")
    }
}
