import SwiftUI

struct ChatView: View {
    @EnvironmentObject var app: AppState
    let conversationID: UUID

    @State private var input = ""
    @State private var streaming = false
    @State private var streamingText = ""
    @State private var showModelPicker = false
    @FocusState private var focused: Bool

    private var conversationIndex: Int? {
        app.conversations.firstIndex { $0.id == conversationID }
    }

    private var conversation: Conversation {
        conversationIndex.map { app.conversations[$0] } ?? Conversation(title: "对话")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(conversation.messages) { m in
                            MessageBubble(message: m) { app.show("已复制") }
                                .id(m.id)
                        }
                        if streaming, !streamingText.isEmpty {
                            MessageBubble(message: ChatMessage(role: .assistant, content: streamingText)) { _ in }
                                .id("streaming")
                        }
                        if streaming, streamingText.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("正在生成…").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(conversation.messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: streamingText) { _, _ in
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }

            Divider()
            inputBar
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showModelPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(conversation.model.isEmpty ? (app.selectedModelId.isEmpty ? "选择模型" : app.selectedModelId) : conversation.model)
                            .font(.footnote.weight(.medium))
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("重新生成", systemImage: "arrow.clockwise") { regenerate() }
                        .disabled(conversation.messages.isEmpty || streaming)
                    Button("清空对话", systemImage: "trash", role: .destructive) { clear() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showModelPicker) {
            NavigationStack {
                List {
                    if app.models.isEmpty {
                        Button("拉取模型列表") { Task { await app.loadModels() } }
                    }
                    ForEach(app.models) { m in
                        Button {
                            setModel(m.id)
                            showModelPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(m.name)
                                    if !m.provider.isEmpty {
                                        Text(m.provider).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if m.id == app.selectedModelId {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("模型")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showModelPicker = false }
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入消息…", text: $input, axis: .vertical)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

            Button {
                send()
            } label: {
                Image(systemName: streaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !streaming)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: 操作

    private func setModel(_ id: String) {
        app.selectedModelId = id
        if let i = conversationIndex {
            app.conversations[i].model = id
            app.save(app.conversations[i])
        }
    }

    private func clear() {
        guard let i = conversationIndex else { return }
        app.conversations[i].messages.removeAll()
        app.save(app.conversations[i])
    }

    private func regenerate() {
        guard let i = conversationIndex, !streaming else { return }
        if app.conversations[i].messages.last?.role == .assistant {
            app.conversations[i].messages.removeLast()
            app.save(app.conversations[i])
        }
        send(appendUser: false)
    }

    private func send(appendUser: Bool = true) {
        if streaming { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard appendUser ? !text.isEmpty : true else { return }
        guard let i = conversationIndex else { return }

        if appendUser {
            app.conversations[i].messages.append(ChatMessage(role: .user, content: text))
            if app.conversations[i].title == "新对话" {
                app.conversations[i].title = String(text.prefix(20))
            }
            input = ""
        }
        app.conversations[i].updatedAt = Date()
        app.save(app.conversations[i])

        let msgs = app.conversations[i].messages
        let model = app.selectedModelId.isEmpty ? (app.models.first?.id ?? "") : app.selectedModelId
        guard !model.isEmpty else {
            app.show("请先选择模型")
            return
        }
        if app.apiKey.isEmpty {
            app.show("请先在设置里填写 API Key")
            return
        }

        streaming = true
        streamingText = ""

        Task {
            var payload: [String: Any] = [
                "model": model,
                "temperature": UserDefaults.standard.object(forKey: "aigw.temp") as? Double ?? 0.7,
                "max_tokens": UserDefaults.standard.object(forKey: "aigw.maxTokens") as? Int ?? 2048
            ]
            let system = UserDefaults.standard.string(forKey: "aigw.system") ?? ""
            var apiMessages: [[String: String]] = []
            if !system.isEmpty { apiMessages.append(["role": "system", "content": system]) }
            for m in msgs where m.role != .system {
                apiMessages.append(["role": m.role.rawValue, "content": m.content])
            }

            let useResponses = UserDefaults.standard.bool(forKey: "aigw.useResponses")
            if useResponses {
                payload = [
                    "model": model,
                    "input": apiMessages,
                    "max_output_tokens": UserDefaults.standard.object(forKey: "aigw.maxTokens") as? Int ?? 2048
                ]
                if !system.isEmpty { payload["instructions"] = system }
            } else {
                payload["messages"] = apiMessages
            }

            let path = useResponses ? API.responses : API.chatCompletions
            var finalText = ""
            var reasoning = ""
            do {
                finalText = try await ApiClient.shared.streamChat(
                    path: path, payload: payload, bearer: app.apiKey,
                    onDelta: { delta in
                        streamingText += delta
                    },
                    onReasoning: { delta in
                        reasoning += delta
                    }
                )
            } catch {
                finalText = ""
                await MainActor.run { app.lastErrorText = error.localizedDescription }
            }

            await MainActor.run {
                streaming = false
                streamingText = ""
                if let idx = conversationIndex {
                    if finalText.isEmpty {
                        app.conversations[idx].messages.append(
                            ChatMessage(role: .assistant, content: "",
                                        reasoning: reasoning,
                                        error: "请求失败：\(app.lastErrorText ?? "未知错误")")
                        )
                    } else {
                        app.conversations[idx].messages.append(
                            ChatMessage(role: .assistant, content: finalText, reasoning: reasoning)
                        )
                    }
                    app.save(app.conversations[idx])
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onCopy: (String) -> Void
    @State private var showReasoning = false

    private var bubbleStyle: AnyShapeStyle {
        message.role == .user
            ? AnyShapeStyle(Color.accentColor.opacity(0.16))
            : AnyShapeStyle(Color.secondary.opacity(0.10))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                if !message.reasoning.isEmpty {
                    DisclosureGroup(isExpanded: $showReasoning) {
                        Text(message.reasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("思考过程").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                }
                if let err = message.error {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if message.role == .user {
                    Text(message.content)
                        .textSelection(.enabled)
                } else {
                    MarkdownText(text: message.content, onCopy: onCopy)
                }
            }
            .padding(12)
            .background(bubbleStyle, in: RoundedRectangle(cornerRadius: 14))

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .contextMenu {
            Button("复制", systemImage: "doc.on.doc") { onCopy(message.content) }
        }
    }
}
