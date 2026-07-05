import SwiftUI

enum KineticUIConfig {
    static var useVisualIconUI: Bool {
        let raw = ProcessInfo.processInfo.environment["KV_USE_VISUAL_UI"]
        return raw == "1"
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
        Color.black.ignoresSafeArea(.all)
    }
}

private struct VisualCanvas<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 204, proxy.size.height / 240)
            ZStack {
                content()
            }
            .frame(width: 204, height: 240)
            .scaleEffect(scale, anchor: .center)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct VisualStatusBar: View {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { timeline in
            ZStack {
                Text(Self.timeFormatter.string(from: timeline.date))
                    .font(VisualToken.title(14))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .position(x: 25, y: 16)

                VisualMenuDots()
                    .position(x: 180, y: 16)
            }
        }
        .frame(width: 204, height: 32)
    }
}

private struct VisualMenuDots: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 26, height: 26)

            VisualSvgAsset(name: "svg_clean_common_menu_ellipsis", size: 20, shadowColor: .clear, shadowRadius: 0)
        }
    }
}

private struct VisualUnitText: View {
    let text: String
    var size: CGFloat = 10

    var body: some View {
        Text(text)
            .font(VisualToken.title(size))
            .foregroundStyle(VisualToken.lime)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

private struct VisualGlowPanel<S: Shape>: View {
    let shape: S
    let tint: Color
    var opacity: Double = 0.10

    var body: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(opacity + 0.06),
                        tint.opacity(opacity * 0.42),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .stroke(tint.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.20), radius: 12, x: 0, y: 0)
    }
}

private struct VisualMetricBubble: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color

    var body: some View {
        ZStack {
            VisualGlowPanel(shape: Circle(), tint: tint, opacity: 0.045)
                .frame(width: 51, height: 51)

            VStack(spacing: 3) {
                VisualIcon(kind: kind, color: tint, size: 25)
                    .frame(height: 24)

                Text(value)
                    .font(VisualToken.number(13.5))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .allowsTightening(true)
                    .frame(width: 44)
            }
            .padding(.top, 2)
        }
        .frame(width: 54, height: 54)
    }
}

private struct VisualNumberBlock: View {
    let value: String
    let unit: String
    var numberSize: CGFloat
    var unitSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(VisualToken.number(numberSize))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.38)
                .allowsTightening(true)

            VisualUnitText(text: unit, size: unitSize)
        }
    }
}

private struct VisualArcRange: View {
    let from: CGFloat
    let to: CGFloat
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .shadow(color: color.opacity(0.55), radius: 8, x: 0, y: 0)
    }
}

private struct VisualZoneRing: View {
    let zone: Int?

    private var progress: CGFloat {
        CGFloat(min(max(zone ?? 3, 1), 5)) / 5.0
    }

    private var hotTint: Color {
        switch zone ?? 3 {
        case 1...2:
            return VisualToken.green
        case 3:
            return VisualToken.lime
        default:
            return VisualToken.orange
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 9.5)

            VisualArcRange(from: 0.54, to: 0.78, color: VisualToken.green, lineWidth: 9.5)

            VisualArcRange(
                from: 0.0,
                to: max(0.14, progress),
                color: hotTint,
                lineWidth: 9.5
            )
        }
    }
}

private struct VisualIconPill: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color
    var showsDot: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            VisualIcon(kind: kind, color: tint, size: 34)
                .frame(width: 39, height: 34)

            Text(value)
                .font(VisualToken.number(16))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
        .frame(width: 96, height: 58)
        .background {
            VisualGlowPanel(
                shape: RoundedRectangle(cornerRadius: 15, style: .continuous),
                tint: tint,
                opacity: 0.075
            )
        }
        .overlay(alignment: .topLeading) {
            if showsDot {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 9)
                    .padding(.top, 6)
            }
        }
    }
}

