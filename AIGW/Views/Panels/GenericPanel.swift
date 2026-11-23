import SwiftUI

/// 通用接口面板的查询定义
struct PanelQuery: Identifiable {
    let id = UUID()
    let title: String
    let path: String
    var method: String = "GET"
    var body: [String: Any]? = nil
    var needsLogin: Bool = true
}

/// 一个面板 = 若干 GET 查询 + 若干动作按钮，结果以可折叠 JSON 展示
struct GenericPanel: View {
    let title: String
    let queries: [PanelQuery]
    let actions: [PanelQuery]
    var footer: String? = nil

    @EnvironmentObject var app: AppState
    @State private var results: [UUID: JSONValue] = [:]
    @State private var errors: [UUID: String] = [:]
    @State private var loading: Set<UUID> = []
    @State private var expanded: UUID?

    var body: some View {
        List {
            if !app.loggedIn {
                Section {
                    NavigationLink("先登录") { LoginView() }
                }
            }
            if !queries.isEmpty {
                Section("数据") {
                    ForEach(queries) { q in
                        queryRow(q)
                    }
                }
            }
            if !actions.isEmpty {
                Section("操作") {
                    ForEach(actions) { q in
                        Button {
                            Task { await run(q, asAction: true) }
                        } label: {
                            HStack {
                                Text(q.title)
                                Spacer()
                                if loading.contains(q.id) { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(!app.loggedIn)
                    }
                }
            }
            if let footer {
                Section { Text(footer).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(title)
        .refreshable {
            for q in queries where results[q.id] == nil {
                await run(q, asAction: false)
            }
        }
        .task {
            for q in queries where results[q.id] == nil {
                await run(q, asAction: false)
            }
        }
    }

    @ViewBuilder
    private func queryRow(_ q: PanelQuery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded = expanded == q.id ? nil : q.id }
            } label: {
                HStack {
                    Text(q.title)
                    Spacer()
                    if loading.contains(q.id) { ProgressView().controlSize(.small) }
                    Image(systemName: expanded == q.id ? "chevron.down" : "chevron.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if let e = errors[q.id] {
                Text(e).font(.caption).foregroundStyle(.red)
            }

            if expanded == q.id {
                JSONBody(value: results[q.id])
                Button("刷新") { Task { await run(q, asAction: false) } }
                    .font(.footnote)
            } else if let v = results[q.id] {
                Text(summary(v))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func summary(_ v: JSONValue) -> String {
        if case .array(let a) = v { return "共 \(a.count) 条" }
        if case .object(let o) = v {
            let keys = o.keys.sorted().prefix(4).map { "\($0)=\(o[$0]!.stringValue.prefix(24))" }
            return keys.joined(separator: "，")
        }
        return v.stringValue
    }

    private func run(_ q: PanelQuery, asAction: Bool) async {
        loading.insert(q.id)
        errors[q.id] = nil
        if asAction { expanded = q.id }
        defer { loading.remove(q.id) }
        do {
            let v = try await ApiClient.shared.request(q.path, method: q.method, body: q.body)
            results[q.id] = v
            if asAction { app.show("\(q.title)：完成") }
        } catch {
            errors[q.id] = error.localizedDescription
        }
    }
}
