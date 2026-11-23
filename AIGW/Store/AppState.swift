import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var loggedIn = false
    @Published var user: JSONValue?
    @Published var baseURL: String = AppConfig.baseURL
    @Published var serverStatus: ServerStatus = .unknown
    @Published var lastError: String?
    @Published var toast: String?
    @Published var lastErrorText: String?

    enum ServerStatus { case unknown, ok(String), down(String) }

    /// 对话用 API Key（用户 sk-user-* 或网关 sk-aigw-*）
    @Published var apiKey: String = UserDefaults.standard.string(forKey: AppConfig.keyAPIKey) ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: AppConfig.keyAPIKey) }
    }

    @Published var selectedModelId: String = UserDefaults.standard.string(forKey: AppConfig.keyLastModel) ?? "" {
        didSet { UserDefaults.standard.set(selectedModelId, forKey: AppConfig.keyLastModel) }
    }

    @Published var models: [ModelItem] = []
    @Published var conversations: [Conversation] = []

    private init() {
        conversations = ConversationStore.load()
    }

    // MARK: 启动

    func bootstrap() async {
        await checkHealth()
        if SessionCookieStore.shared.header(for: AppConfig.normalizedBase() ?? URL(string: "http://127.0.0.1")!) != nil {
            await refreshMe()
        }
    }

    func checkHealth() async {
        do {
            let v = try await ApiClient.shared.request(API.health)
            let name = v["status"]?.stringValue ?? v["ok"]?.stringValue ?? "ok"
            serverStatus = .ok(name.isEmpty ? "ok" : name)
        } catch {
            serverStatus = .down(error.localizedDescription)
        }
    }

    func refreshMe() async {
        do {
            let v = try await ApiClient.shared.request(API.me)
            user = v
            loggedIn = true
            if apiKey.isEmpty, let k = v["api_key"]?.stringValue, !k.isEmpty {
                apiKey = k
            }
        } catch {
            loggedIn = false
            user = nil
        }
    }

    func applyBaseURL(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        AppConfig.baseURL = s
        baseURL = s
    }

    // MARK: 提示

    func show(_ message: String) {
        toast = message
    }

    // MARK: 会话管理

    func newConversation() -> Conversation {
        let c = Conversation(title: "新对话")
        conversations.insert(c, at: 0)
        ConversationStore.save(conversations)
        return c
    }

    func save(_ c: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == c.id }) {
            conversations[idx] = c
        } else {
            conversations.insert(c, at: 0)
        }
        ConversationStore.save(conversations)
    }

    func delete(_ c: Conversation) {
        conversations.removeAll { $0.id == c.id }
        ConversationStore.save(conversations)
    }

    // MARK: 模型列表

    func loadModels() async {
        // 优先走 /v1/models（需要 Bearer）
        if !apiKey.isEmpty {
            do {
                let v = try await ApiClient.shared.request(API.v1Models, bearer: apiKey)
                let items = v["data"]?.objectValues.compactMap { it -> ModelItem? in
                    guard let id = it["id"]?.stringValue else { return nil }
                    let owned = it["owned_by"]?.stringValue ?? ""
                    return ModelItem(id: id, name: id, provider: owned)
                } ?? []
                if !items.isEmpty {
                    models = items
                    if selectedModelId.isEmpty { selectedModelId = items[0].id }
                    return
                }
            } catch { /* 回落到用户模型接口 */ }
        }
        if loggedIn {
            do {
                let v = try await ApiClient.shared.request(API.models)
                let items = v.objectValues.compactMap { it -> ModelItem? in
                    let id = it["model_id"]?.stringValue ?? it["id"]?.stringValue ?? ""
                    guard !id.isEmpty else { return nil }
                    let name = it["display_name"]?.stringValue ?? it["name"]?.stringValue ?? id
                    return ModelItem(id: id, name: name, provider: it["provider"]?.stringValue ?? "")
                }
                models = items
                if selectedModelId.isEmpty, let f = items.first { selectedModelId = f.id }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

struct ModelItem: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String
}

// MARK: - 对话模型

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case system, user, assistant }
    var id = UUID()
    var role: Role
    var content: String
    var reasoning: String = ""
    var date = Date()
    var error: String?
}

struct Conversation: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var model: String = ""
    var messages: [ChatMessage] = []
    var updatedAt = Date()
}

enum ConversationStore {
    static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("conversations.json")
    }

    static func load() -> [Conversation] {
        guard let d = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Conversation].self, from: d)) ?? []
    }

    static func save(_ list: [Conversation]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        if let d = try? enc.encode(list) {
            try? d.write(to: fileURL, options: .atomic)
        }
    }
}
