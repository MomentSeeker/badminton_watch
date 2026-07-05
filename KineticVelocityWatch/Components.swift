import SwiftUI

struct LiveHeader: View {
    let elapsedSeconds: Int

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(KVColor.lime)
                    .frame(width: 6, height: 6)
                    .telemetryGlow()

                Text("LIVE")
                    .font(KVFont.data(10))
                    .foregroundStyle(KVColor.lime)
            }

            Text(elapsedSeconds.clockString)
                .font(KVFont.data(11, weight: .medium))
                .foregroundStyle(KVColor.text.opacity(0.82))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }
}

struct ScreenTitle: View {
    let english: String
    let chinese: String

    var body: some View {
        VStack(spacing: 2) {
            Text(english)
                .font(KVFont.data(9, weight: .medium))
                .foregroundStyle(KVColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(chinese)
                .font(KVFont.body(11))
                .foregroundStyle(KVColor.text)
        }
        .multilineTextAlignment(.center)
    }
}

struct KineticPageTitle: View {
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(KVFont.headline(15))
                .italic()
                .foregroundStyle(KVColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(KVFont.body(10, weight: .semibold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

struct KineticMetricPill: View {
    let label: String
    let value: String
    let unit: String
    let accent: Color
    var footnote: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(KVFont.data(9, weight: .medium))
                .foregroundStyle(KVColor.muted)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(KVFont.headline(21))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !unit.isEmpty {
                    Text(unit)
                        .font(KVFont.data(9, weight: .medium))
                        .foregroundStyle(KVColor.muted)
                        .lineLimit(1)
                }
            }

            if !footnote.isEmpty {
                Text(footnote)
                    .font(KVFont.data(8, weight: .medium))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(KVColor.surface.opacity(0.80))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.32), lineWidth: 1)
        }
    }
}

struct BodyMetricCapsule: View {
    let label: String
    let value: String
    let unit: String
    let accent: Color
    var footnote: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(KVFont.data(8, weight: .medium))
                .foregroundStyle(KVColor.muted)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(KVFont.headline(20))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !unit.isEmpty {
                    Text(unit)
                        .font(KVFont.data(8, weight: .medium))
                        .foregroundStyle(KVColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if !footnote.isEmpty {
                Text(footnote)
                    .font(KVFont.data(8, weight: .medium))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            KVColor.surface.opacity(0.88),
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.42), lineWidth: 1.2)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 48, height: 48)
                .blur(radius: 18)
                .offset(x: 10, y: -14)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let accent: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(KVFont.data(9, weight: .medium))
                    .foregroundStyle(KVColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 4)

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(KVFont.headline(26))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(unit)
                    .font(KVFont.data(9, weight: .medium))
                    .foregroundStyle(KVColor.muted)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .glassTile(radius: 8, borderColor: accent.opacity(0.28))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 50, height: 50)
                .blur(radius: 18)
                .offset(x: 16, y: -14)
        }
    }
}

struct PerformanceMetric: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let accent: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 25, height: 25)
                    .background(accent.opacity(0.15), in: Circle())

                Spacer()

                Text(subtitle)
                    .font(KVFont.data(8, weight: .medium))
                    .foregroundStyle(accent.opacity(0.78))
            }

            Text(title)
                .font(KVFont.body(10, weight: .semibold))
                .foregroundStyle(KVColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(KVFont.headline(33))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(unit.uppercased())
                    .font(KVFont.data(9, weight: .medium))
                    .foregroundStyle(KVColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.17),
                            KVColor.surface.opacity(0.88),
                            Color.black.opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.44), Color.white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(accent)
                .frame(width: 42, height: 3)
                .padding(.leading, 12)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 72, height: 72)
                .blur(radius: 22)
                .offset(x: 22, y: -22)
        }
    }
}

struct BadmintonMotionBackground: View {
    var body: some View {
        Canvas { context, size in
            let grid = Path { path in
                for y in stride(from: CGFloat(72), through: size.height, by: 58) {
                    path.move(to: CGPoint(x: 24, y: y))
                    path.addLine(to: CGPoint(x: size.width - 24, y: y))
                }
            }
            context.stroke(grid, with: .color(Color.white.opacity(0.045)), lineWidth: 0.7)

            var cyanPath = Path()
            cyanPath.move(to: CGPoint(x: -20, y: size.height * 0.67))
            cyanPath.addCurve(
                to: CGPoint(x: size.width + 30, y: size.height * 0.39),
                control1: CGPoint(x: size.width * 0.22, y: size.height * 0.42),
                control2: CGPoint(x: size.width * 0.60, y: size.height * 0.84)
            )
            context.stroke(cyanPath, with: .color(KVColor.cyan.opacity(0.28)), lineWidth: 2)

            var limePath = Path()
            limePath.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.76))
            limePath.addCurve(
                to: CGPoint(x: size.width * 0.92, y: size.height * 0.58),
                control1: CGPoint(x: size.width * 0.34, y: size.height * 0.56),
                control2: CGPoint(x: size.width * 0.64, y: size.height * 0.86)
            )
            context.stroke(limePath, with: .color(KVColor.lime.opacity(0.12)), lineWidth: 1)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.black,
                    KVColor.background,
                    KVColor.lime.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct StatChip: View {
    let title: String
    let value: Int
    let accent: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value.groupedString)
                    .font(KVFont.headline(17))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(KVFont.body(9, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 44)
        .glassTile(radius: 8, borderColor: accent.opacity(0.30))
    }
}

