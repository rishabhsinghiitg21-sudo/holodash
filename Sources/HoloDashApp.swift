import SwiftUI

@main
struct HoloDashApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .task {
                    // Allows the simulator/preview to boot straight into a populated HUD.
                    if CommandLine.arguments.contains("-noMirror") { model.disableMirrorForSession() }
                    if CommandLine.arguments.contains("-demoMode") { model.startDemo() }
                    #if DEBUG
                    if CommandLine.arguments.contains("-simNav") {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        model.startSimNav()
                    }
                    #endif
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.running {
                HUDView()
            } else {
                SetupView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.running)
    }
}
