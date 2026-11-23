import Foundation

/// 全局配置：服务器地址默认本机，可在设置里改
enum AppConfig {
    static let defaultBaseURL = "http://127.0.0.1"
    static let keyBaseURL = "aigw.baseURL"
    static let keyAPIKey = "aigw.apiKey"     // 会话里用户自己的 sk-user-*
    static let keyGatewayKey = "aigw.gatewayKey"
    static let keyLastModel = "aigw.lastModel"

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: keyBaseURL) ?? defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: keyBaseURL) }
    }

    static func normalizedBase() -> URL? {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = defaultBaseURL }
        if !s.lowercased().hasPrefix("http") { s = "http://" + s }
        return URL(string: s)
    }
}

enum ApiError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case decode(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "服务器地址无效"
        case .http(let c, let m): return "HTTP \(c)\(m.isEmpty ? "" : "：\(m)")"
        case .decode(let m): return "解析失败：\(m)"
        case .network(let m): return "网络错误：\(m)"
        }
    }
}

/// 统一响应包：{ ok: true, data: ... } / { ok: false, message: ... }
struct ApiEnvelope: Decodable {
    let ok: Bool?
    let data: JSONValue?
    let message: String?
    let error: String?
}

enum JSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        self = .null
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        case .array, .object:
            guard let d = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]),
                  let s = String(data: d, encoding: .utf8) else { return "" }
            return s
        }
    }

    var intValue: Int? { Int(stringValue) }
    var boolValue: Bool {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        case .string(let s): return ["1", "true", "yes", "on"].contains(s.lowercased())
        default: return false
        }
    }

    var raw: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map { $0.raw }
        case .object(let o): return o.mapValues { $0.raw }
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var objectValues: [JSONValue] {
        if case .array(let a) = self { return a }
        return []
    }
}

/// 会话级 Cookie 存储：后端用 aigw_session Cookie 鉴权
final class SessionCookieStore {
    static let shared = SessionCookieStore()
    private let lock = NSLock()

    private func key(_ url: URL) -> String {
        (url.host ?? "") + ":" + String(url.port ?? (url.scheme == "https" ? 443 : 80))
    }

    func setCookies(from headers: [AnyHashable: Any], url: URL) {
        let fields = headers.map { ($0.key as? String ?? "", $0.value) } + (headers["Set-Cookie"] != nil ? [] : [])
        var found: [String] = []
        for (name, value) in fields where name.lowercased() == "set-cookie" {
            if let list = value as? [String] { found.append(contentsOf: list) }
            else if let s = value as? String { found.append(s) }
        }
        guard !found.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var dict = persisted()
        for raw in found {
            let parts = raw.split(separator: ";")
            guard let first = parts.first else { continue }
            let kv = first.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            let name = String(kv[0]).trimmingCharacters(in: .whitespaces)
            let value = String(kv[1]).trimmingCharacters(in: .whitespaces)
            let expired = parts.dropFirst().contains {
                let p = $0.trimmingCharacters(in: .whitespaces).lowercased()
                return p.hasPrefix("max-age=0") || p.contains("1970")
            }
            if expired || value.isEmpty { dict.removeValue(forKey: name) } else { dict[name] = value }
        }
        save(dict)
    }

    func header(for url: URL) -> String? {
        lock.lock(); defer { lock.unlock() }
        let dict = persisted()
        if dict.isEmpty { return nil }
        return dict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        save([:])
    }

    private var storageKey: String { "aigw.cookies" }

    private func persisted() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
    }

    private func save(_ d: [String: String]) {
        UserDefaults.standard.set(d, forKey: storageKey)
    }
}

/// HTTP 客户端
final class ApiClient: NSObject, URLSessionDataDelegate {
    static let shared = ApiClient()

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 300
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpCookieStorage = nil          // 自己管 cookie，保证跨重启可用
        cfg.httpShouldSetCookies = false
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    // MARK: 基础请求

