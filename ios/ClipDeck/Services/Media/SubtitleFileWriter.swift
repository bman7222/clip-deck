import Foundation

/// One subtitle packet read from the MKV, on the source clock (which is the MP4's clock: no rebase).
nonisolated struct SubtitleCuePacket: Sendable, Equatable {
    /// Presentation time in milliseconds.
    var startMs: Int
    /// Block duration in milliseconds; 0 when the file doesn't say.
    var durationMs: Int
    /// The packet payload as UTF-8 text (Matroska text tracks are UTF-8).
    var text: String
}

/// Collects the packets of one subtitle track during the converter's read pass. Plain values: no libav pointer.
nonisolated struct SubtitleCollector: Sendable, Equatable {
    /// More text than this in one track means a damaged or hostile file; the track is dropped with a warning.
    static let maximumBytes = 16_000_000

    let extraction: ConversionPlan.SubtitleExtraction
    /// The track's CodecPrivate as text (the ASS header); empty for SubRip and WebVTT.
    let header: String
    private(set) var cues: [SubtitleCuePacket] = []
    private(set) var byteCount = 0
    private(set) var isTooLarge = false

    init(extraction: ConversionPlan.SubtitleExtraction, header: String) {
        self.extraction = extraction
        self.header = header
    }

    mutating func add(startMs: Int, durationMs: Int, text: String) {
        guard !isTooLarge else { return }
        byteCount += text.utf8.count
        if byteCount > Self.maximumBytes {
            isTooLarge = true
            cues = []
            return
        }
        cues.append(SubtitleCuePacket(startMs: startMs, durationMs: durationMs, text: text))
    }

    /// The file's text and how many cues it holds, or nil when the track gave no usable cue.
    func file() -> (text: String, cueCount: Int)? {
        guard !isTooLarge else { return nil }
        let written: (text: String, cueCount: Int)
        switch extraction.kind {
        case .subRip: written = SubtitleFileWriter.subRip(cues, isWebVTT: false)
        case .webVTT: written = SubtitleFileWriter.subRip(cues, isWebVTT: true)
        case .ass: written = SubtitleFileWriter.ass(header: header, cues: cues)
        }
        return written.cueCount > 0 ? written : nil
    }
}

/// Builds `.srt` and `.ass` file text from Matroska subtitle packets (the FFmpegBuild package has no srt or ass
/// muxer). Output is UTF-8 with "\n" line ends. Times are written as they are on the source clock.
nonisolated enum SubtitleFileWriter {
    /// A cue whose block has no duration is shown for this long.
    static let defaultDurationMs = 2000

    static let assEventsFormat = "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"

    /// Used when the track has no CodecPrivate header.
    static let defaultAssHeader = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 384
        PlayResY: 288
        WrapStyle: 0

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,1,2,10,10,10,1
        """

    // MARK: Time

    /// SubRip clock `HH:MM:SS,mmm`.
    static func srtClock(_ milliseconds: Int) -> String {
        let value = max(milliseconds, 0)
        return "\(pad(value / 3_600_000, 2)):\(pad(value / 60_000 % 60, 2)):\(pad(value / 1000 % 60, 2)),\(pad(value % 1000, 3))"
    }

    /// ASS clock `H:MM:SS.cc` (centiseconds, rounded to nearest).
    static func assClock(_ milliseconds: Int) -> String {
        let centis = (max(milliseconds, 0) + 5) / 10
        return "\(centis / 360_000):\(pad(centis / 6000 % 60, 2)):\(pad(centis / 100 % 60, 2)).\(pad(centis % 100, 2))"
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(width - digits.count, 0)) + digits
    }

    // MARK: SubRip

    /// A SubRip file from SubRip or WebVTT packets. FFmpeg's Matroska demuxer puts only the cue payload in a WebVTT
    /// packet (identifier and settings are side data), so both kinds are written alike: every line is cue text.
    static func subRip(_ cues: [SubtitleCuePacket], isWebVTT: Bool) -> (text: String, cueCount: Int) {
        var entries: [(start: Int, end: Int, text: String)] = []
        for cue in cues {
            let body = normalizeNewlines(cue.text)
            // A blank line would end the cue in an SRT file.
            let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }
            let start = max(cue.startMs, 0)
            let duration = cue.durationMs > 0 ? cue.durationMs : defaultDurationMs
            entries.append((start, start + duration, lines.joined(separator: "\n")))
        }
        // Stable: equal start times keep their packet order.
        let sorted = entries.enumerated().sorted { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }.map { $0.element }
        var out = ""
        for (index, entry) in sorted.enumerated() {
            out += "\(index + 1)\n\(srtClock(entry.start)) --> \(srtClock(entry.end))\n\(entry.text)\n\n"
        }
        return (out, sorted.count)
    }

    // MARK: ASS

    /// An ASS file: the track's CodecPrivate header (without any `[Events]` section it carries), then `[Events]`
    /// with a `Format:` line and one `Dialogue:` line per packet, in ReadOrder order. Packets are
    /// `ReadOrder,Layer,Style,Name,MarginL,MarginR,MarginV,Effect,Text`; the times come from the packet.
    static func ass(header: String, cues: [SubtitleCuePacket]) -> (text: String, cueCount: Int) {
        var events: [(readOrder: Int, offset: Int, line: String)] = []
        for (offset, cue) in cues.enumerated() {
            let packet = normalizeNewlines(cue.text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Text may contain commas, so split off the 8 leading fields only.
            let fields = packet.split(separator: ",", maxSplits: 8, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 9 else { continue }
            let text = fields[8].replacingOccurrences(of: "\n", with: "\\N")
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let start = max(cue.startMs, 0)
            let duration = cue.durationMs > 0 ? cue.durationMs : defaultDurationMs
            let line = "Dialogue: \(fields[1]),\(assClock(start)),\(assClock(start + duration)),"
                + "\(fields[2]),\(fields[3]),\(fields[4]),\(fields[5]),\(fields[6]),\(fields[7]),\(text)"
            events.append((Int(fields[0].trimmingCharacters(in: .whitespaces)) ?? Int.max, offset, line))
        }
        events.sort { ($0.readOrder, $0.offset) < ($1.readOrder, $1.offset) }

        var out = assHeader(from: header)
        out += "\n[Events]\n\(assEventsFormat)\n"
        for event in events { out += event.line + "\n" }
        return (out, events.count)
    }

    /// The CodecPrivate text up to (not including) its `[Events]` section; a default header when it has none.
    static func assHeader(from codecPrivate: String) -> String {
        let text = normalizeNewlines(codecPrivate.replacingOccurrences(of: "\u{FEFF}", with: ""))
        var kept: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).lowercased() == "[events]" { break }
            kept.append(line)
        }
        let header = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = header.contains("[") ? header : defaultAssHeader
        return body + "\n"
    }

    static func normalizeNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{0}", with: "")
    }
}
