import CoreGraphics

/// Where the dictionary popup sits until the user moves it (T-029b): the one place its reset (↺📄) goes back to.
nonisolated enum LookupPopupPlacement {
    static let margin: CGFloat = 16
    static let landscapeSize = CGSize(width: 300, height: 200)
    static let portraitHeight: CGFloat = 260

    /// `area` is where the popup may be: the video column inside the safe area (landscape) or the safe area (portrait).
    /// Landscape: the top-trailing corner, 16 pt in. Portrait: full width less 16 pt each side, just above the bottom.
    static func defaultFrame(in area: CGRect, isLandscape: Bool) -> CGRect {
        let room = CGSize(width: max(0, area.width - 2 * margin), height: max(0, area.height - 2 * margin))
        let width = isLandscape ? min(landscapeSize.width, room.width) : room.width
        let height = min(isLandscape ? landscapeSize.height : portraitHeight, room.height)
        let x = isLandscape ? area.maxX - margin - width : area.minX + margin
        let y = isLandscape ? area.minY + margin : area.maxY - margin - height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
