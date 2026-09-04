import Observation

/// Which screen a panel is showing. One per surface: the popover and the Dock window each
/// keep their own place, so opening one does not move the other.
///
/// Reset when the panel closes: a menu bar panel opens on the thing it is for, not on
/// wherever you happened to be last time.
@Observable
final class PanelNavigation {
    var route: PanelRoute = .overview

    func go(to route: PanelRoute) { self.route = route }
    func reset() { route = .overview }
}
