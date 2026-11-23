import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @AppStorage("aigw.didOnboard") private var didOnboard = false
    @State private var address = AppConfig.baseURL
    @State private var checking = false
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("http://127.0.0.1", text: $address)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button(checking ? "检测中…" : "保存并探活") {
                        app.applyBaseURL(address)
                        Task {
                            checking = true
                            await app.checkHealth()
                            checking = false
                        }
                    }
                    HStack {
                        Text("健康检查")
                        Spacer()
                        switch app.serverStatus {
                        case .unknown: Text("未检测").foregroundStyle(.secondary)
                        case .ok(let s): Text(s).foregroundStyle(.green)
                        case .down: Text("不可达").foregroundStyle(.red)
                        }
                    }
                    .font(.footnote)
                }

                Section("对话") {
                    SecureField("API Key", text: $app.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("拉取模型列表") { Task { await app.loadModels() } }
                    HStack {
                        Text("已加载模型")
                        Spacer()
                        Text("\(app.models.count)").foregroundStyle(.secondary)
                    }
                }

                Section("账号") {
                    if app.loggedIn {
                        HStack {
                            Text("已登录")
                            Spacer()
                            Text(app.user?["nickname"]?.stringValue
                                 ?? app.user?["email"]?.stringValue ?? "-")
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink("账号详情与管理") { AccountPanel() }
                    } else {
                        Button("登录 / 注册") { showLogin = true }
                    }
                }

                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text(appVersion).foregroundStyle(.secondary) }
                    HStack { Text("默认地址"); Spacer(); Text(AppConfig.defaultBaseURL).foregroundStyle(.secondary) }
                    Button("重看引导") { didOnboard = false }
                }

                Section {
                    Text("客户端对接 aigw-backend 的 OpenAI 兼容层与 /api/user/* 全量接口。若网关不在本机，把地址改成对应域名或局域网 IP。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showLogin) { NavigationStack { LoginView() } }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
