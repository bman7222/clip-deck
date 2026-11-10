import Foundation

/// One subtitle line with its times in the subtitle file's own clock (before any offset).
struct SubtitleCue: Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let startMs: Int
    let endMs: Int
    let text: String
}

enum SubtitleFormat: String, CaseIterable, Sendable {
    case srt, ass, ssa

    init?(fileExtension: String) {
        self.init(rawValue: fileExtension.lowercased())
    }
}

enum SubtitleError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case unreadable(String)
    case empty(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "“.\(ext)” files aren't supported. Use an .srt or .ass subtitle file."
        case .unreadable(let name):
            return "“\(name)” couldn't be read as text. Save it as UTF-8 and import it again."
        case .empty(let name):
            return "“\(name)” has no subtitle lines Clip Deck can show."
        }
    }
}

enum SubtitleParser {
    // MARK: Entry points

    static func parse(contentsOf url: URL) throws -> [SubtitleCue] {
        let name = url.lastPathComponent
        guard let format = SubtitleFormat(fileExtension: url.pathExtension) else {
            throw SubtitleError.unsupportedFormat(url.pathExtension)
        }
        let data = try Data(contentsOf: url)
        guard let text = decode(data) else { throw SubtitleError.unreadable(name) }
        let cues = parse(text, format: format)
        if cues.isEmpty { throw SubtitleError.empty(name) }
        return cues
    }

    static func parse(_ text: String, format: SubtitleFormat) -> [SubtitleCue] {
        let normalized = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let raw = format == .srt ? parseSRT(normalized) : parseASS(normalized)
        return finalize(raw)
    }

    /// UTF-8 (with or without BOM), UTF-16 with BOM, then Shift-JIS (common for older Japanese files).
    static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .shiftJIS) { return text }
        return String(data: data, encoding: .windowsCP1252)
    }

    // MARK: Time

    /// Parses `H:MM:SS,mmm`, `HH:MM:SS.mmm`, `MM:SS.mmm`, and ASS centiseconds `H:MM:SS.cc`.
    static func parseClock(_ string: String) -> Int? {
        let value = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count) else { return nil }

        let secondParts = parts[parts.count - 1].split(separator: ".", omittingEmptySubsequences: false)
        guard secondParts.count <= 2, let seconds = Int(secondParts[0]) else { return nil }
        var millis = 0
        if secondParts.count == 2 {
            let fraction = String(secondParts[1].prefix(3))
            let scale = [1: 100, 2: 10, 3: 1]
            guard let digits = Int(fraction), let multiplier = scale[fraction.count] else { return nil }
            millis = digits * multiplier
        }
        guard let minutes = Int(parts[parts.count - 2]) else { return nil }
        let hours = parts.count == 3 ? Int(parts[0]) : 0
        guard let hours, minutes >= 0, seconds >= 0 else { return nil }
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis
    }

    // MARK: SRT

    struct RawCue: Equatable {
        let startMs: Int
        let endMs: Int
        let text: String
    }

    static func parseSRT(_ text: String) -> [RawCue] {
        let lines = text.components(separatedBy: "\n")
        var cues: [RawCue] = []
        var index = 0
        while index < lines.count {
            guard let timing = parseSRTTiming(lines[index]) else {
                index += 1
                continue
            }
            index += 1
            var textLines: [String] = []
            while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                if parseSRTTiming(lines[index]) != nil {
                    // A block without a blank line before it: its number line ended up in our text.
                    if let last = textLines.last, Int(last.trimmingCharacters(in: .whitespaces)) != nil {
                        textLines.removeLast()
                    }
                    break
                }
                textLines.append(lines[index])
                index += 1
            }
            cues.append(RawCue(startMs: timing.0, endMs: timing.1, text: cleanSRT(textLines.joined(separator: "\n"))))
        }
        return cues
    }

    static func parseSRTTiming(_ line: String) -> (Int, Int)? {
        let sides = line.components(separatedBy: "-->")
        guard sides.count == 2 else { return nil }
        // The end side may carry position info: "00:00:02,000 X1:100 X2:200 ..."
        let endToken = sides[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
        guard let start = parseClock(sides[0]), let end = parseClock(endToken) else { return nil }
        return (start, end)
    }

    static func cleanSRT(_ text: String) -> String {
        tidyLines(
            text
                .replacing(#/<[^>]*>/#, with: "")
                .replacing(#/\{[^}]*\}/#, with: "")
        )
    }

    // MARK: ASS / SSA

    static func parseASS(_ text: String) -> [RawCue] {
        var inEvents = false
        var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var cues: [RawCue] = []

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inEvents = line.lowercased() == "[events]"
                continue
            }
            guard inEvents else { continue }
            let lower = line.lowercased()
            if lower.hasPrefix("format:") {
                fields = line.dropFirst("format:".count)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                continue
            }
            guard lower.hasPrefix("dialogue:"), !fields.isEmpty else { continue }

            let values = line.dropFirst("dialogue:".count)
                .split(separator: ",", maxSplits: fields.count - 1, omittingEmptySubsequences: false)
                .map(String.init)
            guard values.count == fields.count,
                  let startIndex = fields.firstIndex(of: "start"),
                  let endIndex = fields.firstIndex(of: "end"),
                  let textIndex = fields.firstIndex(of: "text"),
                  let start = parseClock(values[startIndex]),
                  let end = parseClock(values[endIndex])
            else { continue }

            let rawText = values[textIndex]
            // Vector drawings (\p1 and up) are signs/graphics, not dialogue.
            if rawText.contains(#/\{[^}]*\\p[1-9]/#) { continue }
            cues.append(RawCue(startMs: start, endMs: end, text: cleanASS(rawText)))
        }
        return cues
    }

    static func cleanASS(_ text: String) -> String {
        tidyLines(
            text
                .replacing(#/\{[^}]*\}/#, with: "")
                .replacingOccurrences(of: "\\N", with: "\n")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\h", with: " ")
        )
    }

    // MARK: Shared

    static func tidyLines(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Drops empty/invalid lines, sorts by time, removes exact duplicates, and numbers the cues.
    static func finalize(_ raw: [RawCue]) -> [SubtitleCue] {
        let valid = raw
            .filter { !$0.text.isEmpty && $0.endMs > $0.startMs }
            .sorted { ($0.startMs, $0.endMs) < ($1.startMs, $1.endMs) }
        var result: [SubtitleCue] = []
        var previous: RawCue?
        for cue in valid where cue != previous {
            result.append(SubtitleCue(id: result.count, startMs: cue.startMs, endMs: cue.endMs, text: cue.text))
            previous = cue
        }
        return result
    }
}