struct KineticActionTile: View {
    let title: String
    let value: Int
    let accent: Color
    let systemImage: String
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(filled ? Color.black : accent)
                .frame(width: 20, height: 20)
                .background(filled ? Color.black.opacity(0.10) : accent.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value.groupedString)
                    .font(KVFont.headline(16))
                    .foregroundStyle(filled ? Color.black : KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(KVFont.body(8, weight: .semibold))
                    .foregroundStyle(filled ? Color.black : accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(actionFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(filled ? accent.opacity(0.92) : accent.opacity(0.42), lineWidth: filled ? 0.5 : 1.2)
        }
        .shadow(color: accent.opacity(filled ? 0.26 : 0.08), radius: filled ? 10 : 4, x: 0, y: 0)
    }

    private var actionFill: some ShapeStyle {
        if filled {
            return AnyShapeStyle(accent)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    accent.opacity(0.20),
                    KVColor.surface.opacity(0.92),
                    Color.black.opacity(0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct KineticCompactMetricTile: View {
    let title: String
    let value: String
    let unit: String
    let accent: Color
    let systemImage: String
    var footnote: String = ""
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(filled ? Color.black : accent)
                .frame(width: 24, height: 24)
                .background(filled ? Color.black.opacity(0.10) : accent.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(KVFont.headline(15))
                        .foregroundStyle(filled ? Color.black : KVColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .layoutPriority(1)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(KVFont.data(7, weight: .medium))
                            .foregroundStyle(filled ? Color.black.opacity(0.62) : KVColor.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }

                Text(title)
                    .font(KVFont.body(8, weight: .semibold))
                    .foregroundStyle(filled ? Color.black : accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !footnote.isEmpty {
                    Text(footnote)
                        .font(KVFont.data(7, weight: .medium))
                        .foregroundStyle(filled ? Color.black.opacity(0.62) : KVColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tileFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(filled ? accent.opacity(0.92) : accent.opacity(0.42), lineWidth: filled ? 0.5 : 1.2)
        }
        .shadow(color: accent.opacity(filled ? 0.30 : 0.10), radius: filled ? 12 : 5, x: 0, y: 0)
    }

    private var tileFill: some ShapeStyle {
        if filled {
            return AnyShapeStyle(accent)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    KVColor.surface.opacity(0.92),
                    Color.black.opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct SegmentedMetricPanel: View {
    struct Segment: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let unit: String
        let systemImage: String
        let fill: Color?
        let accent: Color
        var footnote: String = ""
    }

    let segments: [Segment]
    var compact: Bool = false
    var dense: Bool = false

    private var frameAccent: Color {
        segments.first?.fill ?? segments.first?.accent ?? KVColor.lime
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                SegmentCell(segment: segment, compact: compact, dense: dense)
            }
        }
        .padding(dense ? 3 : 3)
        .frame(maxWidth: .infinity, minHeight: dense ? 48 : (compact ? 56 : 70))
        .background {
            RoundedRectangle(cornerRadius: compact ? 19 : 24, style: .continuous)
                .fill(KVColor.surface.opacity(0.86))
        }
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 19 : 24, style: .continuous)
                .stroke(frameAccent.opacity(0.22), lineWidth: 1.1)
        }
        .shadow(color: frameAccent.opacity(0.12), radius: 12, x: 0, y: 0)
    }
}

struct BodyMetricTriplet: View {
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let unit: String
        let systemImage: String
        let fill: Color?
        let accent: Color
    }

    let metrics: [Metric]

    private var frameAccent: Color {
        metrics.first(where: { $0.fill != nil })?.fill ?? metrics.first?.accent ?? KVColor.lime
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(metrics) { metric in
                BodyMetricTripletCell(metric: metric)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(KVColor.surface.opacity(0.86))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(frameAccent.opacity(0.22), lineWidth: 1.1)
        }
        .shadow(color: frameAccent.opacity(0.12), radius: 12, x: 0, y: 0)
    }
}

private struct BodyMetricTripletCell: View {
    let metric: BodyMetricTriplet.Metric

    private var isFilled: Bool {
        metric.fill != nil
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                MetricIcon(systemImage: metric.systemImage, accent: metric.accent, filled: isFilled, size: 17, symbolSize: 10)

                Text(metric.title)
                    .font(KVFont.body(6.2, weight: .bold))
                    .foregroundStyle(isFilled ? Color.black : metric.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(metric.value)
                    .font(KVFont.headline(17.5))
                    .foregroundStyle(isFilled ? Color.black : KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.42)
                    .allowsTightening(true)
                    .layoutPriority(1)

                if !metric.unit.isEmpty {
                    Text(metric.unit)
                        .font(KVFont.data(6.2, weight: .bold))
                        .foregroundStyle(isFilled ? Color.black.opacity(0.62) : KVColor.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 48, maxHeight: 50)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cellFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFilled ? Color.white.opacity(0.0) : metric.accent.opacity(0.20), lineWidth: 1)
        }
    }

    private var cellFill: some ShapeStyle {
        if let fill = metric.fill {
            return AnyShapeStyle(fill)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct MetricIcon: View {
    let systemImage: String
    let accent: Color
    let filled: Bool
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(filled ? Color.black.opacity(0.10) : accent.opacity(0.16))

            if systemImage == "effective.timer" {
                EffectiveTimeIcon()
                    .stroke(filled ? Color.black : accent, style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.22)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: symbolSize, weight: .black))
                    .foregroundStyle(filled ? Color.black : accent)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct EffectiveTimeIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.39

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(130),
            endAngle: .degrees(410),
            clockwise: false
        )

        path.move(to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: center.x, y: rect.minY + rect.height * 0.20))

        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.58))
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x + radius * 0.52, y: center.y + radius * 0.34))

        return path
    }
}

