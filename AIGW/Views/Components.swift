import SwiftUI

/// 轻量 Markdown 渲染：标题、列表、粗体、行内代码、围栏代码块（带复制）
struct MarkdownText: View {
    let text: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let lang, let code):
                    CodeBlockView(lang: lang, code: code, onCopy: onCopy)
                case .paragraph(let s):
                    Text(inline(s))
                        .textSelection(.enabled)
                case .heading(let level, let s):
                    Text(inline(s))
                        .font(level <= 2 ? .headline : .subheadline.weight(.semibold))
                        .textSelection(.enabled)
                case .bullet(let s):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(.secondary)
                        Text(inline(s)).textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    enum Block {
        case code(String, String)
        case paragraph(String)
        case heading(Int, String)
        case bullet(String)
    }

    var blocks: [Block] {
        var out: [Block] = []
        var buffer: [String] = []
        var codeLang: String?
        var codeLines: [String] = []

        func flush() {
            if !buffer.isEmpty {
                out.append(.paragraph(buffer.joined(separator: "\n")))
                buffer.removeAll()
            }
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let lang = codeLang {
                    out.append(.code(lang, codeLines.joined(separator: "\n")))
                    codeLines.removeAll(); codeLang = nil
                } else {
                    flush()
                    codeLang = String(trimmed.dropFirst(3))
                }
                continue
            }
            if codeLang != nil { codeLines.append(line); continue }
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix { $0 == "#" }.count
                flush()
                out.append(.heading(min(level, 4), String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flush()
                out.append(.bullet(String(trimmed.dropFirst(2))))
                continue
            }
            if trimmed.isEmpty {
                flush()
                continue
            }
            buffer.append(line)
        }
        flush()
        if let lang = codeLang {
            out.append(.code(lang, codeLines.joined(separator: "\n")))
        }
        return out.isEmpty ? [.paragraph(text)] : out
    }

    /// 行内 Markdown：**粗体**、`代码`
    func inline(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(raw)
        while !rest.isEmpty {
            if let r = rest.range(of: "**"),
               let close = rest[r.upperBound...].range(of: "**") {
                result += AttributedString(String(rest[rest.startIndex..<r.lowerBound]))
                var bold = AttributedString(String(rest[r.upperBound..<close.lowerBound]))
                bold.font = .body.bold()
                result += bold
                rest = rest[close.upperBound...]
                continue
            }
            if let r = rest.range(of: "`"),
               let close = rest[r.upperBound...].range(of: "`") {
                result += AttributedString(String(rest[rest.startIndex..<r.lowerBound]))
                var code = AttributedString(String(rest[r.upperBound..<close.lowerBound]))
                code.font = .system(.body, design: .monospaced)
                code.backgroundColor = Color.secondary.opacity(0.15)
                result += code
                rest = rest[close.upperBound...]
                continue
            }
            result += AttributedString(String(rest))
            break
        }
        return result
    }
}

struct CodeBlockView: View {
    let lang: String
    let code: String
    let onCopy: (String) -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.isEmpty ? "code" : lang)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onCopy(code)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 通用键值展示
struct KVRow: View {
    let key: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(key).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}

/// 把任意 JSON 渲染成可折叠的键值 / 列表
struct JSONDisclosure: View {
    let title: String
    let value: JSONValue?

    var body: some View {
        DisclosureGroup {
            JSONBody(value: value)
        } label: {
            Text(title).font(.subheadline.weight(.semibold))
        }
    }
}

struct JSONBody: View {
    let value: JSONValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch value {
            case .object(let dict):
                ForEach(Array(dict.keys.sorted()), id: \.self) { k in
                    let v = dict[k]!
                    if case .object = v {
                        JSONDisclosure(title: k, value: v)
                    } else if case .array = v {
                        JSONDisclosure(title: "\(k)（\(v.objectValues.count)）", value: v)
                    } else {
                        KVRow(key: k, value: v.stringValue)
                    }
                }
            case .array(let arr):
                ForEach(Array(arr.enumerated()), id: \.offset) { i, v in
                    if case .object = v {
                        JSONDisclosure(title: "#\(i + 1)", value: v)
                    } else {
                        KVRow(key: "#\(i + 1)", value: v.stringValue)
                    }
                }
            case .none:
                Text("无数据").font(.footnote).foregroundStyle(.secondary)
            default:
                Text(value?.stringValue ?? "").font(.footnote).textSelection(.enabled)
            }
        }
        .padding(.leading, 4)
    }
}
