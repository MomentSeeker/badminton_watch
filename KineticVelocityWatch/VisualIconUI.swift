import SwiftUI

enum KineticUIConfig {
    static var useVisualIconUI: Bool {
        let raw = ProcessInfo.processInfo.environment["KV_USE_VISUAL_UI"]
        if raw == "0" { return false }
        return true
    }
}

private enum VisualToken {
    static let bg = Color(red: 0.02, green: 0.03, blue: 0.02)
    static let white = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let muted = Color(red: 0.45, green: 0.46, blue: 0.43)
    static let lime = Color(red: 0.84, green: 1.0, blue: 0.0)
    static let green = Color(red: 0.62, green: 1.0, blue: 0.0)
    static let orange = Color(red: 1.0, green: 0.68, blue: 0.09)
    static let panel = Color(red: 0.04, green: 0.06, blue: 0.04)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

struct VisualIconLiveSessionView: View {
    @EnvironmentObject private var store: TrainingSessionStore

    var body: some View {
        ZStack {
            VisualBackground()

            Group {
                switch store.activeTab {
                case .body:
                    VisualBodyLoadView(session: store.session)
                case .badminton:
                    VisualBadmintonDataView(session: store.session)
                case .action:
                    VisualActionMapView(session: store.session) {
                        store.requestEndConfirmation()
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            PageDots(selection: store.activeTab)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 9)
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -30 {
                        moveTab(by: 1)
                    } else if value.translation.width > 30 {
                        moveTab(by: -1)
                    }
                }
        )
        .animation(.snappy(duration: 0.18), value: store.activeTab)
        .ignoresSafeArea(.all)
    }

    private func moveTab(by delta: Int) {
        let nextRaw = min(max(store.activeTab.rawValue + delta, 0), LiveTab.allCases.count - 1)
        if let next = LiveTab(rawValue: nextRaw) {
            store.activeTab = next
        }
    }
}

private struct VisualBackground: View {
    var body: some View {
        ZStack {
            VisualToken.bg.ignoresSafeArea(.all)

            Canvas { context, size in
                var grid = Path()
                for x in stride(from: CGFloat(24), through: size.width, by: 34) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: CGFloat(36), through: size.height, by: 34) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(VisualToken.lime.opacity(0.08)), lineWidth: 0.6)

                var wave = Path()
                wave.move(to: CGPoint(x: -20, y: size.height * 0.70))
                wave.addCurve(
                    to: CGPoint(x: size.width + 36, y: size.height * 0.37),
                    control1: CGPoint(x: size.width * 0.22, y: size.height * 0.46),
                    control2: CGPoint(x: size.width * 0.62, y: size.height * 0.86)
                )
                context.stroke(wave, with: .color(VisualToken.lime.opacity(0.16)), lineWidth: 1.0)
            }
        }
    }
}

private struct VisualCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 204, proxy.size.height / 248)
            ZStack {
                content()
            }
            .frame(width: 204, height: 248)
            .scaleEffect(scale, anchor: .center)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct VisualTopBar: View {
    let title: String
    var showsMenu: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(VisualToken.title(10.5))
                .foregroundStyle(VisualToken.white)
                .tracking(0.3)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(width: 160)
    }
}

private struct VisualIcon: View {
    enum Kind {
        case heart, stopwatch, clock, flame, shuttlecock, speedometer, chain, bolt
        case arrowUpRight, arrowDownRight, arrowRight, arrowLeft, runner
    }

    let kind: Kind
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch kind {
            case .shuttlecock:
                ShuttlecockLineIcon(color: color)
            case .bolt:
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
            case .heart:
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
            case .stopwatch:
                Image(systemName: "stopwatch")
                    .resizable()
                    .scaledToFit()
            case .clock:
                Image(systemName: "clock")
                    .resizable()
                    .scaledToFit()
            case .flame:
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
            case .speedometer:
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .resizable()
                    .scaledToFit()
            case .chain:
                Image(systemName: "link")
                    .resizable()
                    .scaledToFit()
            case .arrowUpRight:
                Image(systemName: "arrow.up.right")
                    .resizable()
                    .scaledToFit()
            case .arrowDownRight:
                Image(systemName: "arrow.down.right")
                    .resizable()
                    .scaledToFit()
            case .arrowRight:
                Image(systemName: "arrow.right")
                    .resizable()
                    .scaledToFit()
            case .arrowLeft:
                Image(systemName: "arrow.left")
                    .resizable()
                    .scaledToFit()
            case .runner:
                Image(systemName: "figure.run")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.48), radius: 5, x: 0, y: 0)
    }
}

private struct ShuttlecockLineIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                Capsule()
                    .stroke(color, lineWidth: 2.1)
                    .frame(width: 5, height: 27)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(index) * 13 - 19))
            }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(color, lineWidth: 2)
                .frame(width: 18, height: 11)
                .rotationEffect(.degrees(-18))
                .offset(x: -9, y: 15)
        }
        .frame(width: 42, height: 42)
    }
}

private struct VisualBodyLoadView: View {
    let session: TrainingSession

    private var ringProgress: CGFloat {
        CGFloat(min(max(session.heartZone ?? 0, 0), 5)) / 5.0
    }

