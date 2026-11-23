import SwiftUI

@main
struct AIGWApp: App {
    @StateObject private var app = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .task { await app.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("aigw.didOnboard") private var didOnboard = false

    var body: some View {
        ZStack {
            TabView {
                ChatListView()
                    .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }
                ConsoleView()
                    .tabItem { Label("控制台", systemImage: "square.grid.2x2") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .tint(.accentColor)

            if let toast = app.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 90)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        if app.toast == toast { app.toast = nil }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { !didOnboard },
                                    set: { didOnboard = !$0 })) {
            OnboardingView()
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var address = AppConfig.baseURL
    @State private var key = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器地址") {
                    TextField("http://127.0.0.1", text: $address)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section("API Key（可稍后填）") {
                    TextField("sk-aigw-… 或 sk-user-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("默认指向本机 \(AppConfig.defaultBaseURL)。若网关部署在其他机器，改成对应地址即可。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("接入 AI 聚合网关")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        app.applyBaseURL(address)
                        if !key.isEmpty { app.apiKey = key }
                        Task {
                            await app.checkHealth()
                            await app.loadModels()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
