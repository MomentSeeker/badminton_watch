import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TrainingSessionStore

    var body: some View {
        ZStack {
            KVColor.background.ignoresSafeArea(.all)

            switch store.state {
            case .idle:
                StartSetupView()
            case .recording:
                if KineticUIConfig.useVisualIconUI {
                    VisualIconLiveSessionView()
                } else {
                    LiveSessionView()
                }
            case .pendingEndConfirm:
                EndConfirmView()
            case .saving:
                SavingView()
            case .saved:
                SavedView()
            case .calibrating:
                CalibrationDebugView(
                    store: store.calibrationStore,
                    onExit: {
                        store.exitCalibration()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

struct StartSetupView: View {
    @EnvironmentObject private var store: TrainingSessionStore

    var body: some View {
        ZStack {
            TelemetryGridBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(height: 8)

                ZStack {
                    Circle()
                        .fill(KVColor.lime.opacity(0.17))
                        .frame(width: 88, height: 88)
                        .blur(radius: 20)

                    ShuttlecockMark()
                        .rotationEffect(.degrees(-14))
                        .telemetryGlow()
                        .scaleEffect(0.74)
                }
                .frame(height: 76)
                .onLongPressGesture(minimumDuration: 1.2) {
                    store.enterCalibration()
                }

                Text("KINETIC VELOCITY")
                    .font(KVFont.headline(17))
                    .italic()
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 4)

                Text(store.racketHand.chineseTitle)
                    .font(KVFont.body(10, weight: .semibold))
                    .foregroundStyle(KVColor.muted)
                    .padding(.top, 1)

                RacketHandSelector(selection: $store.racketHand)
                    .padding(.top, 9)

                Button {
                    store.start()
                } label: {
                    Text("TAP TO BEGIN")
                        .font(KVFont.headline(13))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(KVColor.lime, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .telemetryGlow()
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.horizontal, 16)

                Spacer(minLength: 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all)
    }
}

struct RacketHandSelector: View {
    @Binding var selection: RacketHand
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let padding: CGFloat = 4
            let segmentWidth = max(1, (proxy.size.width - padding * 2) / 2)
            let baseOffset = selection == .left ? CGFloat(0) : segmentWidth
            let sliderOffset = min(max(baseOffset + dragTranslation, 0), segmentWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(KVColor.surface.opacity(0.82))
                    .overlay {
                        Capsule()
                            .stroke(KVColor.lime.opacity(0.20), lineWidth: 1)
                    }

                Capsule()
                    .fill(KVColor.lime)
                    .frame(width: segmentWidth, height: 34)
                    .offset(x: padding + sliderOffset)
                    .telemetryGlow(KVColor.lime)

                HStack(spacing: 0) {
                    racketHandOption(.left)
                        .frame(width: segmentWidth, height: 34)
                        .contentShape(Capsule())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.18)) {
                                selection = .left
                            }
                        }

                    racketHandOption(.right)
                        .frame(width: segmentWidth, height: 34)
                        .contentShape(Capsule())
                        .onTapGesture {
                            withAnimation(.snappy(duration: 0.18)) {
                                selection = .right
                            }
                        }
                }
                .padding(.horizontal, padding)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let projectedOffset = baseOffset + value.translation.width
                        withAnimation(.snappy(duration: 0.18)) {
                            selection = projectedOffset > segmentWidth / 2 ? .right : .left
                        }
                    }
            )
        }
        .frame(height: 42)
        .frame(maxWidth: 160)
    }

    private func racketHandOption(_ hand: RacketHand) -> some View {
        let isSelected = selection == hand

        return HStack(spacing: 5) {
            Image(systemName: hand == .left ? "hand.raised.fill" : "hand.raised")
                .font(.system(size: 14, weight: .bold))
                .scaleEffect(x: hand == .left ? -1 : 1, y: 1)

            Text(hand.shortTitle)
                .font(KVFont.data(11))
        }
        .foregroundStyle(isSelected ? Color.black : KVColor.muted)
    }
}

struct LiveSessionView: View {
    @EnvironmentObject private var store: TrainingSessionStore

