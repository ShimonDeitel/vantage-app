import SwiftUI
import AVFoundation

/// Free-tier home screen: a live camera feed with a proportion grid and a plumb
/// crosshair that reads the device's own tilt (CoreMotion) and rotates to stay
/// world-true, springing into a brightened "locked" state when the phone holds
/// steady — an electronic version of the hand-held plumb bob and sighting stick
/// artists already use.
struct OverlayCameraView: View {
    @State private var camera = CameraService()
    @StateObject private var motion = MotionEngine()
    @EnvironmentObject var appModel: AppModel

    @State private var authDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isConfigured {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                GridPlumbOverlay(
                    divisions: appModel.gridDivisions,
                    showGrid: appModel.showGrid,
                    rotation: MotionEngine.plumbRotation(roll: motion.roll),
                    isSteady: motion.isSteady
                )
                .ignoresSafeArea()
            } else if authDenied {
                permissionMessage
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                steadyBadge
                Spacer()
                controlBar
            }
            .padding()
        }
        .statusBarHidden(camera.isConfigured)
        .task { await setUp() }
        .onDisappear {
            camera.stop()
            motion.stop()
        }
    }

    private var steadyBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(motion.isSteady ? Color.white : Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
            Text(motion.isSteady ? "STEADY — TRUE VERTICAL LOCKED" : "HOLD STILL TO LOCK")
                .font(VantageFont.tick(11))
                .tracking(1.2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(VantageColor.overlayPanel)
        .overlay(Rectangle().strokeBorder(VantageColor.overlayHairline, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: motion.isSteady)
    }

    private var controlBar: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.click()
                appModel.showGrid.toggle()
            } label: {
                Image(systemName: appModel.showGrid ? "grid" : "grid.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    appModel.gridDivisions = max(AppModel.gridDivisionsRange.lowerBound, appModel.gridDivisions - 1)
                } label: {
                    Image(systemName: "minus").font(.system(size: 14, weight: .bold))
                }
                Text("\(appModel.gridDivisions) × \(appModel.gridDivisions)")
                    .font(VantageFont.value(13))
                    .frame(minWidth: 46)
                Button {
                    Haptics.tap()
                    appModel.gridDivisions = min(AppModel.gridDivisionsRange.upperBound, appModel.gridDivisions + 1)
                } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
        }
        .foregroundStyle(.white)
        .background(VantageColor.overlayPanel)
        .overlay(Rectangle().strokeBorder(VantageColor.overlayHairline, lineWidth: 1))
    }

    private var permissionMessage: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 34, weight: .semibold))
            Text("Camera Access Needed")
                .font(VantageFont.headline(18))
            Text("Vantage needs the camera to draw the live proportion grid and plumb line. Enable it in Settings.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .squareButton()
            .frame(width: 200)
        }
        .foregroundStyle(.white)
    }

    private func setUp() async {
        let granted = await CameraService.requestPermission()
        guard granted else {
            authDenied = true
            return
        }
        do {
            try camera.configure()
            camera.start()
            motion.start()
        } catch {
            authDenied = true
        }
    }
}

/// The rotating grid + plumb crosshair layer. Corner viewfinder ticks stay fixed to
/// the screen; only the true-vertical/true-horizontal sighting lines rotate.
private struct GridPlumbOverlay: View {
    let divisions: Int
    let showGrid: Bool
    let rotation: Angle
    let isSteady: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            let frame = CGSize(width: diagonal, height: diagonal)

            ZStack {
                if showGrid {
                    GridPath(divisions: divisions)
                        .stroke(lineColor, lineWidth: 1)
                }
                PlumbCrosshairPath()
                    .stroke(lineColor, lineWidth: isSteady ? 2.2 : 1.4)
            }
            .frame(width: frame.width, height: frame.height)
            .position(x: size.width / 2, y: size.height / 2)
            .rotationEffect(rotation)
            .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: rotation)
            .animation(.easeOut(duration: 0.2), value: isSteady)

            CornerTicks(length: 18)
                .stroke(Color.white.opacity(0.85), lineWidth: 1.6)
                .padding(28)
        }
        .allowsHitTesting(false)
    }

    private var lineColor: Color {
        isSteady ? VantageColor.overlayLineLocked : VantageColor.overlayLine
    }
}

/// N-1 evenly spaced vertical and horizontal interior lines across the given rect.
private struct GridPath: Shape {
    let divisions: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in GridGeometry.linePositions(divisions: divisions) {
            let x = rect.minX + rect.width * fraction
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * fraction
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// The plumb line (vertical) and level line (horizontal) through the frame's center.
private struct PlumbCrosshairPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        return path
    }
}
