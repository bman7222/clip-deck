import Foundation

/// Turns Yomitan glossary items (plain strings, text items, structured content) into safe HTML for the popup's web view.
/// Every piece of text is escaped. Only a small set of tags and styles gets through; a link is shown as its text, and
/// images, scripts and every attribute other than `style` are dropped. Attribute values use single quotes.
nonisolated enum GlossaryHTML {
    private static let maxDepth = 24
    private static let tags: Set<String> = [
        "ruby", "rt", "rp", "ul", "ol", "li", "table", "thead", "tbody", "tr", "th", "td", "details", "summary", "div", "span",
    ]
    private static let dropped: Set<String> = ["img", "script", "style"]

    /// One definition's glossary: text items become a bulleted list, structured items their own block.
    static func html(_ items: [GlossaryItem]) -> String {
        var out = ""
        var listOpen = false
        for item in items {
            switch item {
            case .text(let text):
                if !listOpen { out += "<ul>"; listOpen = true }
                out += "<li>\(escape(text))</li>"
            case .structured(let json):
                if listOpen { out += "</ul>"; listOpen = false }
                out += "<div>\(html(structured: json))</div>"
            }
        }
        return listOpen ? out + "</ul>" : out
    }

    static func html(structured json: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: json, options: .fragmentsAllowed) else { return "" }
        return render(root, depth: 0)
    }

    static func escape(_ text: String) -> String {
        text.reduce(into: "") { out, character in
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\u{22}": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(character)
            }
        }
    }

    private static func render(_ node: Any, depth: Int) -> String {
        guard depth < maxDepth else { return "" }
        if let text = node as? String { return escape(text) }
        if let list = node as? [Any] { return list.map { render($0, depth: depth + 1) }.joined() }
        guard let object = node as? [String: Any] else { return "" }
        let tag = (object["tag"] as? String)?.lowercased() ?? ""
        if dropped.contains(tag) { return "" }
        if tag == "br" { return "<br>" }
        let inner = object["content"].map { render($0, depth: depth + 1) } ?? ""
        guard tags.contains(tag) else { return inner }
        return "<\(tag)\(style(object["style"]))>\(inner)</\(tag)>"
    }

    /// The allowed styles of a structured-content `style` object, as a ` style='…'` attribute (or nothing).
    private static func style(_ any: Any?) -> String {
        guard let style = any as? [String: Any] else { return "" }
        var parts: [String] = []
        func keyword(_ key: String, _ css: String, _ allowed: Set<String>) {
            if let value = style[key] as? String, allowed.contains(value) { parts.append("\(css):\(value)") }
        }
        keyword("fontWeight", "font-weight", ["bold", "normal"])
        keyword("fontStyle", "font-style", ["italic", "normal"])
        let lines = (style["textDecorationLine"] as? [String]) ?? (style["textDecorationLine"] as? String).map { [$0] } ?? []
        let allowedLines = lines.filter { ["underline", "line-through", "none"].contains($0) }
        if !allowedLines.isEmpty { parts.append("text-decoration:" + allowedLines.joined(separator: " ")) }
        if let size = style["fontSize"] as? String, size.hasSuffix("em"), let em = Double(size.dropLast(2)), (0.1...5).contains(em) {
            parts.append("font-size:\(em)em")
        }
        keyword("listStyleType", "list-style-type", ["disc", "circle", "square", "decimal", "none"])
        keyword("verticalAlign", "vertical-align",
                ["baseline", "sub", "super", "top", "middle", "bottom", "text-top", "text-bottom"])
        return parts.isEmpty ? "" : " style='\(parts.joined(separator: ";"))'"
    }
}
