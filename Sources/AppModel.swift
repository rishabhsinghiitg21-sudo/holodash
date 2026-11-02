import Foundation
import Observation
import CoreLocation
import MapKit
import UIKit

@Observable
final class AppModel {
    // Live HUD state
    var speedKmh: Double = 0
    var hasSpeed: Bool = false
    var limitKmh: Int? = nil
    var maneuver: Maneuver? = nil
    var warning: String? = nil
    /// GPS signal strength, 0...4, derived from CLLocation.horizontalAccuracy.
    var gpsBars: Int = 0

    // Flow
    var running: Bool = false
    var demo: Bool = false
    var destinationName: String = ""
    var authDenied: Bool = false

    // Settings (persisted)
    var mirrored: Bool { didSet { if persistMirror { ud.set(mirrored, forKey: "mirrored") } } }
    var useMph: Bool { didSet { ud.set(useMph, forKey: "useMph") } }
    var keepAwake: Bool { didSet { ud.set(keepAwake, forKey: "keepAwake"); if running { UIApplication.shared.isIdleTimerDisabled = keepAwake } } }
    var overThreshold: Int { didSet { ud.set(overThreshold, forKey: "overThreshold") } }
    var largeText: Bool { didSet { ud.set(largeText, forKey: "largeText") } }

    /// False while a launch argument overrides the mirror setting, so `-noMirror` is not saved.
    private var persistMirror = true
    private let ud = UserDefaults.standard
    private let location = LocationManager()
    private let speedLimits = SpeedLimitService()
    private let nav = NavigationManager()
    private var demoTimer: Timer?
    private var lastLimitLookup: Date = .distantPast
    private var lastLoc: CLLocation?

    init() {
        mirrored = ud.object(forKey: "mirrored") as? Bool ?? true
        useMph = ud.bool(forKey: "useMph")
        keepAwake = ud.object(forKey: "keepAwake") as? Bool ?? true
        overThreshold = ud.object(forKey: "overThreshold") as? Int ?? 3
        largeText = ud.bool(forKey: "largeText")
        location.onAuth = { [weak self] d in self?.authDenied = d }
        location.onUpdate = { [weak self] loc in self?.handle(loc) }
    }

    /// Turns mirroring off for this run only (the `-noMirror` launch argument); the saved setting is untouched.
    func disableMirrorForSession() {
        persistMirror = false
        mirrored = false
        persistMirror = true
    }

    // Derived display values (unit-aware)
    var displaySpeed: Int { Int((useMph ? speedKmh / 1.60934 : speedKmh).rounded()) }
    var displayLimit: Int? {
        guard let l = limitKmh else { return nil }
        return useMph ? Int((Double(l) / 1.60934).rounded()) : l
    }
    var unitLabel: String { useMph ? "MPH" : "KM/H" }
    /// The over-limit margin is entered in the display unit (km/h or mph); compare in km/h.
    private var thresholdKmh: Double { Double(overThreshold) * (useMph ? 1.60934 : 1) }
    var isOver: Bool {
        if let l = limitKmh { return speedKmh > Double(l) + thresholdKmh }
        return false
    }

    // MARK: Start modes

    /// Clears anything left over from a previous run (demo values, old GPS fix, old route).
    private func resetFeeds() {
        demoTimer?.invalidate(); demoTimer = nil
        location.stop(); nav.reset()
        speedKmh = 0; hasSpeed = false; limitKmh = nil; maneuver = nil
        gpsBars = 0; lastLoc = nil; lastLimitLookup = .distantPast
    }

    func start(destination item: MKMapItem) {
        resetFeeds()
        demo = false; running = true; warning = nil
        destinationName = item.name ?? "Destination"
        awake(true)
        location.start()
        nav.start(to: item) { [weak self] ok in if !ok { self?.warning = "ROUTE UNAVAILABLE" } }
    }

    func startNoRoute() {
        resetFeeds()
        demo = false; running = true; warning = nil; destinationName = ""
        awake(true)
        location.start()
    }