struct ActionMetricRow: View {
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let systemImage: String
        let fill: Color?
        let accent: Color
    }

    let metrics: [Metric]

    private var frameAccent: Color {
        metrics.first(where: { $0.fill != nil })?.fill ?? metrics.first?.accent ?? KVColor.lime
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(metrics) { metric in
                ActionMetricCell(metric: metric)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 46)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(KVColor.surface.opacity(0.86))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(frameAccent.opacity(0.24), lineWidth: 1.1)
        }
        .shadow(color: frameAccent.opacity(0.12), radius: 12, x: 0, y: 0)
    }
}

private struct ActionMetricCell: View {
    let metric: ActionMetricRow.Metric

    private var isFilled: Bool {
        metric.fill != nil
    }

    var body: some View {
        ZStack {
            Text(metric.value)
                .font(KVFont.headline(23))
                .foregroundStyle(isFilled ? Color.black : KVColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, 30)
                .padding(.trailing, 3)
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(isFilled ? Color.black : metric.accent)
                    .frame(width: 18, height: 18)
                    .background((isFilled ? Color.black.opacity(0.10) : metric.accent.opacity(0.16)), in: Circle())

                Text(metric.title)
                    .font(KVFont.body(6.2, weight: .bold))
                    .foregroundStyle(isFilled ? Color.black : metric.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 40, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cellFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFilled ? Color.white.opacity(0.0) : metric.accent.opacity(0.20), lineWidth: 1)
        }
    }