    var body: some View {
        VisualCanvas {
            VisualTopBar(title: "BODY LOAD")
                .position(x: 99, y: 24)

            VisualIcon(kind: .heart, color: VisualToken.lime, size: 24)
                .position(x: 49, y: 46)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: max(ringProgress, 0.12))
                    .stroke(
                        LinearGradient(
                            colors: [VisualToken.green, VisualToken.lime],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: VisualToken.lime.opacity(0.72), radius: 8, x: 0, y: 0)

                VStack(spacing: 1) {
                    Text(session.currentHeartRate.map(String.init) ?? "--")
                        .font(VisualToken.number(38))
                        .foregroundStyle(VisualToken.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("BPM")
                        .font(VisualToken.title(9))
                        .foregroundStyle(VisualToken.lime)

                    Text(session.heartZone.map { "Z\($0)" } ?? "Z--")
                        .font(VisualToken.title(10))
                        .foregroundStyle(VisualToken.lime)
                        .padding(.top, 6)
                }
            }
            .frame(width: 105, height: 105)
            .position(x: 102, y: 117)

            HStack(spacing: 14) {
                VisualMetricCard(kind: .stopwatch, value: session.activeSeconds.compactClockString, tint: VisualToken.green)
                VisualMetricCard(kind: .clock, value: session.elapsedSeconds.compactClockString, tint: VisualToken.lime)
                VisualMetricCard(kind: .flame, value: "\(session.calories)", tint: VisualToken.orange, orange: true)
            }
            .position(x: 102, y: 199)
        }
    }
}

private struct VisualMetricCard: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color
    var orange: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            VisualIcon(kind: kind, color: tint, size: 17)
                .padding(.top, 5)

            Text(value)
                .font(VisualToken.number(13.5))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)

            Capsule()
                .fill(tint)
                .frame(width: 14, height: 2.5)
        }
        .frame(width: 47, height: 43)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((orange ? VisualToken.orange : VisualToken.lime).opacity(orange ? 0.10 : 0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(orange ? 0.30 : 0.26), lineWidth: 1)
        }
    }
}

private struct VisualBadmintonDataView: View {
    let session: TrainingSession

    var body: some View {
        VisualCanvas {
            VisualTopBar(title: "BADMINTON", showsMenu: true)
                .position(x: 102, y: 24)

            Circle()
                .fill(VisualToken.lime.opacity(0.12))
                .frame(width: 145, height: 145)
                .blur(radius: 20)
                .position(x: 102, y: 128)

            VisualIcon(kind: .shuttlecock, color: VisualToken.lime, size: 40)
                .position(x: 102, y: 63)

            VStack(spacing: 4) {
                Text(session.swingCount.groupedString)
                    .font(VisualToken.number(46))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.44)
                    .allowsTightening(true)
                    .frame(width: 164)

                Text("SWINGS")
                    .font(VisualToken.title(11))
                    .foregroundStyle(VisualToken.lime)
                    .tracking(0.8)
            }
            .position(x: 102, y: 130)

            HStack(spacing: 20) {
                VisualMetricPill(kind: .speedometer, value: "\(session.maxSwingSpeedKph)", tint: VisualToken.lime)
                VisualMetricPill(kind: .chain, value: "\(session.maxRallyStreak)", tint: VisualToken.orange, orange: true)
            }
            .position(x: 102, y: 198)
        }
    }
}

private struct VisualMetricPill: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color
    var orange: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            VisualIcon(kind: kind, color: tint, size: 24)
                .frame(width: 30)

            Text(value)
                .font(VisualToken.number(14))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.48)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
        .frame(width: 73, height: 42)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill((orange ? VisualToken.orange : VisualToken.lime).opacity(orange ? 0.10 : 0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(tint.opacity(orange ? 0.30 : 0.26), lineWidth: 1)
        }
    }
}

private struct VisualActionMapView: View {
    let session: TrainingSession
    let onEnd: () -> Void

    var body: some View {
        VisualCanvas {
            VisualTopBar(title: "ACTION MAP", showsMenu: true)
                .position(x: 102, y: 24)

            HStack(alignment: .center, spacing: 7) {
                VisualIcon(kind: .bolt, color: VisualToken.lime, size: 29)

                Text(session.smashCount.groupedString)
                    .font(VisualToken.number(32))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .allowsTightening(true)
            }
            .position(x: 102, y: 74)

            Text("SMASHES")
                .font(VisualToken.title(10))
                .foregroundStyle(VisualToken.lime)
                .tracking(0.8)
                .position(x: 102, y: 103)

            HStack(spacing: 14) {
                VisualActionDot(kind: .arrowUpRight, value: session.overheadCount.groupedString, tint: VisualToken.green)
                VisualActionDot(kind: .arrowDownRight, value: session.underhandCount.groupedString, tint: VisualToken.lime)
                VisualActionDot(kind: .arrowRight, value: session.forehandCount.groupedString, tint: VisualToken.orange, orange: true)
                VisualActionDot(kind: .arrowLeft, value: session.backhandCount.groupedString, tint: VisualToken.orange, orange: true)
            }
            .position(x: 102, y: 146)

            Rectangle()
                .fill(VisualToken.white.opacity(0.16))
                .frame(width: 154, height: 1)
                .position(x: 102, y: 185)

            Button(action: onEnd) {
                HStack(spacing: 10) {
                    VisualIcon(kind: .runner, color: VisualToken.lime, size: 19)

                    Text("训练结束")
                        .font(VisualToken.title(13))
                        .foregroundStyle(VisualToken.white)
                }
                .frame(width: 158, height: 29)
                .background(VisualToken.green.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(VisualToken.lime.opacity(0.26), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .position(x: 102, y: 211)
        }
    }
}

private struct VisualActionDot: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color
    var orange: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .overlay {
                        Circle()
                            .stroke(tint.opacity(0.36), lineWidth: 1)
                    }

                VisualIcon(kind: kind, color: tint, size: 23)
            }
            .frame(width: 31, height: 31)

            Text(value)
                .font(VisualToken.number(12))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.44)
                .allowsTightening(true)
                .frame(width: 38)

            Capsule()
                .fill(tint)
                .frame(width: 16, height: 2.5)
        }
    }
}
