import SwiftUI

// MARK: - 概览

struct DashboardPanel: View {
    var body: some View {
        GenericPanel(
            title: "概览",
            queries: [
                PanelQuery(title: "仪表盘数据", path: API.dashboard),
                PanelQuery(title: "账号池总览", path: API.poolOverview),
                PanelQuery(title: "日志统计", path: API.logsStats),
                PanelQuery(title: "额度监控", path: API.creditsMonitor)
            ],
            actions: []
        )
    }
}

// MARK: - 账号池

struct AccountPoolPanel: View {
    var body: some View {
        GenericPanel(
            title: "账号池",
            queries: [
                PanelQuery(title: "账号列表", path: API.accounts),
                PanelQuery(title: "签到记录", path: API.checkinLogs),
                PanelQuery(title: "旅行任务记录", path: API.travelLogs),
                PanelQuery(title: "活跃记录", path: API.activityLogs),
                PanelQuery(title: "成长数据", path: API.growth),
                PanelQuery(title: "任务状态", path: API.actionTask)
            ],
            actions: [
                PanelQuery(title: "全部刷新", path: API.refreshAll, method: "POST"),
                PanelQuery(title: "全部签到", path: API.checkinAll, method: "POST"),
                PanelQuery(title: "全部跑任务", path: API.tasksAll, method: "POST"),
                PanelQuery(title: "全部旅行", path: API.travelAll, method: "POST"),
                PanelQuery(title: "全部活跃", path: API.activityAll, method: "POST")
            ],
            footer: "账号池是后端多上游账号轮转的核心，这里的操作与网页控制台 /console 完全等价。"
        )
    }
}

// MARK: - 供应商

struct ProvidersPanel: View {
    var body: some View {
        GenericPanel(
            title: "供应商",
            queries: [PanelQuery(title: "供应商列表", path: API.providers)],
            actions: [],
            footer: "内置 Trae / WorkBuddy / Antigravity / 豆包 / ZCode / Qoder / 小浣熊 / Loomy 及自定义 OpenAI 兼容供应商。新增与 OAuth 登录请在网页控制台完成，本页可查看与测试。"
        )
    }
}

// MARK: - 模型

struct ModelsPanel: View {
    var body: some View {
        GenericPanel(
            title: "模型",
            queries: [
                PanelQuery(title: "可用模型", path: API.models),
                PanelQuery(title: "网关 /v1/models", path: API.v1Models),
                PanelQuery(title: "模型分组配置", path: API.modelProfiles)
            ],
            actions: [
                PanelQuery(title: "从供应商同步模型", path: API.modelsSync, method: "POST")
            ],
            footer: "「从供应商同步」会把上游最新模型拉进本实例。"
        )
    }
}

// MARK: - 思维注入 / 模板

struct PersonasPanel: View {
    var body: some View {
        GenericPanel(
            title: "思维注入",
            queries: [
                PanelQuery(title: "Persona 列表", path: API.personas),
                PanelQuery(title: "提示词模板", path: API.promptTemplates),
                PanelQuery(title: "对话设置", path: API.chatSettings),
                PanelQuery(title: "全局设置", path: API.settings)
            ],
            actions: [
                PanelQuery(title: "Persona 自检", path: API.personaSelfcheck, method: "POST")
            ],
            footer: "思维注入按供应商 / 模型下发 Persona，支持预览与自检。"
        )
    }
}

// MARK: - 会话资产

struct AssetsPanel: View {
    var body: some View {
        GenericPanel(
            title: "会话资产",
            queries: [
                PanelQuery(title: "世界书", path: API.worldbook),
                PanelQuery(title: "角色卡", path: API.characterCards),
                PanelQuery(title: "助手记忆", path: API.memory),
                PanelQuery(title: "记忆召回测试", path: API.memoryRecall, method: "POST",
                           body: ["query": "测试"])
            ],
            actions: [
                PanelQuery(title: "清空记忆", path: API.memoryClear, method: "POST")
            ]
        )
    }
}

// MARK: - 扩展能力

