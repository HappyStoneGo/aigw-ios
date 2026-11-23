import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var app: AppState
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if app.conversations.isEmpty {
                    ContentUnavailableView {
                        Label("还没有对话", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("点右上角新建一个，或用下方按钮开始")
                    } actions: {
                        Button("新建对话") { _ = app.newConversation() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(app.conversations) { c in
                            NavigationLink {
                                ChatView(conversationID: c.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(c.title).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(c.model.isEmpty ? "默认模型" : c.model)
                                        Text("·")
                                        Text("\(c.messages.count) 条")
                                        Spacer()
                                        Text(c.updatedAt, style: .date)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { app.delete(app.conversations[$0]) }
                        }
                    }
                }
            }
            .navigationTitle("AI 聚合网关")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let c = app.newConversation()
                        app.save(c)
                    } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showSettings) { ChatPrefsView() }
        }
    }
}

/// 对话偏好（模型 / 采集参数 / 会话级附加字段）
struct ChatPrefsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var temperature = 0.7
    @State private var maxTokens = 2048
    @State private var system = ""
    @State private var useResponses = false

    var body: some View {
        NavigationStack {
            Form {
                Section("鉴权") {
                    SecureField("API Key（sk-aigw-… / sk-user-…）", text: $app.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("默认模型") {
                    if app.models.isEmpty {
                        Button("拉取模型列表") { Task { await app.loadModels() } }
                    } else {
                        Picker("模型", selection: $app.selectedModelId) {
                            ForEach(app.models) { m in
                                Text(m.name).tag(m.id)
                            }
                        }
                    }
                }
                Section("生成参数") {
                    VStack(alignment: .leading) {
                        Text("temperature \(String(format: "%.2f", temperature))")
                            .font(.footnote).foregroundStyle(.secondary)
                        Slider(value: $temperature, in: 0...2)
                    }
                    Stepper("max_tokens：\(maxTokens)", value: $maxTokens, in: 64...32000, step: 128)
                }
                Section("系统提示") {
                    TextEditor(text: $system).frame(minHeight: 80)
                }
                Section {
                    Toggle("使用 /v1/responses 接口", isOn: $useResponses)
                        .onChange(of: useResponses) { _, v in
                            UserDefaults.standard.set(v, forKey: "aigw.useResponses")
                        }
                } footer: {
                    Text("Responses API 支持后台执行与会话检索。")
                }
            }
            .navigationTitle("对话设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        UserDefaults.standard.set(temperature, forKey: "aigw.temp")
                        UserDefaults.standard.set(maxTokens, forKey: "aigw.maxTokens")
                        UserDefaults.standard.set(system, forKey: "aigw.system")
                        dismiss()
                    }
                }
            }
            .onAppear {
                temperature = UserDefaults.standard.object(forKey: "aigw.temp") as? Double ?? 0.7
                maxTokens = UserDefaults.standard.object(forKey: "aigw.maxTokens") as? Int ?? 2048
                system = UserDefaults.standard.string(forKey: "aigw.system") ?? ""
                useResponses = UserDefaults.standard.bool(forKey: "aigw.useResponses")
            }
        }
    }
}