    func startDemo() {
        resetFeeds()
        demo = true; running = true; warning = nil
        awake(true)
        startDemoFeed()
    }

    #if DEBUG
    /// Debug only: auto-start a real MapKit route to a fixed destination (used with simulated GPS).
    func startSimNav() {
        let dest = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: 37.7955, longitude: -122.3937)))
        dest.name = "Ferry Building"
        start(destination: dest)
    }
    #endif

    func stop() {
        running = false; demo = false
        resetFeeds()
        awake(false)
    }

    private func awake(_ on: Bool) { UIApplication.shared.isIdleTimerDisabled = on && keepAwake }

    // MARK: Live data

    private func handle(_ loc: CLLocation) {
        gpsBars = Self.bars(forAccuracy: loc.horizontalAccuracy)
        if loc.speed >= 0 {
            speedKmh = loc.speed * 3.6; hasSpeed = true
        } else if let p = lastLoc {                       // derive speed from GPS deltas
            let dt = loc.timestamp.timeIntervalSince(p.timestamp)
            if dt > 0.1 { speedKmh = loc.distance(from: p) / dt * 3.6; hasSpeed = true }
        }
        lastLoc = loc
        if let m = nav.update(with: loc) { maneuver = m }
        if Date().timeIntervalSince(lastLimitLookup) > 12 {
            lastLimitLookup = Date()
            speedLimits.lookup(loc.coordinate) { [weak self] kmh in guard let self, self.running, !self.demo else { return }; self.limitKmh = kmh; self.updateWarning() }
        }
        updateWarning()
    }

    /// Maps horizontal accuracy (metres) to 0...4 signal bars. A negative value means no fix.
    static func bars(forAccuracy a: Double) -> Int {
        if a < 0 { return 0 }
        if a <= 10 { return 4 }
        if a <= 30 { return 3 }
        if a <= 100 { return 2 }
        return 1
    }

    private func updateWarning() {
        if isOver { warning = "OVER LIMIT" }
        else if warning == "OVER LIMIT" { warning = nil }
    }

    // MARK: Demo feed

    private func startDemoFeed() {
        let legs: [(Maneuver.Dir, String, String)] = [
            (.right, "MG Road", "Ring Road"),
            (.forkRight, "NH-48", "Exit 12"),
            (.roundabout, "Field Marshal Rd", "3rd Ave"),
            (.left, "Brigade Rd", "Residency Rd"),
            (.straight, "ahead", "Church St"),
            (.merge, "NH-48", "Toll Plaza"),
            (.exitRight, "Exit 9", "Service Rd"),
            (.uturn, "MG Road", "city centre"),
            (.slightRight, "Hosur Rd", "Silk Board"),
            (.slightLeft, "Old Airport Rd", "Indiranagar"),
            (.forkLeft, "Outer Ring Rd", "Marathahalli"),
            (.exitLeft, "Exit 14", "Sarjapur Rd"),
            (.arrive, "Destination", "")
        ]
        var dist = 400.0
        var li = 0
        var limit = 50
        speedKmh = 48; hasSpeed = true; limitKmh = limit
        gpsBars = 3   // simulated
        maneuver = Maneuver(dir: legs[0].0, distance: dist, primary: legs[0].1, next: legs[1].2)

        demoTimer?.invalidate()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { [weak self] _ in
            guard let self else { return }
            let target = Double(limit) + 4
            self.speedKmh += (target - self.speedKmh) * 0.12 + Double.random(in: -3...3)
            self.speedKmh = max(8, min(130, self.speedKmh))
            dist -= Double.random(in: 18...44)
            if dist <= 0 {
                li = (li + 1) % legs.count
                dist = Double(200 + Int.random(in: 0...7) * 100)
                limit = [30, 40, 50, 60, 80, 100].randomElement()!
                self.limitKmh = limit
            }
            let leg = legs[li]
            self.maneuver = Maneuver(dir: leg.0, distance: dist, primary: leg.1, next: legs[(li + 1) % legs.count].1)
            self.updateWarning()
        }
    }
}
