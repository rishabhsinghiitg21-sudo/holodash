import SwiftUI

struct HUDView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false

    private var ts: CGFloat { model.largeText ? 1.18 : 1.0 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let landscape = geo.size.width >= geo.size.height
                Group {
                    if landscape { landscapeLayout(geo: geo.size) }
                    else { portraitLayout(geo: geo.size) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(x: model.mirrored ? -1 : 1, y: 1)   // mirror for the reflection
            }
            controls
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showSettings) { SettingsView().environment(model) }
    }

    // MARK: Layouts

    @ViewBuilder
    private func landscapeLayout(geo: CGSize) -> some View {
        ZStack {
            topLabels(pad: 24, top: 44)   // below the gear / mirror controls
            if let m = model.maneuver {
                // Three disjoint columns spanning the full width: speed · road · turn
                HStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 24) {
                        SpeedTape(speed: model.displaySpeed, unit: model.unitLabel, over: model.isOver, scale: ts * 1.2)
                        LimitRoundel(limit: model.displayLimit, scale: ts * 1.15)
                    }
                    .frame(width: geo.width * 0.27)

                    RoadDiagram(kind: m.dir)
                        .frame(width: geo.width * 0.38, height: min(geo.height * 0.84, geo.width * 0.36))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: m.dir)

                    callout(distSize: 96)
                        .frame(width: geo.width * 0.35)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)   // keep the columns clear of the top label row
            } else {
                // Speed-only: large, centred, filling the screen
                HStack(spacing: geo.width * 0.12) {
                    SpeedTape(speed: model.displaySpeed, unit: model.unitLabel, over: model.isOver, scale: ts * 1.8)
                    LimitRoundel(limit: model.displayLimit, scale: ts * 1.6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func portraitLayout(geo: CGSize) -> some View {
        let pad: CGFloat = 20
        let side = min(geo.width * 0.78, geo.height * 0.40)
        ZStack {
            topLabels(pad: pad, top: pad)
            VStack(spacing: 0) {
                callout(distSize: 78).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 56).padding(.horizontal, pad)
                Spacer()
                road(side: side, dy: 0)
                Spacer()
                HStack(alignment: .bottom) {
                    SpeedTape(speed: model.displaySpeed, unit: model.unitLabel, over: model.isOver, scale: ts)
                    Spacer()
                    LimitRoundel(limit: model.displayLimit, scale: ts)
                }
                .padding(.horizontal, 26).padding(.bottom, 52)
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private func road(side: CGFloat, dy: CGFloat) -> some View {
        if let m = model.maneuver {
            RoadDiagram(kind: m.dir)
                .frame(width: side, height: side)
                .offset(y: dy)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: m.dir)
        }
    }

    private func topLabels(pad: CGFloat, top: CGFloat) -> some View {
        VStack {
            HStack(alignment: .top) {
                Text(model.maneuver == nil ? "▶  SPEED" : "▶  NAVIGATION")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(3)
                    .foregroundStyle(HUD.teal)
                Spacer()
                if model.warning == "ROUTE UNAVAILABLE" {
                    Text(model.warning ?? "")
                        .font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(2)
                        .foregroundStyle(HUD.red)
                    Spacer()
                }
                Text("GPS  " + String(repeating: "●", count: model.gpsBars) + String(repeating: "○", count: 4 - model.gpsBars))
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(2)
                    .foregroundStyle(HUD.teal.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, pad).padding(.top, top)
    }

    @ViewBuilder
    private func callout(distSize: CGFloat) -> some View {
        if let m = model.maneuver {
            VStack(alignment: .leading, spacing: 3) {
                Text("▸ " + m.dir.verb)
                    .font(.system(size: 15 * ts, weight: .medium, design: .monospaced)).tracking(4)
                    .foregroundStyle(HUD.yellow)
                HStack(alignment: .bottom, spacing: 6) {
                    Text(distance(m.distance).value)
                        .font(.system(size: distSize * ts, weight: .medium, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(HUD.yellow)
                        .shadow(color: HUD.yellow.opacity(0.45), radius: 16)
                    Text(distance(m.distance).unit)
                        .font(.system(size: 26 * ts, weight: .medium, design: .rounded))
                        .foregroundStyle(HUD.yellow)
                }
                Text(m.primary.uppercased())
                    .font(.system(size: 14 * ts, weight: .medium, design: .monospaced)).tracking(3)
                    .foregroundStyle(HUD.teal).lineLimit(1)
            }
        }
    }

    /// Distance to the manoeuvre in the user's units: m / km, or ft / mi in mph mode.
    private func distance(_ d: Double) -> (value: String, unit: String) {
        if model.useMph {
            let feet = d * 3.28084
            if feet >= 1000 { return (String(format: "%.1f", d / 1609.34), "MI") }
            let step = feet < 100 ? 10.0 : 50.0
            return ("\(Int((feet / step).rounded() * step))", "FT")
        }
        if d >= 995 { return (String(format: "%.1f", d / 1000), "KM") }
        return ("\(Int((d / 10).rounded()) * 10)", "M")
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").padding(8).contentShape(Rectangle())
                }
                Spacer()
                Button { model.mirrored.toggle() } label: {
                    Image(systemName: "arrow.left.and.right").padding(8).contentShape(Rectangle())
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 10).padding(.top, 4)
            Spacer()
        }
    }
}

struct LimitRoundel: View {
    let limit: Int?
    var scale: CGFloat = 1
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(HUD.red, lineWidth: 4).frame(width: 50 * scale, height: 50 * scale)
                    .shadow(color: HUD.red.opacity(0.4), radius: 6)
                Text(limit.map(String.init) ?? "--")
                    .font(.system(size: 24 * scale, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text("ZONE\nLIMIT")
                .font(.system(size: 11 * scale, weight: .medium, design: .monospaced)).tracking(1)
                .fixedSize()
                .foregroundStyle(HUD.teal)
        }
    }
}
