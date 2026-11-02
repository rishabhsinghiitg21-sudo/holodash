import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Navigation") {
                    Button {
                        dismiss(); model.stop()
                    } label: {
                        Label("Change destination", systemImage: "location")
                    }
                    Button {
                        dismiss(); model.startDemo()
                    } label: {
                        Label("Demo mode", systemImage: "play.circle")
                    }
                }

                Section("Display") {
                    Picker("Units", selection: $model.useMph) {
                        Text("km/h").tag(false)
                        Text("mph").tag(true)
                    }
                    Toggle("Mirror for reflection", isOn: $model.mirrored)
                    Toggle("Keep screen awake", isOn: $model.keepAwake)
                }

                Section("Alerts") {
                    Stepper("Over-limit margin: +\(model.overThreshold) \(model.useMph ? "mph" : "km/h")",
                            value: $model.overThreshold, in: 0...10)
                }

                Section {
                    Toggle("Larger HUD text", isOn: $model.largeText)
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Reduce Motion is followed automatically when enabled in iOS Settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .tint(HUD.teal)
        }
        .preferredColorScheme(.dark)
    }
}