private struct VisualEndButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VisualSvgAsset(name: "svg_clean_action_runner_button", size: 36, shadowColor: VisualToken.lime)

                Text("训练结束")
                    .font(VisualToken.title(15))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 190, height: 42)
            .background {
                VisualGlowPanel(
                    shape: Capsule(),
                    tint: VisualToken.lime,
                    opacity: 0.075
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct VisualActionGlyph: View {
    let kind: VisualIcon.Kind
    let value: String
    let tint: Color

    private var legendAssetName: String {
        switch kind {
        case .arrowUpRight:
            return "svg_clean_action_arrow_up_right_legend"
        case .arrowDownRight:
            return "svg_clean_action_arrow_down_right_legend"
        case .arrowRight:
            return "svg_clean_action_arrow_right_legend"
        case .arrowLeft:
            return "svg_clean_action_arrow_left_legend"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                VisualGlowPanel(shape: Circle(), tint: tint, opacity: 0.12)
                    .frame(width: 34, height: 34)

                VisualSvgAsset(name: legendAssetName, size: 28, shadowColor: tint)
            }

            Text(value)
                .font(VisualToken.number(12.5))
                .foregroundStyle(VisualToken.white)
                .lineLimit(1)
                .minimumScaleFactor(0.46)
                .allowsTightening(true)
                .frame(width: 38)
        }
        .frame(width: 44)
    }
}

private struct VisualSmashHeader: View {
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            HStack(alignment: .center, spacing: 8) {
                VisualSvgAsset(name: "svg_clean_action_lightning_main", size: 43, shadowColor: VisualToken.lime)

                Text(value)
                    .font(VisualToken.number(40))
                    .foregroundStyle(VisualToken.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.36)
                    .allowsTightening(true)
                    .frame(maxWidth: 116, alignment: .leading)
            }

            VisualUnitText(text: "SMASHES", size: 11)
                .padding(.leading, 29)
        }
    }
}

private struct VisualLoadLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(VisualToken.green).frame(width: 18, height: 5)
            Capsule().fill(VisualToken.lime).frame(width: 18, height: 5)
            Capsule().fill(VisualToken.orange).frame(width: 18, height: 5)
        }
    }
}

private struct VisualDataAura: View {
    let tint: Color

    var body: some View {
        Circle()
            .fill(tint.opacity(0.11))
            .frame(width: 152, height: 152)
            .blur(radius: 24)
    }
}

private struct VisualSeparator: View {
    var body: some View {
        Rectangle()
            .fill(VisualToken.white.opacity(0.18))
            .frame(width: 162, height: 1)
    }
}

private struct VisualStatusMetricRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .frame(width: 172)
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
                VisualSvgAsset(name: "svg_clean_badminton_shuttle_main", size: size, shadowColor: color)
            case .bolt:
                VisualSvgAsset(name: "svg_clean_action_lightning_main", size: size, shadowColor: color)
            case .heart:
                VisualSvgAsset(name: "svg_clean_body_heart_main", size: size, shadowColor: color)
            case .stopwatch:
                VisualSvgAsset(name: "svg_clean_body_stopwatch_card", size: size, shadowColor: color)
            case .clock:
                VisualSvgAsset(name: "svg_clean_body_clock_card", size: size, shadowColor: color)
            case .flame:
                VisualSvgAsset(name: "svg_clean_body_flame_card", size: size, shadowColor: color)
            case .speedometer:
                VisualSvgAsset(name: "svg_clean_badminton_speedometer_card", size: size, shadowColor: color)
            case .chain:
                VisualSvgAsset(name: "svg_clean_badminton_chain_card", size: size, shadowColor: color)
            case .arrowUpRight:
                VisualSvgAsset(name: "svg_clean_action_arrow_up_right_legend", size: size, shadowColor: color)
            case .arrowDownRight:
                VisualSvgAsset(name: "svg_clean_action_arrow_down_right_legend", size: size, shadowColor: color)
            case .arrowRight:
                VisualSvgAsset(name: "svg_clean_action_arrow_right_legend", size: size, shadowColor: color)
            case .arrowLeft:
                VisualSvgAsset(name: "svg_clean_action_arrow_left_legend", size: size, shadowColor: color)
            case .runner:
                VisualSvgAsset(name: "svg_clean_action_runner_button", size: size, shadowColor: color)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct VisualSvgAsset: View {
    let name: String
    let size: CGFloat
    var shadowColor: Color = VisualToken.lime
    var shadowRadius: CGFloat = 5

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: shadowColor.opacity(0.48), radius: shadowRadius, x: 0, y: 0)
    }
}

private struct ShuttlecockLineIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                ShuttleFeather(index: index)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(color, lineWidth: 2)
                .frame(width: 18, height: 13)
                .rotationEffect(.degrees(22))
                .offset(x: -9, y: 14)
        }
        .frame(width: 42, height: 42)
    }
}