    var body: some View {
        ZStack {
            KVColor.background.ignoresSafeArea(.all)
            TelemetryGridBackground(
                gridColor: KVColor.lime.opacity(0.08),
                waveColor: KVColor.load.opacity(0.16)
            )

            Group {
                switch store.activeTab {
                case .body:
                    BodyTelemetryView(session: store.session)
                case .badminton:
                    BadmintonDataView(session: store.session)
                case .action:
                    ActionStatsView(session: store.session) {
                        store.requestEndConfirmation()
                    }
                }
            }
            .padding(.top, 22)
            .padding(.bottom, store.activeTab == .action ? 8 : (store.activeTab == .body ? 22 : 24))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
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

struct BodyTelemetryView: View {
    let session: TrainingSession

    var zoneColor: Color {
        switch session.heartZone ?? 0 {
        case 1: return KVColor.cyan
        case 2: return KVColor.lime
        case 3: return KVColor.amber
        case 4: return .orange
        default: return KVColor.pink
        }
    }

    var body: some View {
        let primaryAccent = KVColor.lime
        let ringAccent = KVColor.load

        VStack(spacing: 5) {
            KineticPageTitle(title: "BODY LOAD", subtitle: "体能负荷", accent: ringAccent)
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            ZStack {
                Circle()
                    .stroke(KVColor.surfaceHigh.opacity(0.84), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: CGFloat(min(max(session.heartZone ?? 0, 0), 5)) / 5.0)
                    .stroke(ringAccent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .telemetryGlow(ringAccent)

                VStack(spacing: 0) {
                    Text("HR")
                        .font(KVFont.data(10, weight: .medium))
                        .foregroundStyle(KVColor.muted)

                    Text(session.currentHeartRate.map(String.init) ?? "--")
                        .font(KVFont.headline(41))
                        .foregroundStyle(KVColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("BPM  \(session.heartZone.map { "Z\($0)" } ?? "Z--")")
                        .font(KVFont.data(9, weight: .medium))
                        .foregroundStyle(ringAccent)
                }
            }
            .frame(width: 102, height: 102)
            .padding(.bottom, 7)

            BodyMetricTriplet(
                metrics: [
                    .init(title: "有效", value: session.activeSeconds.compactClockString, unit: "", systemImage: "effective.timer", fill: nil, accent: primaryAccent),
                    .init(title: "总时长", value: session.elapsedSeconds.compactClockString, unit: "", systemImage: "timer", fill: primaryAccent, accent: primaryAccent),
                    .init(title: "卡路里", value: "\(session.calories)", unit: "", systemImage: "flame.fill", fill: nil, accent: KVColor.load)
                ]
            )
            .padding(.horizontal, 12)
            .padding(.top, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct BadmintonDataView: View {
    let session: TrainingSession

    var body: some View {
        ZStack {
            Circle()
                .fill(KVColor.lime.opacity(0.12))
                .frame(width: 170, height: 170)
                .blur(radius: 34)
                .offset(x: 112, y: 118)

            Circle()
                .fill(KVColor.cyan.opacity(0.12))
                .frame(width: 150, height: 150)
                .blur(radius: 32)
                .offset(x: -116, y: 88)

            VStack(spacing: 0) {
                KineticPageTitle(title: "BADMINTON", subtitle: "羽毛球数据", accent: KVColor.lime)
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

                VStack(spacing: -3) {
                    Text(session.swingCount.groupedString)
                        .font(KVFont.headline(68))
                        .foregroundStyle(KVColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.42)
                        .allowsTightening(true)
                        .frame(width: 188)

                    Text("SWINGS / 本场挥拍")
                        .font(KVFont.data(11, weight: .medium))
                        .foregroundStyle(KVColor.lime)
                }
                .padding(.bottom, 16)

                SegmentedMetricPanel(segments: [
                    .init(
                        title: "最大挥速",
                        value: "\(session.maxSwingSpeedKph)",
                        unit: "",
                        systemImage: "gauge.with.dots.needle.67percent",
                        fill: KVColor.load,
                        accent: KVColor.load
                    ),
                    .init(
                        title: "最长连拍",
                        value: "\(session.maxRallyStreak)",
                        unit: "",
                        systemImage: "repeat",
                        fill: nil,
                        accent: KVColor.courtAmber
                    )
                ], compact: true)
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all)
    }
}

struct ActionStatsView: View {
    let session: TrainingSession
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            KineticPageTitle(title: "ACTION MAP", subtitle: "动作统计", accent: KVColor.lime)
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(KVColor.lime)

                Text(session.smashCount.groupedString)
                    .font(KVFont.headline(29))
                    .foregroundStyle(KVColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Text("SMASHES / 杀球")
                    .font(KVFont.body(9.5, weight: .black))
                    .foregroundStyle(KVColor.lime)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
            }
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.top, -2)

            VStack(spacing: 3) {
                ActionMetricRow(metrics: [
                    .init(
                        title: "上手球",
                        value: session.overheadCount.groupedString,
                        systemImage: "arrow.up.right",
                        fill: KVColor.load,
                        accent: KVColor.load
                    ),
                    .init(
                        title: "下手球",
                        value: session.underhandCount.groupedString,
                        systemImage: "arrow.down.right",
                        fill: nil,
                        accent: KVColor.load
                    )
                ])

                ActionMetricRow(metrics: [
                    .init(
                        title: "正手击球",
                        value: session.forehandCount.groupedString,
                        systemImage: "arrow.right",
                        fill: KVColor.courtAmber,
                        accent: KVColor.courtAmber
                    ),
                    .init(
                        title: "反手击球",
                        value: session.backhandCount.groupedString,
                        systemImage: "arrow.left",
                        fill: nil,
                        accent: KVColor.courtAmber
                    )
                ])
            }
            .padding(.horizontal, 10)

            HoldToEndButton(action: onEnd)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct EndConfirmView: View {
    @EnvironmentObject private var store: TrainingSessionStore

    var body: some View {
        let snapshot = store.session.snapshot

        ZStack {
            KVColor.background.ignoresSafeArea(.all)
            TelemetryGridBackground(
                gridColor: KVColor.lime.opacity(0.08),
                waveColor: KVColor.load.opacity(0.14)
            )

            Circle()
                .fill(KVColor.load.opacity(0.12))
                .frame(width: 164, height: 164)
                .blur(radius: 32)
                .offset(x: 92, y: -92)

            VStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text("END SESSION?")
                        .font(KVFont.headline(18))
                        .italic()
                        .foregroundStyle(KVColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("结束确认")
                        .font(KVFont.body(11, weight: .black))
                        .foregroundStyle(KVColor.load)
                }
                .padding(.top, 10)
                .padding(.trailing, 36)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 2), spacing: 7) {
                    SnapshotMetric(title: "时长", value: snapshot.durationSeconds.clockString, unit: "", systemImage: "timer")
                    SnapshotMetric(title: "挥拍", value: snapshot.swingCount.groupedString, unit: "", systemImage: "figure.badminton")
                    SnapshotMetric(title: "卡路里", value: "\(snapshot.calories)", unit: "kcal", systemImage: "flame.fill")
                    SnapshotMetric(title: "最快", value: "\(snapshot.maxSwingSpeedKph)", unit: "km/h", systemImage: "gauge.with.dots.needle.67percent")
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                Spacer(minLength: 4)

                Button {
                    store.continueRecording()
                } label: {
                    Text("CONTINUE")
                        .font(KVFont.headline(14))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(KVColor.lime, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .telemetryGlow(KVColor.lime)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)

                Button {
                    store.endAndSave()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .black))
                        Text("END TRAINING")
                            .font(KVFont.body(11, weight: .black))
                            .lineLimit(1)
                    }
                    .foregroundStyle(KVColor.courtAmber)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(KVColor.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(KVColor.courtAmber.opacity(0.34), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 5)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all)
    }
}

struct SnapshotMetric: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(KVColor.load)
                .frame(width: 15, height: 15)
                .background(KVColor.load.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(KVFont.headline(17))
                        .foregroundStyle(KVColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(KVFont.data(7, weight: .bold))
                            .foregroundStyle(KVColor.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }

                Text(title)
                    .font(KVFont.body(8.5, weight: .black))
                    .foregroundStyle(KVColor.load)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(KVColor.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(KVColor.load.opacity(0.22), lineWidth: 1)
        }
    }
}

struct SavingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(KVColor.lime)
            Text("SAVING SESSION")
                .font(KVFont.data(12))
                .foregroundStyle(KVColor.text)
            Text("同步到 iPhone 后查看详细复盘")
                .font(KVFont.body(10))
                .foregroundStyle(KVColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(18)
    }
}

struct SavedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 52, height: 52)
                .background(KVColor.lime, in: Circle())
                .telemetryGlow()

            Text("SAVED")
                .font(KVFont.headline(18))
                .foregroundStyle(KVColor.text)

            Text("iPhone 端查看深度复盘")
                .font(KVFont.body(10, weight: .semibold))
                .foregroundStyle(KVColor.muted)
        }
        .padding(16)
    }
}

#Preview("Start") {
    RootView()
        .environmentObject(TrainingSessionStore())
}