    private func makeRequest(_ path: String, method: String, query: [String: String] = [:],
                             body: [String: Any]? = nil, bearer: String? = nil) throws -> URLRequest {
        guard let base = AppConfig.normalizedBase() else { throw ApiError.invalidURL }
        var comps = URLComponents(url: base.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            comps?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps?.url else { throw ApiError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("AIGW-iOS/1.0", forHTTPHeaderField: "X-AIGW-Client")
        if let bearer, !bearer.isEmpty {
            req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let cookie = SessionCookieStore.shared.header(for: url) {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    /// 普通 JSON 请求，返回 data 节点（无 data 时返回整个响应体）
    @discardableResult
    func request(_ path: String, method: String = "GET", query: [String: String] = [:],
                 body: [String: Any]? = nil, bearer: String? = nil) async throws -> JSONValue {
        let req = try makeRequest(path, method: method, query: query, body: body, bearer: bearer)
        let (data, resp) = try await send(req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if let http = resp as? HTTPURLResponse {
            SessionCookieStore.shared.setCookies(from: http.allHeaderFields, url: req.url!)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(code) else {
            let msg = Self.extractMessage(text) ?? text.prefix(200).description
            throw ApiError.http(code, msg)
        }
        return try Self.unwrap(data)
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw ApiError.network(error.localizedDescription)
        }
    }

    static func unwrap(_ data: Data) throws -> JSONValue {
        guard !data.isEmpty else { return .object([:]) }
        do {
            let env = try JSONDecoder().decode(ApiEnvelope.self, from: data)
            if let d = env.data { return d }
            if env.ok == false {
                throw ApiError.http(200, env.message ?? "请求失败")
            }
            return .object([:])
        } catch let e as ApiError {
            throw e
        } catch {
            // 某些端点直接返回数组
            if let v = try? JSONDecoder().decode(JSONValue.self, from: data) { return v }
            throw ApiError.decode(error.localizedDescription)
        }
    }

    static func extractMessage(_ text: String) -> String? {
        guard let d = text.data(using: .utf8),
              let v = try? JSONDecoder().decode(JSONValue.self, from: d) else { return nil }
        return v["message"]?.stringValue ?? v["error"]?["message"]?.stringValue
              ?? v["error"]?.stringValue ?? nil
    }

    // MARK: 流式 SSE

    /// 流式对话：回调增量文本
    func streamChat(path: String = "/v1/chat/completions", payload: [String: Any],
                    bearer: String,
                    onDelta: @escaping (String) -> Void,
                    onReasoning: @escaping (String) -> Void) async throws -> String {
        var body = payload
        body["stream"] = true
        let req = try makeRequest(path, method: "POST", body: body, bearer: bearer)
        return try await withCheckedThrowingContinuation { cont in
            let task = self.session.dataTask(with: req)
            let box = StreamBox(continuation: cont, onDelta: onDelta, onReasoning: onReasoning)
            self.streams[task.taskIdentifier] = box
            task.resume()
        }
    }

    private final class StreamBox {
        let continuation: CheckedContinuation<String, Error>
        let onDelta: (String) -> Void
        let onReasoning: (String) -> Void
        var buffer = ""
        var full = ""
        var code = 0
        var errBody = ""
        var finished = false

        init(continuation: CheckedContinuation<String, Error>,
             onDelta: @escaping (String) -> Void,
             onReasoning: @escaping (String) -> Void) {
            self.continuation = continuation
            self.onDelta = onDelta
            self.onReasoning = onReasoning
        }
    }

    private var streams: [Int: StreamBox] = [:]
    private let streamLock = NSLock()

    private func box(_ id: Int) -> StreamBox? {
        streamLock.lock(); defer { streamLock.unlock() }
        return streams[id]
    }

    private func drop(_ id: Int) -> StreamBox? {
        streamLock.lock(); defer { streamLock.unlock() }
        return streams.removeValue(forKey: id)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let b = box(dataTask.taskIdentifier) else { return }
        if let http = dataTask.response as? HTTPURLResponse, b.code == 0 { b.code = http.statusCode }
        if b.code >= 400 {
            b.errBody += String(data: data, encoding: .utf8) ?? ""
            return
        }
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        b.buffer += chunk
        while let r = b.buffer.range(of: "\n") {
            let line = String(b.buffer[b.buffer.startIndex..<r.lowerBound])
            b.buffer.removeSubrange(b.buffer.startIndex..<r.upperBound)
            Self.handle(line: line, box: b)
        }
    }

    private static func handle(line raw: String, box b: StreamBox) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("data:") else { return }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return }
        guard let d = payload.data(using: .utf8),
              let v = try? JSONDecoder().decode(JSONValue.self, from: d) else { return }

        // OpenAI chat.completion.chunk
        if let choices = v["choices"], case .array(let arr) = choices, let first = arr.first {
            if let delta = first["delta"]?["content"]?.stringValue, !delta.isEmpty {
                b.full += delta
                DispatchQueue.main.async { b.onDelta(delta) }
            }
            if let reasoning = first["delta"]?["reasoning_content"]?.stringValue, !reasoning.isEmpty {
                DispatchQueue.main.async { b.onReasoning(reasoning) }
            }
        }
        // Responses API 事件
        if let type = v["type"]?.stringValue {
            if type == "response.output_text.delta", let delta = v["delta"]?.stringValue {
                b.full += delta
                DispatchQueue.main.async { b.onDelta(delta) }
            }
        }
        if b.full.isEmpty, let text = v["choices"]?.objectValues.first?["message"]?["content"]?.stringValue {
            b.full += text
            DispatchQueue.main.async { b.onDelta(text) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let b = drop(task.taskIdentifier) else { return }
        if let error {
            if !b.full.isEmpty { b.continuation.resume(returning: b.full); return }
            b.continuation.resume(throwing: ApiError.network(error.localizedDescription)); return
        }
        let code = b.code == 0 ? (task.response as? HTTPURLResponse)?.statusCode ?? 200 : b.code
        if code >= 400 {
            let msg = ApiClient.extractMessage(b.errBody) ?? (b.errBody.isEmpty ? "请求失败" : b.errBody)
            b.continuation.resume(throwing: ApiError.http(code, String(msg.prefix(300))))
        } else {
            b.continuation.resume(returning: b.full)
        }
    }
}
