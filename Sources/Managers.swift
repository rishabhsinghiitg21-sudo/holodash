import Foundation
import CoreLocation
import MapKit

// MARK: - Maneuver model

struct Maneuver {
    enum Dir {
        case left, right, slightLeft, slightRight, straight, merge, uturn, arrive
        case forkLeft, forkRight, roundabout, exitLeft, exitRight

        /// Short uppercase verb shown in the yellow turn callout.
        var verb: String {
            switch self {
            case .left:        return "TURN LEFT"
            case .right:       return "TURN RIGHT"
            case .slightLeft:  return "SLIGHT LEFT"
            case .slightRight: return "SLIGHT RIGHT"
            case .straight:    return "CONTINUE"
            case .merge:       return "MERGE"
            case .uturn:       return "U-TURN"
            case .arrive:      return "ARRIVE"
            case .forkLeft:    return "KEEP LEFT"
            case .forkRight:   return "KEEP RIGHT"
            case .roundabout:  return "ROUNDABOUT"
            case .exitLeft:    return "EXIT LEFT"
            case .exitRight:   return "EXIT RIGHT"
            }
        }

        static func parse(_ s: String) -> Dir {
            let t = s.lowercased()
            if t.contains("roundabout") || t.contains("rotary") || t.contains("traffic circle") { return .roundabout }
            if t.contains("u-turn") || t.contains("u turn") { return .uturn }
            if t.contains("exit") || t.contains("ramp") { return t.contains("left") ? .exitLeft : .exitRight }
            if t.contains("keep") || t.contains("fork") { return t.contains("left") ? .forkLeft : .forkRight }
            if t.contains("slight") { return t.contains("left") ? .slightLeft : .slightRight }
            if t.contains("merge") { return .merge }
            if t.contains("arrive") || t.contains("destination") { return .arrive }
            if t.contains("left") { return .left }
            if t.contains("right") { return .right }
            return .straight
        }
    }

    var dir: Dir
    var distance: Double   // meters to the maneuver
    var primary: String    // short label, e.g. "MG Road"
    var next: String?      // following maneuver label
}

// MARK: - Location

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    var onUpdate: ((CLLocation) -> Void)?
    var onAuth: ((Bool) -> Void)?
    /// Only deliver updates between start() and stop(); the system can report
    /// authorization at any time (e.g. on launch) and must not start the GPS by itself.
    private var wantsUpdates = false

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        mgr.activityType = .automotiveNavigation
        mgr.distanceFilter = 5
    }

    func start() {
        wantsUpdates = true
        mgr.requestWhenInUseAuthorization()
        mgr.startUpdatingLocation()
    }

    func stop() {
        wantsUpdates = false
        mgr.stopUpdatingLocation()
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if wantsUpdates, let l = locs.last { onUpdate?(l) }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        onAuth?(s == .denied || s == .restricted)
        if wantsUpdates, s == .authorizedWhenInUse || s == .authorizedAlways {
            m.startUpdatingLocation()
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Speed limit (best-effort OpenStreetMap / Overpass)

final class SpeedLimitService {
    /// Calls `completion` on the main queue. A nil value means the map has no limit here;
    /// on a network or parse failure the completion is not called, so the last limit stays.
    func lookup(_ coord: CLLocationCoordinate2D, completion: @escaping (Int?) -> Void) {
        let query = "[out:json][timeout:5];way(around:25,\(coord.latitude),\(coord.longitude))[\"maxspeed\"];out tags 1;"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encoded)") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("HoloDash/1.0 (personal project)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let elements = json["elements"] as? [[String: Any]] else { return }
            var result: Int? = nil
            if let tags = elements.first?["tags"] as? [String: Any],
               let raw = tags["maxspeed"] as? String {
                result = Self.parse(raw)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// Parses OSM `maxspeed` values such as "50", "30 mph" or "50;30" (first number wins).
    /// Non-numeric values ("none", "signals", "walk") give nil.
    static func parse(_ s: String) -> Int? {
        let lower = s.lowercased()
        let digits = lower.drop { !$0.isNumber }.prefix { $0.isNumber }
        guard let n = Int(digits), n > 0, n <= 200 else { return nil }
        if lower.contains("mph") { return Int((Double(n) * 1.60934).rounded()) }
        return n
    }
}

// MARK: - Navigation (Apple MapKit, no API key)

final class NavigationManager {
    private var maneuvers: [(coord: CLLocationCoordinate2D, instr: String)] = []
    private var idx = 0
    private var active = false

    func start(to dest: MKMapItem, completion: @escaping (Bool) -> Void) {
        let req = MKDirections.Request()
        req.source = MKMapItem.forCurrentLocation()
        req.destination = dest
        req.transportType = .automobile
        MKDirections(request: req).calculate { [weak self] resp, _ in
            guard let self else { return }
            guard let route = resp?.routes.first else { completion(false); return }
            self.maneuvers = route.steps.enumerated().compactMap { i, step in
                guard i > 0 else { return nil }
                let instr = step.instructions.isEmpty ? "Continue" : step.instructions
                return (step.polyline.firstCoordinate, instr)
            }
            self.idx = 0
            self.active = true
            completion(true)
        }
    }

    func update(with loc: CLLocation) -> Maneuver? {
        guard active else { return nil }
        guard idx < maneuvers.count else {
            return Maneuver(dir: .arrive, distance: 0, primary: "Arrive", next: nil)
        }
        while idx < maneuvers.count {
            let m = maneuvers[idx]
            let d = loc.distance(from: CLLocation(latitude: m.coord.latitude, longitude: m.coord.longitude))
            if d < 15 { idx += 1 } else { break }
        }
        guard idx < maneuvers.count else {
            return Maneuver(dir: .arrive, distance: 0, primary: "Arrive", next: nil)
        }
        let cur = maneuvers[idx]
        let dist = loc.distance(from: CLLocation(latitude: cur.coord.latitude, longitude: cur.coord.longitude))
        let next = (idx + 1 < maneuvers.count) ? shorten(maneuvers[idx + 1].instr) : nil
        return Maneuver(dir: .parse(cur.instr), distance: dist, primary: shorten(cur.instr), next: next)
    }

    func reset() { maneuvers = []; idx = 0; active = false }

    private func shorten(_ s: String) -> String {
        if let r = s.range(of: "onto ") { return String(s[r.upperBound...]) }
        return s
    }
}

extension MKPolyline {
    var firstCoordinate: CLLocationCoordinate2D {
        var c = coordinate
        if pointCount > 0 { c = points()[0].coordinate }
        return c
    }
}