struct ExtensionsPanel: View {
    var body: some View {
        GenericPanel(
            title: "扩展能力",
            queries: [
                PanelQuery(title: "MCP 服务器", path: API.mcp),
                PanelQuery(title: "MCP 工具", path: API.mcpTools),
                PanelQuery(title: "插件", path: API.plugins),
                PanelQuery(title: "插件能力", path: API.pluginCaps),
                PanelQuery(title: "子代理运行", path: API.subagentRuns),
                PanelQuery(title: "工作流", path: API.workflows),
                PanelQuery(title: "工具清单", path: API.tools),
                PanelQuery(title: "研究任务", path: API.research),
                PanelQuery(title: "语音能力", path: API.speechCaps),
                PanelQuery(title: "语音日志", path: API.speechLogs),
                PanelQuery(title: "运行环境", path: API.envInfo),
                PanelQuery(title: "环境变量", path: API.envVariables)
            ],
            actions: [],
            footer: "MCP / 插件 / 工作流的创建请走网页控制台；移动端提供查看与调用。"
        )
    }
}

// MARK: - 套餐

struct PlanPanel: View {
    var body: some View {
        GenericPanel(
            title: "套餐",
            queries: [PanelQuery(title: "当前套餐", path: API.plan)],
            actions: [
                PanelQuery(title: "生成套餐方案", path: API.planGenerate, method: "POST")
            ]
        )
    }
}

// MARK: - 日志审计

struct LogsPanel: View {
    var body: some View {
        GenericPanel(
            title: "日志审计",
            queries: [
                PanelQuery(title: "请求日志", path: API.logs),
                PanelQuery(title: "日志统计", path: API.logsStats),
                PanelQuery(title: "审计时间线", path: API.auditTimeline),
                PanelQuery(title: "审计流水", path: API.audit)
            ],
            actions: []
        )
    }
}

// MARK: - 账号

struct AccountPanel: View {
    @EnvironmentObject var app: AppState
    @State private var newPassword = ""
    @State private var confirmRegenerate = false

    var body: some View {
        List {
            if let u = app.user {
                Section("资料") {
                    KVRow(key: "昵称", value: u["nickname"]?.stringValue ?? "-")
                    KVRow(key: "邮箱", value: u["email"]?.stringValue ?? "-")
                    KVRow(key: "用户名", value: u["username"]?.stringValue ?? "-")
                    KVRow(key: "用户 ID", value: u["id"]?.stringValue ?? "-")
                }
                Section("我的 API Key") {
                    let k = u["api_key"]?.stringValue ?? (u["apiKey"]?.stringValue ?? "")
                    if k.isEmpty {
                        Text("未获取到 Key，可尝试重置后在网页端查看").font(.footnote)
                    } else {
                        Text(k).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                        Button("复制并用作对话 Key") {
                            app.apiKey = k
                            app.show("已设为对话 Key")
                        }
                    }
                    Button("重置 API Key", role: .destructive) { confirmRegenerate = true }
                }
            } else {
                Section {
                    NavigationLink("登录") { LoginView() }
                }
            }

            Section("修改密码") {
                SecureField("新密码", text: $newPassword)
                Button("提交") {
                    Task {
                        do {
                            _ = try await ApiClient.shared.request(API.password, method: "POST",
                                                                  body: ["password": newPassword])
                            app.show("密码已修改")
                            newPassword = ""
                        } catch { app.show(error.localizedDescription) }
                    }
                }
                .disabled(newPassword.count < 6)
            }

            Section {
                Button("退出登录", role: .destructive) {
                    Task {
                        _ = try? await ApiClient.shared.request(API.logout, method: "POST")
                        SessionCookieStore.shared.clear()
                        app.loggedIn = false
                        app.user = nil
                    }
                }
            }
        }
        .navigationTitle("账号")
        .refreshable { await app.refreshMe() }
        .confirmationDialog("重置后旧 Key 立即失效", isPresented: $confirmRegenerate) {
            Button("确认重置", role: .destructive) {
                Task {
                    do {
                        let v = try await ApiClient.shared.request(API.regenerateKey, method: "POST")
                        if let k = v["api_key"]?.stringValue { app.apiKey = k }
                        await app.refreshMe()
                        app.show("已重置")
                    } catch { app.show(error.localizedDescription) }
                }
            }
        }
    }
}