    private var cellFill: some ShapeStyle {
        if let fill = metric.fill {
            return AnyShapeStyle(fill)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct SegmentCell: View {
    let segment: SegmentedMetricPanel.Segment
    let compact: Bool
    let dense: Bool

    private var isFilled: Bool {
        segment.fill != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: dense ? 5 : 6) {
            VStack(alignment: .leading, spacing: dense ? 2 : 3) {
                Image(systemName: segment.systemImage)
                    .font(.system(size: dense ? 10 : (compact ? 11 : 13), weight: .black))
                    .foregroundStyle(isFilled ? Color.black : segment.accent)
                    .frame(width: dense ? 18 : (compact ? 19 : 22), height: dense ? 18 : (compact ? 19 : 22))
                    .background((isFilled ? Color.black.opacity(0.10) : segment.accent.opacity(0.16)), in: Circle())

                Text(segment.title)
                    .font(KVFont.body(dense ? 6.2 : (compact ? 6.4 : 8), weight: .bold))
                    .foregroundStyle(isFilled ? Color.black : segment.accent)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.70)

                if !segment.footnote.isEmpty {
                    Text(segment.footnote)
                        .font(KVFont.data(dense ? 5.4 : (compact ? 5.8 : 6), weight: .medium))
                        .foregroundStyle(isFilled ? Color.black.opacity(0.58) : KVColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
            }
            .frame(width: dense ? 29 : (compact ? 31 : 42), alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(segment.value)
                    .font(KVFont.headline(dense ? 17 : (compact ? 20 : 26)))
                    .foregroundStyle(isFilled ? Color.black : KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .allowsTightening(true)
                    .layoutPriority(1)

                if !segment.unit.isEmpty {
                    Text(segment.unit)
                        .font(KVFont.data(dense ? 6.5 : 7.5, weight: .bold))
                        .foregroundStyle(isFilled ? Color.black.opacity(0.64) : KVColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, dense ? 4 : (compact ? 5 : 8))
        .padding(.vertical, dense ? 4 : (compact ? 5 : 8))
        .frame(maxWidth: .infinity, minHeight: dense ? 42 : (compact ? 48 : 60), alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .fill(cellFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 16 : 20, style: .continuous)
                .stroke(isFilled ? Color.white.opacity(0.0) : segment.accent.opacity(0.20), lineWidth: 1)
        }
    }

    private var cellFill: some ShapeStyle {
        if let fill = segment.fill {
            return AnyShapeStyle(fill)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct PageDots: View {
    let selection: LiveTab

    var body: some View {
        HStack(spacing: 5) {
            ForEach(LiveTab.allCases) { tab in
                Capsule()
                    .fill(tab == selection ? Color.white : Color.white.opacity(0.26))
                    .frame(width: tab == selection ? 14 : 5, height: 5)
                    .animation(.snappy(duration: 0.2), value: selection)
            }
        }
    }
}

struct ShuttlecockMark: View {
    var body: some View {
        ZStack {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? KVColor.lime.opacity(0.90) : KVColor.cyan.opacity(0.78))
                    .frame(width: 9, height: 56)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(index - 2) * 17))
            }

            RoundedRectangle(cornerRadius: 3)
                .fill(KVColor.text)
                .frame(width: 38, height: 18)
                .rotationEffect(.degrees(-10))
                .offset(y: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(KVColor.lime.opacity(0.7), lineWidth: 1)
                )
        }
        .frame(width: 96, height: 96)
    }
}

struct TelemetryGridBackground: View {
    var gridColor: Color = KVColor.lime.opacity(0.08)
    var waveColor: Color = KVColor.cyan.opacity(0.22)

    var body: some View {
        Canvas { context, size in
            let grid = Path { path in
                for y in stride(from: CGFloat(24), to: size.height, by: 34) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }

                for x in stride(from: CGFloat(24), to: size.width, by: 34) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
            }

            context.stroke(grid, with: .color(gridColor), lineWidth: 0.6)

            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: size.height * 0.72))
            wave.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.42),
                control1: CGPoint(x: size.width * 0.25, y: size.height * 0.46),
                control2: CGPoint(x: size.width * 0.58, y: size.height * 0.86)
            )
            context.stroke(wave, with: .color(waveColor), lineWidth: 1.2)
        }
    }
}

struct HoldToEndButton: View {
    let action: () -> Void
    @State private var knobOffset: CGFloat = 0
    @State private var isActivated = false

    var body: some View {
        GeometryReader { proxy in
            let knobSize: CGFloat = 30
            let horizontalPadding: CGFloat = 3
            let maxOffset = max(0, proxy.size.width - knobSize - horizontalPadding * 2)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                KVColor.surface.opacity(0.88),
                                Color.black.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        Capsule()
                            .stroke(isActivated ? KVColor.lime.opacity(0.55) : Color.white.opacity(0.16), lineWidth: 1)
                    }

                Capsule()
                    .fill(KVColor.lime.opacity(0.12))
                    .frame(width: knobOffset + knobSize + horizontalPadding)

                HStack(spacing: 3) {
                    Text("滑动结束训练")
                        .font(KVFont.body(10.5, weight: .bold))
                        .foregroundStyle(KVColor.text.opacity(0.96))
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundStyle(KVColor.lime.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 22)
                .opacity(1 - min(0.45, knobOffset / max(maxOffset, 1) * 0.45))

                ZStack {
                    Circle()
                        .fill(KVColor.lime)

                    Image(systemName: isActivated ? "checkmark" : "arrow.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.black)
                }
                .frame(width: knobSize, height: knobSize)
                .offset(x: horizontalPadding + knobOffset)
                .telemetryGlow()
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard !isActivated else { return }
                            knobOffset = min(max(value.translation.width, 0), maxOffset)
                        }
                        .onEnded { _ in
                            let passed = knobOffset > maxOffset * 0.82

                            if passed {
                                isActivated = true
                                withAnimation(.snappy(duration: 0.18)) {
                                    knobOffset = maxOffset
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                    action()
                                    isActivated = false
                                    knobOffset = 0
                                }
                            } else {
                                withAnimation(.snappy(duration: 0.22)) {
                                    knobOffset = 0
                                }
                            }
                        }
                )
            }
            .contentShape(Capsule())
        }
        .frame(height: 34)
    }
}
