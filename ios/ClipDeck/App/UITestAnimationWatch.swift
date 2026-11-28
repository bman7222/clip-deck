#if DEBUG
import QuartzCore
import UIKit

/// UI tests only (`-uiTesting`, Debug builds; started by `ClipDeckApp`). It only reads the layer tree and prints.
///
/// Before and after every UI-test action XCTest waits until the app's UIKit animations have finished. On slow CI
/// runners the app sometimes stops answering that wait right after a rotation to landscape, for the rest of the
/// process (the "idle stall", T-034; `UITestSupport.rotateToLandscape` guards the tests against it). To find the
/// animation that never finishes, this walks every window's layer tree every 2 s and prints, once each, every
/// animation that has stayed on a layer for 3 s or more. Nothing in Clip Deck animates that long; a system spinner
/// does, which also shows the watch is running. The lines go to the app's stdout, which the xcresult keeps
/// (`StandardOutputAndStandardError-dev.brent.clipdeck.txt`). No line near a stall means the animation XCTest is
/// waiting for is no longer on a layer in any window.
enum UITestAnimationWatch {
    private static let interval: Duration = .seconds(2)
    private static let longRunning: Duration = .seconds(3)
    /// At most this many lines per app process.
    private static let maxReports = 40
    /// When each animation (its layer, key and begin time) was first seen, while it is still on its layer.
    private static var firstSeen: [String: ContinuousClock.Instant] = [:]
    private static var reported: Set<String> = []
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        print("UITestAnimationWatch: started; prints every animation that stays on a layer for 3 s or more")
        Task {
            while reported.count < maxReports {
                try? await Task.sleep(for: interval)
                scan()
            }
        }
    }

    private static func scan() {
        let now = ContinuousClock.now
        var current: [String: String] = [:]
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                collect(window.layer, owners: [String(describing: type(of: window))], identifier: nil,
                        speed: 1, hidden: window.isHidden, into: &current)
            }
        }
        firstSeen = firstSeen.filter { current[$0.key] != nil }
        for (id, text) in current.sorted(by: { $0.key < $1.key }) {
            let first = firstSeen[id] ?? now
            firstSeen[id] = first
            guard now - first >= longRunning, !reported.contains(id), reported.count < maxReports else { continue }
            reported.insert(id)
            print("UITestAnimationWatch: on its layer for at least \(now - first): \(text)")
        }
    }

    /// Records every animation on `layer` and its sublayers. `owners` are the view classes from the window down,
    /// `identifier` the nearest accessibility identifier, `speed` the product of the layer speeds above.
    private static func collect(_ layer: CALayer, owners: [String], identifier: String?, speed: Float, hidden: Bool,
                                into current: inout [String: String]) {
        let speed = speed * layer.speed
        let hidden = hidden || layer.isHidden
        var owners = owners
        var identifier = identifier
        if let view = layer.delegate as? UIView {
            owners.append(String(describing: type(of: view)))
            if let viewIdentifier = view.accessibilityIdentifier, !viewIdentifier.isEmpty { identifier = viewIdentifier }
        }
        for key in layer.animationKeys() ?? [] {
            guard let animation = layer.animation(forKey: key) else { continue }
            // iOS 26 Liquid Glass keeps infinite "match" animations (no delegate) on glass bar items. They are
            // permanent noise and never what XCTest waits for, so they are skipped.
            if animation.duration.isInfinite, animation.delegate == nil,
               String(describing: type(of: animation)).contains("Match") { continue }
            let id = "\(ObjectIdentifier(layer))|\(key)|\(animation.beginTime)"
            let keyPath = (animation as? CAPropertyAnimation)?.keyPath ?? "-"
            let delegate = animation.delegate.map { String(describing: type(of: $0)) } ?? "none"
            let repeats = animation.repeatCount.isInfinite ? "forever" : "\(animation.repeatCount)"
            let layerTime = layer.convertTime(CACurrentMediaTime(), from: nil)
            let place = "\(owners.suffix(6).joined(separator: " > ")) layer \(type(of: layer)) id \(identifier ?? "-")"
            let what = "key \(key) keyPath \(keyPath) \(type(of: animation)) duration \(animation.duration)"
                + " repeat \(repeats) repeatDuration \(animation.repeatDuration)"
            let timing = "beginTime \(animation.beginTime) layerTime \(layerTime) speed \(speed) hidden \(hidden)"
            current[id] = "\(place); \(what); \(timing); delegate \(delegate)"
        }
        for sublayer in layer.sublayers ?? [] {
            collect(sublayer, owners: owners, identifier: identifier, speed: speed, hidden: hidden, into: &current)
        }
    }
}
#endif
