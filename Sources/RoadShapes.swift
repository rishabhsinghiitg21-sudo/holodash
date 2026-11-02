import SwiftUI

// Maneuver road schematics, authored in a 200 x 220 design space and scaled to fit.

struct RoadPaths {
    var context: [Path] = []
    var route = Path()
    var head = Path()
    var ring: Path? = nil
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func seg(_ a: CGPoint, _ b: CGPoint) -> Path { var p = Path(); p.move(to: a); p.addLine(to: b); return p }
private func tri(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
    var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: c); p.closeSubpath(); return p
}
private func mirror(_ p: Path) -> Path { p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 200, ty: 0)) }
private func mirrorRoad(_ r: RoadPaths) -> RoadPaths {
    RoadPaths(context: r.context.map(mirror), route: mirror(r.route), head: mirror(r.head), ring: r.ring.map(mirror))
}

func roadPaths(_ d: Maneuver.Dir) -> RoadPaths {
    switch d {
    case .right:
        var r = RoadPaths()
        r.context = [seg(P(80,220),P(94,96)), seg(P(120,220),P(106,96)), seg(P(44,92),P(168,84))]
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,104))
        rt.addQuadCurve(to: P(114,88), control: P(100,90)); rt.addLine(to: P(162,84)); r.route = rt
        r.head = tri(P(150,73), P(178,84), P(150,95)); return r

    case .slightRight:
        var r = RoadPaths()
        r.context = [seg(P(84,220),P(96,96)), seg(P(116,220),P(104,96))]
        var rt = Path(); rt.move(to: P(100,212))
        rt.addCurve(to: P(128,106), control1: P(100,162), control2: P(104,130)); rt.addLine(to: P(152,86)); r.route = rt
        r.head = tri(P(140,74), P(166,82), P(148,102)); return r

    case .forkRight:
        var r = RoadPaths()
        var lb = Path(); lb.move(to: P(98,124)); lb.addCurve(to: P(68,88), control1: P(96,106), control2: P(84,98)); lb.addLine(to: P(44,72))
        r.context = [seg(P(86,220),P(98,124)), seg(P(114,220),P(102,124)), lb]
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,124))
        rt.addCurve(to: P(128,88), control1: P(100,106), control2: P(112,98)); rt.addLine(to: P(154,72)); r.route = rt
        r.head = tri(P(142,60), P(168,72), P(146,92)); return r

    case .exitRight:
        var r = RoadPaths()
        r.context = [seg(P(86,220),P(96,58)), seg(P(114,220),P(104,58)), seg(P(58,60),P(150,56))]
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,150))
        rt.addCurve(to: P(146,110), control1: P(100,126), control2: P(122,116)); rt.addLine(to: P(170,104)); r.route = rt
        r.head = tri(P(158,93), P(184,104), P(158,115)); return r

    case .merge:
        var r = RoadPaths()
        r.context = [seg(P(126,220),P(126,64)), seg(P(152,220),P(152,64))]
        var rt = Path(); rt.move(to: P(68,212))
        rt.addCurve(to: P(118,130), control1: P(80,166), control2: P(98,146)); rt.addLine(to: P(132,92)); r.route = rt
        r.head = tri(P(120,90), P(142,82), P(132,108)); return r

    case .straight:
        var r = RoadPaths()
        r.context = [seg(P(82,220),P(94,80)), seg(P(118,220),P(106,80)), seg(P(60,80),P(140,76))]
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,80)); r.route = rt
        r.head = tri(P(86,88), P(100,60), P(114,88)); return r

    case .uturn:
        var r = RoadPaths()
        r.context = [seg(P(86,220),P(86,124)), seg(P(118,220),P(118,124))]
        var rt = Path(); rt.move(to: P(112,212)); rt.addLine(to: P(112,122))
        rt.addQuadCurve(to: P(82,84), control: P(112,84)); rt.addQuadCurve(to: P(54,122), control: P(54,84)); rt.addLine(to: P(54,182)); r.route = rt
        r.head = tri(P(44,170), P(54,196), P(64,170)); return r

    case .roundabout:
        var r = RoadPaths()
        r.ring = Path(ellipseIn: CGRect(x: 62, y: 58, width: 76, height: 76))
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,136))
        rt.addArc(center: P(100,96), radius: 40, startAngle: .degrees(90), endAngle: .degrees(-48), clockwise: false)
        rt.addLine(to: P(160,46)); r.route = rt
        r.head = tri(P(150,36), P(176,48), P(150,60)); return r

    case .arrive:
        var r = RoadPaths()
        r.context = [seg(P(82,220),P(94,96)), seg(P(118,220),P(106,96))]
        var rt = Path(); rt.move(to: P(100,212)); rt.addLine(to: P(100,100)); r.route = rt
        r.head = Path(ellipseIn: CGRect(x: 88, y: 64, width: 24, height: 24)); return r

    case .left:        return mirrorRoad(roadPaths(.right))
    case .slightLeft:  return mirrorRoad(roadPaths(.slightRight))
    case .forkLeft:    return mirrorRoad(roadPaths(.forkRight))
    case .exitLeft:    return mirrorRoad(roadPaths(.exitRight))
    }
}

struct RoadDiagram: View {
    let kind: Maneuver.Dir

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 200, size.height / 220)
            let ox = (size.width - 200 * s) / 2
            let oy = (size.height - 220 * s) / 2
            let t = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: ox, ty: oy)
            let r = roadPaths(kind)

            for c in r.context {
                ctx.stroke(c.applying(t), with: .color(HUD.teal.opacity(0.22)),
                           style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            }
            if let ring = r.ring {
                ctx.stroke(ring.applying(t), with: .color(HUD.teal.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
            }
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: HUD.yellow.opacity(0.5), radius: 8 * s))
                layer.stroke(r.route.applying(t), with: .color(HUD.yellow),
                             style: StrokeStyle(lineWidth: 9 * s, lineCap: .round, lineJoin: .round))
                layer.fill(r.head.applying(t), with: .color(HUD.yellow))
            }
            ctx.fill(tri(P(92,214), P(100,200), P(108,214)).applying(t), with: .color(HUD.teal))
        }
    }
}

struct SpeedTape: View {
    let speed: Int
    let unit: String
    let over: Bool
    var scale: CGFloat = 1
    private var c: Color { over ? HUD.red : HUD.teal }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Canvas { ctx, size in
                let n = 11
                for i in 0..<n {
                    let y = size.height * CGFloat(i) / CGFloat(n - 1)
                    let major = i % 2 == 0
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: major ? 18 : 10, y: y))
                    ctx.stroke(p, with: .color(HUD.teal.opacity(major ? 0.5 : 0.28)), lineWidth: 2)
                }
                let my = size.height * 0.5
                var m = Path()
                m.move(to: CGPoint(x: 22, y: my - 7)); m.addLine(to: CGPoint(x: 22, y: my + 7)); m.addLine(to: CGPoint(x: 9, y: my)); m.closeSubpath()
                ctx.fill(m, with: .color(c))
            }
            .frame(width: 24, height: 128 * scale)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(speed)")
                    .font(.system(size: 52 * scale, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(c)
                    .shadow(color: c.opacity(0.4), radius: 10)
                Text(unit)
                    .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(c.opacity(0.8))
            }
        }
    }
}
