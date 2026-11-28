import Foundation

/// The popup's page: one self-contained HTML document with the headword (furigana), frequency badges and one section per
/// dictionary, in the order the engine returned them. It loads nothing: the CSP allows inline styles only.
nonisolated enum LookupPage {
    /// Theme colours as `#RRGGBB`, already resolved for light or dark.
    struct Palette: Equatable {
        let ink: String
        let inkSoft: String
        let accent: String
        let shell: String
    }

    static func html(_ result: LookupResult, palette: Palette) -> String {
        let head = [
            "<!doctype html><html><head><meta charset='utf-8'>",
            "<meta name='viewport' content='width=device-width, initial-scale=1'>",
            "<meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'\">",
            "<style>\(css(palette))</style></head><body>",
        ]
        return head.joined() + result.entries.map(entryHTML).joined() + "</body></html>"
    }

    /// What VoiceOver and the UI tests read from the popup: the top entry's "expression reading".
    static func summary(_ result: LookupResult) -> String? {
        result.entries.first.map { $0.reading.isEmpty || $0.reading == $0.expression ? $0.expression : "\($0.expression) \($0.reading)" }
    }

    /// The expression with its reading as furigana. Kana both words share at the start and end stay outside the ruby.
    static func headword(_ expression: String, reading: String) -> String {
        guard !reading.isEmpty, reading != expression else { return GlossaryHTML.escape(expression) }
        let word = Array(expression), kana = Array(reading)
        let limit = min(word.count, kana.count)
        var head = 0
        while head < limit, word[head] == kana[head] { head += 1 }
        var tail = 0
        while tail < limit - head, word[word.count - 1 - tail] == kana[kana.count - 1 - tail] { tail += 1 }
        let base = word[head..<(word.count - tail)], furigana = kana[head..<(kana.count - tail)]
        guard !base.isEmpty, !furigana.isEmpty else { return rubyHTML(expression, reading) }
        return GlossaryHTML.escape(String(word[..<head])) + rubyHTML(String(base), String(furigana))
            + GlossaryHTML.escape(String(word[(word.count - tail)...]))
    }

    private static func rubyHTML(_ base: String, _ reading: String) -> String {
        "<ruby>\(GlossaryHTML.escape(base))<rt>\(GlossaryHTML.escape(reading))</rt></ruby>"
    }

    private static func entryHTML(_ entry: LookupEntry) -> String {
        var out = "<article class='entry'><div class='head'>\(headword(entry.expression, reading: entry.reading))</div>"
        if !entry.reasons.isEmpty {
            out += "<div class='reasons'>\(GlossaryHTML.escape(entry.reasons.joined(separator: " · ")))</div>"
        }
        if !entry.frequencies.isEmpty {
            let badges = entry.frequencies.map {
                "<span class='freq'><b>\(GlossaryHTML.escape($0.dictionaryTitle))</b>\(GlossaryHTML.escape($0.displayText))</span>"
            }
            out += "<div class='badges'>" + badges.joined() + "</div>"
        }
        return out + entry.sections.map(sectionHTML).joined() + "</article>"
    }

    private static func sectionHTML(_ section: LookupSection) -> String {
        let definitions = section.definitions.map(definitionHTML)
        let body = definitions.count == 1
            ? "<div class='def'>\(definitions[0])</div>"
            : "<ol class='defs'>" + definitions.map { "<li class='def'>\($0)</li>" }.joined() + "</ol>"
        return "<section><h3>\(GlossaryHTML.escape(section.dictionaryTitle))</h3>\(body)</section>"
    }

    private static func definitionHTML(_ definition: LookupDefinition) -> String {
        let tags = (definition.tags + definition.termTags).filter { !$0.isEmpty }
        let chips = tags.isEmpty ? "" : "<div class='tags'>" + tags.map { "<span>\(GlossaryHTML.escape($0))</span>" }.joined() + "</div>"
        return chips + GlossaryHTML.html(definition.glossary)
    }

    private static func css(_ palette: Palette) -> String {
        [
            "html{-webkit-text-size-adjust:100%}",
            "body{margin:0;padding:2px 12px 12px;font:-apple-system-body;line-height:1.35;color:\(palette.ink);background:transparent;overflow-wrap:anywhere}",
            ".entry+.entry{margin-top:12px;padding-top:12px;border-top:1px solid \(palette.shell)}",
            ".head{font-size:1.7em;font-weight:700;line-height:1.5}",
            "rt{font-size:.45em;font-weight:400;color:\(palette.inkSoft)}",
            ".reasons{font-size:.8em;color:\(palette.inkSoft)}",
            ".badges{display:flex;flex-wrap:wrap;gap:4px;margin:4px 0}",
            ".freq{font-size:.75em;padding:1px 6px;border-radius:6px;background:\(palette.shell);color:\(palette.inkSoft)}",
            ".freq b{margin-right:4px;color:\(palette.ink)}",
            "h3{margin:12px 0 4px;font-size:.8em;font-weight:700;color:\(palette.accent)}",
            ".tags{margin:2px 0}",
            ".tags span{margin-right:4px;padding:0 5px;border-radius:5px;font-size:.7em;background:\(palette.shell);color:\(palette.inkSoft)}",
            ".defs{margin:0;padding-left:1.4em}",
            ".def{white-space:pre-line}",
            "ul,ol{margin:0;padding-left:1.3em}",
            "table{border-collapse:collapse}",
            "td,th{padding:2px 6px;border:1px solid \(palette.shell)}",
            "summary{color:\(palette.accent)}",
        ].joined()
    }
}
