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
/// - The resting region is the video inset by the margins. The wanted place is measured in it: each up step
///   is 5% of its height, each sideways step 5% of its width.
/// - While the top bar, the bottom bar or the landscape style card show, the region's top or bottom is pulled
///   in to clear them (the obstruction is the distance from that video edge). A line already clear of a bar
///   doesn't move, and the default line sits where it always sat.
/// - While the landscape style card is open (`stepsFromObstruction`), the up steps are counted from the line's
///   resting place just above the card, not from the video's bottom, so every Up or Down tap visibly moves the
///   line (a live preview). Closing the card goes back to the normal rule above.
/// - The line is then moved fully inside. A line taller than the region is pinned to the region's bottom.
nonisolated enum SubtitlePlacement {
    static let stepFraction: CGFloat = 0.05

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
        stepsFromObstruction: Bool = false
    ) -> CGRect {
        let style = style.clamped()
        let resting = restingRegion(videoSize: videoSize, margins: margins)
        let activeTop = min(max(resting.minY, topObstruction), resting.maxY)
        let activeBottom = max(min(resting.maxY, videoSize.height - bottomObstruction), activeTop)

        let width = min(max(lineSize.width, 0), resting.width)
        let height = max(lineSize.height, 0)

        let wantedCenterX = resting.midX + CGFloat(style.rightSteps) * stepFraction * resting.width
        let x = min(max(wantedCenterX - width / 2, resting.minX), resting.maxX - width)

        let upDistance = CGFloat(style.upSteps) * stepFraction * resting.height
        let wantedBottom = (stepsFromObstruction ? activeBottom : resting.maxY) - upDistance
        let bottom: CGFloat
        if height >= activeBottom - activeTop {
            bottom = activeBottom
        } else {
            bottom = min(max(wantedBottom, activeTop + height), activeBottom)
        }
        return CGRect(x: x, y: bottom - height, width: width, height: height)
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
            stepsFromObstruction: stepsFromObstruction
        )
        line.place(
            at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: frame.width, height: frame.height)
        )
    }
}
