import AppKit

final class MarkdownHighlighter {
    // Fonts
    private let bodyFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private let h1Font = NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
    private let h2Font = NSFont.monospacedSystemFont(ofSize: 17, weight: .bold)
    private let h3Font = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
    private let h4Font = NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
    private let boldFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
    private let italicFont: NSFont = {
        let desc = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            .fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }()
    private let boldItalicFont: NSFont = {
        let desc = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            .fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
    }()
    private let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    // Colors
    private let h1Color = NSColor.systemBlue
    private let h2Color = NSColor.systemIndigo
    private let h3Color = NSColor.systemPurple
    private let h4Color = NSColor.systemPink
    private let boldColor = NSColor.systemOrange
    private let italicColor = NSColor.systemTeal
    private let codeColor = NSColor.systemGreen
    private let linkColor = NSColor.systemBlue
    private let linkURLColor = NSColor.systemCyan
    private let blockquoteColor = NSColor.systemMint
    private let listMarkerColor = NSColor.systemOrange
    private let hrColor = NSColor.tertiaryLabelColor
    private let imageColor = NSColor.systemPink
    private let strikethroughColor = NSColor.secondaryLabelColor

    func highlight(_ textStorage: NSTextStorage) {
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: (string as NSString).length)

        textStorage.beginEditing()

        // Reset to default
        textStorage.addAttributes([
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .strikethroughStyle: 0
        ], range: fullRange)

        // --- Line-based highlighting ---
        let lines = string.components(separatedBy: "\n")
        var location = 0
        var inFencedCodeBlock = false

        for line in lines {
            let lineRange = NSRange(location: location, length: (line as NSString).length)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks
            if trimmed.hasPrefix("```") {
                textStorage.addAttributes([
                    .foregroundColor: codeColor,
                    .font: codeFont
                ], range: lineRange)
                inFencedCodeBlock.toggle()
                location += (line as NSString).length + 1
                continue
            }

            if inFencedCodeBlock {
                textStorage.addAttributes([
                    .foregroundColor: codeColor,
                    .font: codeFont
                ], range: lineRange)
                location += (line as NSString).length + 1
                continue
            }

            // Headings
            if line.hasPrefix("# ") {
                textStorage.addAttributes([.font: h1Font, .foregroundColor: h1Color], range: lineRange)
            } else if line.hasPrefix("## ") {
                textStorage.addAttributes([.font: h2Font, .foregroundColor: h2Color], range: lineRange)
            } else if line.hasPrefix("### ") {
                textStorage.addAttributes([.font: h3Font, .foregroundColor: h3Color], range: lineRange)
            } else if line.hasPrefix("#### ") || line.hasPrefix("##### ") || line.hasPrefix("###### ") {
                textStorage.addAttributes([.font: h4Font, .foregroundColor: h4Color], range: lineRange)
            }
            // Blockquotes
            else if trimmed.hasPrefix(">") {
                textStorage.addAttributes([.foregroundColor: blockquoteColor], range: lineRange)
            }
            // Horizontal rules
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" ||
                        trimmed.allSatisfy({ $0 == "-" || $0 == " " }) && trimmed.filter({ $0 == "-" }).count >= 3 ||
                        trimmed.allSatisfy({ $0 == "*" || $0 == " " }) && trimmed.filter({ $0 == "*" }).count >= 3 {
                textStorage.addAttributes([.foregroundColor: hrColor], range: lineRange)
            }
            // List markers (-, *, +, 1., 2., etc.)
            else if let markerRange = listMarkerRange(line: line, lineStart: location) {
                textStorage.addAttribute(.foregroundColor, value: listMarkerColor, range: markerRange)
            }

            location += (line as NSString).length + 1
        }

        // --- Inline highlighting (skip if inside code blocks handled above) ---

        // Bold+italic ***...*** or ___...___
        highlightPattern("(\\*\\*\\*|___)(.+?)(\\1)", in: textStorage, fullRange: fullRange, attributes: [
            .font: boldItalicFont,
            .foregroundColor: boldColor
        ])

        // Bold **...** or __...__
        highlightPattern("(\\*\\*|__)(.+?)(\\1)", in: textStorage, fullRange: fullRange, attributes: [
            .font: boldFont,
            .foregroundColor: boldColor
        ])

        // Italic *...* or _..._  (single delimiter, not preceded/followed by same)
        highlightPattern("(?<![\\*_])(\\*|_)(?![\\*_\\s])(.+?)(?<![\\*_\\s])\\1(?![\\*_])", in: textStorage, fullRange: fullRange, attributes: [
            .font: italicFont,
            .foregroundColor: italicColor
        ])

        // Strikethrough ~~...~~
        highlightPattern("~~(.+?)~~", in: textStorage, fullRange: fullRange, attributes: [
            .foregroundColor: strikethroughColor,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ])

        // Inline code `...` (after bold/italic so it overrides)
        highlightPattern("`[^`]+`", in: textStorage, fullRange: fullRange, attributes: [
            .foregroundColor: codeColor,
            .font: codeFont
        ])

        // Images ![alt](url) — before links so the ! prefix gets colored
        highlightPattern("!\\[([^\\]]*)\\]\\([^)]+\\)", in: textStorage, fullRange: fullRange, attributes: [
            .foregroundColor: imageColor
        ])

        // Links [text](url) — color the whole thing, then dim the URL part
        highlightPattern("(?<!!)\\[([^\\]]+)\\]\\([^)]+\\)", in: textStorage, fullRange: fullRange, attributes: [
            .foregroundColor: linkColor
        ])
        // Dim just the URL portion (url)
        highlightPattern("(?<=\\])\\([^)]+\\)", in: textStorage, fullRange: fullRange, attributes: [
            .foregroundColor: linkURLColor
        ])

        textStorage.endEditing()
    }

    /// Returns the NSRange of a list marker (e.g. "- ", "* ", "1. ") at the start of a line
    private func listMarkerRange(line: String, lineStart: Int) -> NSRange? {
        let nsLine = line as NSString
        // Unordered: optional whitespace then -, *, or + followed by space
        if let regex = try? NSRegularExpression(pattern: "^(\\s*[-*+]\\s)"),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            return NSRange(location: lineStart + match.range.location, length: match.range.length)
        }
        // Ordered: optional whitespace then digits then . or ) followed by space
        if let regex = try? NSRegularExpression(pattern: "^(\\s*\\d+[.)]\\s)"),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            return NSRange(location: lineStart + match.range.location, length: match.range.length)
        }
        // Task list: optional whitespace then - [ ] or - [x]
        if let regex = try? NSRegularExpression(pattern: "^(\\s*-\\s\\[[ xX]\\]\\s)"),
           let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
            return NSRange(location: lineStart + match.range.location, length: match.range.length)
        }
        return nil
    }

    private func highlightPattern(
        _ pattern: String,
        in textStorage: NSTextStorage,
        fullRange: NSRange,
        attributes: [NSAttributedString.Key: Any],
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        regex.enumerateMatches(in: textStorage.string, options: [], range: fullRange) { match, _, _ in
            if let range = match?.range {
                textStorage.addAttributes(attributes, range: range)
            }
        }
    }
}
