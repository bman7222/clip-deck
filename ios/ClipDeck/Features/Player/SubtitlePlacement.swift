import SwiftUI

/// Gaps between the video's edges and the resting region of the line (today's margins).
nonisolated struct SubtitleMargins: Equatable, Sendable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat
}

/// Where the line goes. A pure function of the video size, the margins, the bars and the line's size, so the
/// "always on screen" rule is unit-tested. All coordinates are local to the video (origin at its top left).
///
/// - The resting region is the video inset by the margins. The wanted place is measured in it: `up` is a fraction
///   of its height, `right` a fraction of its width.
/// - While the top bar, the bottom bar or the landscape style card show, the region's top or bottom is pulled
///   in to clear them (the obstruction is the distance from that video edge). A line already clear of a bar
///   doesn't move, and the default line sits where it always sat.
/// - While the landscape style card is open (`stepsFromObstruction`), `up` is counted from the line's
///   resting place just above the card, not from the video's bottom, so every Up or Down tap visibly moves the
///   line (a live preview). Closing the card goes back to the normal rule above.
/// - The line is then moved fully inside. A line taller than the region is pinned to the region's bottom.
nonisolated enum SubtitlePlacement {
    static func restingRegion(videoSize: CGSize, margins: SubtitleMargins) -> CGRect {
        CGRect(
            x: margins.leading,
            y: margins.top,
            width: max(0, videoSize.width - margins.leading - margins.trailing),
            height: max(0, videoSize.height - margins.top - margins.bottom)
        )
    }

    static func frame(
        videoSize: CGSize,
        margins: SubtitleMargins,
        topObstruction: CGFloat = 0,
        bottomObstruction: CGFloat = 0,
        lineSize: CGSize,
        style: SubtitleStyle,
        stepsFromObstruction: Bool = false,
        avoid: CGRect? = nil
    ) -> CGRect {
        let style = style.clamped()
        let resting = restingRegion(videoSize: videoSize, margins: margins)
        let activeTop = min(max(resting.minY, topObstruction), resting.maxY)
        let activeBottom = max(min(resting.maxY, videoSize.height - bottomObstruction), activeTop)

        let width = min(max(lineSize.width, 0), resting.width)
        let height = max(lineSize.height, 0)

        let wantedCenterX = resting.midX + CGFloat(style.right) * resting.width
        let x = min(max(wantedCenterX - width / 2, resting.minX), resting.maxX - width)

        let upDistance = CGFloat(style.up) * resting.height
        let wantedBottom = (stepsFromObstruction ? activeBottom : resting.maxY) - upDistance
        let fitsRegion = height < activeBottom - activeTop
        var bottom: CGFloat
        if fitsRegion {
            bottom = min(max(wantedBottom, activeTop + height), activeBottom)
        } else {
            bottom = activeBottom
        }
        if let band = avoid, fitsRegion, !band.isEmpty,
           x < band.maxX, x + width > band.minX, bottom - height < band.maxY, bottom > band.minY {
            // The line meets the band: just above it (bottom = band.minY) or just below it (top = band.maxY).
            let above = band.minY
            let below = band.maxY + height
            let aboveFits = above - height >= activeTop
            let belowFits = below <= activeBottom
            if aboveFits && belowFits {
                bottom = abs(above - bottom) < abs(below - bottom) ? above : below
            } else if aboveFits {
                bottom = above
            } else if belowFits {
                bottom = below
            } else {
                // Neither fits: below, kept inside the region by the usual clamp.
                bottom = min(max(below, activeTop + height), activeBottom)
            }
        }
        return CGRect(x: x, y: bottom - height, width: width, height: height)
    }

    /// Points of clear space around the overlay buttons that the line keeps away from.
    static let overlayPadding: CGFloat = 8

    /// The band the line avoids while the centred playback overlay shows, local to the video. It comes from the
    /// overlay's layout rule (centres at 25 / 50 / 75 % of the width, vertically centred, 44 / 52 / 44 pt circles),
    /// not from measured views: from back 5's left edge to forward 5's right edge, 52 pt tall, plus the padding.
    static func overlayBand(videoSize: CGSize) -> CGRect {
        let left = videoSize.width * 0.25 - 44 / 2
        let right = videoSize.width * 0.75 + 44 / 2
        let top = videoSize.height / 2 - 52 / 2
        return CGRect(x: left, y: top, width: right - left, height: 52)
            .insetBy(dx: -overlayPadding, dy: -overlayPadding)
    }

    /// The smallest move (in points) that counts as "the line moved" when the landscape card is open.
    static let visibleMove: CGFloat = 1

    /// While the landscape style card is open: can one more Up step still move the line? False at the stored
    /// limit, and false when the placement for step n+1 is clamped to the same place as step n (the line has
    /// reached the top bar, or the top of the video). `stepsFromObstruction` is true for the landscape card (the
    /// default: `up` counted from the card); pass false for a menu at the top, where `up` counts from the bottom.
    static func canStepUpWithCardOpen(
        videoSize: CGSize,
        margins: SubtitleMargins,
        topObstruction: CGFloat,
        bottomObstruction: CGFloat,
        lineSize: CGSize,
        style: SubtitleStyle,
        stepsFromObstruction: Bool = true
    ) -> Bool {
        let current = style.clamped()
        guard current.canMoveUp else { return false }
        // Not measured yet (no line has been drawn): nothing to judge, so leave Up enabled.
        guard videoSize.width > 0, videoSize.height > 0 else { return true }
        var next = current
        next.stepUp(1)
        let now = frame(
            videoSize: videoSize, margins: margins, topObstruction: topObstruction,
            bottomObstruction: bottomObstruction, lineSize: lineSize, style: current,
            stepsFromObstruction: stepsFromObstruction)
        let after = frame(
            videoSize: videoSize, margins: margins, topObstruction: topObstruction,
            bottomObstruction: bottomObstruction, lineSize: lineSize, style: next,
            stepsFromObstruction: stepsFromObstruction)
        return abs(now.minY - after.minY) > visibleMove
    }

    /// While the landscape card is open: the highest `up` the line can reach (searched in 0.05 steps from 0), that is
    /// the first value from which one more Up would not move it. A stored `up` above it is pinned under the top bar.
    static func highestReachableUp(
        videoSize: CGSize,
        margins: SubtitleMargins,
        topObstruction: CGFloat,
        bottomObstruction: CGFloat,
        lineSize: CGSize,
        stepsFromObstruction: Bool = true
    ) -> Double {
        let taps = Int((SubtitleStyle.upRange.upperBound / SubtitleStyle.positionStep).rounded())
        for tap in 0...taps {
            let up = SubtitleStyle.positionSum(0, tap, to: SubtitleStyle.upRange)
            let canStep = canStepUpWithCardOpen(
                videoSize: videoSize, margins: margins, topObstruction: topObstruction,
                bottomObstruction: bottomObstruction, lineSize: lineSize, style: SubtitleStyle(up: up),
                stepsFromObstruction: stepsFromObstruction)
            if !canStep { return up }
        }
        return SubtitleStyle.upRange.upperBound
    }

    /// The `up` after one Down tap with the card open. A stored value above the highest reachable one jumps to 0.05
    /// below it, so the line moves at once; otherwise it is 0.05 down from where it is (never below the default).
    static func upAfterDownWithCardOpen(stored: Double, highestReachable: Double) -> Double {
        let current = SubtitleStyle.clampPosition(stored, to: SubtitleStyle.upRange)
        let target = current > highestReachable ? highestReachable - SubtitleStyle.positionStep
            : current - SubtitleStyle.positionStep
        return SubtitleStyle.clampPosition(target, to: SubtitleStyle.upRange)
    }
}

/// Places its one child with `SubtitlePlacement`. The child is measured at the resting region's width and
/// must hug its text, so the frame it gets is the frame of the visible line.
struct SubtitleLineLayout: Layout {
    var style: SubtitleStyle
    var margins: SubtitleMargins
    var topObstruction: CGFloat
    var bottomObstruction: CGFloat
    /// True while the style card is open: the up steps start from just above the card.
    var stepsFromObstruction = false
    /// True while the centred overlay shows: the line keeps clear of its band (never saved).
    var avoidsOverlay = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 320, height: 180))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let line = subviews.first else { return }
        let regionWidth = max(0, bounds.width - margins.leading - margins.trailing)
        let measured = line.sizeThatFits(ProposedViewSize(width: regionWidth, height: nil))
        let frame = SubtitlePlacement.frame(
            videoSize: bounds.size,
            margins: margins,
            topObstruction: topObstruction,
            bottomObstruction: bottomObstruction,
            lineSize: measured,
            style: style,
            stepsFromObstruction: stepsFromObstruction,
            avoid: avoidsOverlay ? SubtitlePlacement.overlayBand(videoSize: bounds.size) : nil
        )
        line.place(
            at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: frame.width, height: frame.height)
        )
    }
}
