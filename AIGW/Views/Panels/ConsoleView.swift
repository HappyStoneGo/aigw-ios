import SwiftUI

enum ConsoleSection: String, CaseIterable, Identifiable {
    case dashboard = "概览"
    case pool = "账号池"
    case providers = "供应商"
    case models = "模型"
    case personas = "思维注入"
    case assets = "会话资产"
    case extensions = "扩展能力"
    case plan = "套餐"
    case logs = "日志审计"
    case account = "账号"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie"
        case .pool: return "person.2"
        case .providers: return "server.rack"
        case .models: return "cpu"
        case .personas: return "theatermasks"
        case .assets: return "books.vertical"
        case .extensions: return "puzzlepiece.extension"
        case .plan: return "creditcard"
        case .logs: return "list.bullet.rectangle"
        case .account: return "person.crop.circle"
        }
    }
}

struct ConsoleView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                if !app.loggedIn {
                    Section {
                        NavigationLink {
                            LoginView()
                        } label: {
                            Label("登录以解锁控制台", systemImage: "person.badge.key")
                        }
                    } footer: {
                        Text("登录后可使用账号池、供应商、模型、Persona、MCP、工作流等全部用户端能力（/api/user/*）。")
                    }
                }

                Section("模块") {
                    ForEach(ConsoleSection.allCases) { s in
                        NavigationLink {
                            sectionView(s)
                        } label: {
                            Label(s.rawValue, systemImage: s.icon)
                        }
                    }
                }

                Section("服务器") {
                    HStack {
                        Text("地址")
                        Spacer()
                        Text(app.baseURL).font(.footnote).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("状态")
                        Spacer()
                        statusBadge
                    }
                    Button("重新探活") { Task { await app.checkHealth() } }
                }
            }
            .navigationTitle("控制台")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch app.serverStatus {
        case .unknown:
            Text("未检测").font(.footnote).foregroundStyle(.secondary)
        case .ok(let s):
            Label(s, systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(.green)
        case .down:
            Label("不可达", systemImage: "xmark.circle.fill").font(.footnote).foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func sectionView(_ s: ConsoleSection) -> some View {
        switch s {
        case .dashboard: DashboardPanel()
        case .pool: AccountPoolPanel()
        case .providers: ProvidersPanel()
        case .models: ModelsPanel()
        case .personas: PersonasPanel()
        case .assets: AssetsPanel()
        case .extensions: ExtensionsPanel()
        case .plan: PlanPanel()
        case .logs: LogsPanel()
        case .account: AccountPanel()
        }
    }
}
