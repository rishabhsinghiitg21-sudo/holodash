import SwiftUI
import MapKit

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if model.authDenied {
                        Text("Location access is off. Enable it in Settings to show speed and guidance.")
                            .font(.footnote).foregroundStyle(HUD.red)
                    }

                    destinationSearch
                    if !results.isEmpty { resultsList }

                    HStack(spacing: 14) {
                        bigButton("START · SPEED + LIMIT", color: HUD.teal) { model.startNoRoute() }
                        bigButton("DEMO MODE", color: HUD.yellow) { model.startDemo() }
                    }

                    Text("Place the phone screen-up on the dash, then angle the acrylic sheet ~45° above it.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.4))
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HUD.teal)
                    .padding(20)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView().environment(model) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOLODASH")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(HUD.teal)
                .shadow(color: HUD.teal.opacity(0.5), radius: 8)
            Text("Heads-up display")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var destinationSearch: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DESTINATION")
                .font(.caption2.weight(.semibold)).tracking(2)
                .foregroundStyle(.white.opacity(0.4))
            HStack {
                TextField("Search address or place", text: $query)
                    .textFieldStyle(.plain).foregroundStyle(.white)
                    .submitLabel(.search).onSubmit(search)
                Button(action: search) { Image(systemName: "magnifyingglass") }
                    .foregroundStyle(HUD.teal)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.15)))
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(results, id: \.self) { item in
                Button { model.start(destination: item) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "—").foregroundStyle(.white)
                        Text(item.placemark.title ?? "")
                            .font(.caption).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
                Divider().overlay(.white.opacity(0.08))
            }
        }
    }

    private func bigButton(_ title: String, color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(1)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(color)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 1.5))
        }
    }

    private func search() {
        guard !query.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        MKLocalSearch(request: req).start { resp, _ in results = resp?.mapItems ?? [] }
    }
}