private struct ShuttleFeather: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let roots = [
            CGPoint(x: rect.midX - 5, y: rect.maxY - 15),
            CGPoint(x: rect.midX - 1, y: rect.maxY - 16),
            CGPoint(x: rect.midX + 3, y: rect.maxY - 17)
        ]
        let tips = [
            CGPoint(x: rect.midX - 16, y: rect.minY + 8),
            CGPoint(x: rect.midX - 3, y: rect.minY + 3),
            CGPoint(x: rect.midX + 11, y: rect.minY + 9)
        ]
        let widths: [CGFloat] = [9, 10, 8]

        let root = roots[index]
        let tip = tips[index]
        let width = widths[index]
        var path = Path()
        path.move(to: root)
        path.addLine(to: CGPoint(x: tip.x - width * 0.35, y: tip.y + 9))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x + width * 0.55, y: tip.y + 11))
        path.closeSubpath()
        return path
    }
}

private struct SpeedometerLineIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.52, to: 0.98)
                .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                .rotationEffect(.degrees(90))

            Path { path in
                path.move(to: CGPoint(x: 21, y: 24))
                path.addLine(to: CGPoint(x: 30, y: 15))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .position(x: 21, y: 24)
        }
        .frame(width: 42, height: 42)
    }
}

private struct VisualBodyLoadView: View {
    let session: TrainingSession

    var body: some View {
        VisualCanvas {
            VisualStatusBar()
                .position(x: 102, y: 17)

            VisualIcon(kind: .heart, color: VisualToken.lime, size: 29)
                .position(x: 102, y: 54)

            ZStack {
                VisualZoneRing(zone: session.heartZone)

                VStack(spacing: 1) {
                    Text(session.currentHeartRate.map(String.init) ?? "--")
                        .font(VisualToken.number(55))
                        .foregroundStyle(VisualToken.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    VisualUnitText(text: "BPM", size: 9)

                    VisualUnitText(text: session.heartZone.map { "Z\($0)" } ?? "Z--", size: 10)
                        .padding(.top, 6)
                }
            }
            .frame(width: 154, height: 154)
            .position(x: 102, y: 98)

            VisualStatusMetricRow {
                VisualMetricBubble(kind: .stopwatch, value: session.activeSeconds.compactClockString, tint: VisualToken.green)
                VisualMetricBubble(kind: .clock, value: session.elapsedSeconds.compactClockString, tint: VisualToken.lime)
                VisualMetricBubble(kind: .flame, value: "\(session.calories)", tint: VisualToken.orange)
            }
            .position(x: 102, y: 200)
        }
    }
}

private struct VisualBadmintonDataView: View {
    let session: TrainingSession

    var body: some View {
        VisualCanvas {
            VisualStatusBar()
                .position(x: 102, y: 17)

            VisualDataAura(tint: VisualToken.lime)
                .position(x: 102, y: 112)

            VisualIcon(kind: .shuttlecock, color: VisualToken.lime, size: 54)
                .position(x: 102, y: 41)

            VisualNumberBlock(
                value: session.swingCount.groupedString,
                unit: "SWINGS",
                numberSize: 66,
                unitSize: 15
            )
            .frame(width: 178)
            .position(x: 102, y: 110)

            HStack(spacing: 8) {
                VisualIconPill(kind: .speedometer, value: "\(session.maxSwingSpeedKph)", tint: VisualToken.lime)
                VisualIconPill(kind: .chain, value: "\(session.maxRallyStreak)", tint: VisualToken.orange, showsDot: true)
            }
            .position(x: 102, y: 198)
        }
    }
}

private struct VisualActionMapView: View {
    let session: TrainingSession
    let onEnd: () -> Void

    var body: some View {
        VisualCanvas {
            VisualStatusBar()
                .position(x: 102, y: 17)

            VisualSmashHeader(value: session.smashCount.groupedString)
                .position(x: 102, y: 65)

            HStack(spacing: 8) {
                VisualActionGlyph(kind: .arrowUpRight, value: session.overheadCount.groupedString, tint: VisualToken.green)
                VisualActionGlyph(kind: .arrowDownRight, value: session.underhandCount.groupedString, tint: VisualToken.lime)
                VisualActionGlyph(kind: .arrowRight, value: session.forehandCount.groupedString, tint: VisualToken.orange)
                VisualActionGlyph(kind: .arrowLeft, value: session.backhandCount.groupedString, tint: VisualToken.orange)
            }
            .position(x: 102, y: 136)

            VisualSeparator()
                .position(x: 102, y: 172)

            VisualEndButton(action: onEnd)
                .position(x: 102, y: 207)
        }
    }
}
