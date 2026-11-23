import SwiftUI

/// 装载图形验证码：/api/captcha 返回 PNG，写进同一会话 Cookie
@MainActor
final class CaptchaLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var loading = false
    @Published var error: String?

    private var tick = 0

    func reload() async {
        loading = true
        error = nil
        tick += 1
        let t = tick
        do {
            guard let base = AppConfig.normalizedBase() else { throw ApiError.invalidURL }
            let url = base.appendingPathComponent(API.captcha)
                .appending(queryItems: [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 * 1000)))])
            var req = URLRequest(url: url)
            req.setValue("AIGW-iOS/1.0", forHTTPHeaderField: "X-AIGW-Client")
            if let cookie = SessionCookieStore.shared.header(for: url) {
                req.setValue(cookie, forHTTPHeaderField: "Cookie")
            }
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                SessionCookieStore.shared.setCookies(from: http.allHeaderFields, url: url)
            }
            guard t == tick else { return }
            if let img = UIImage(data: data) {
                image = img
            } else if let text = String(data: data, encoding: .utf8) {
                error = ApiClient.extractMessage(text) ?? "验证码加载失败"
            }
        } catch {
            if t == tick { self.error = error.localizedDescription }
        }
        if t == tick { loading = false }
    }
}

struct CaptchaView: View {
    @StateObject private var loader = CaptchaLoader()
    @Binding var code: String

    var body: some View {
        HStack(spacing: 10) {
            TextField("图形验证码", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Group {
                if let img = loader.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if loader.loading {
                    ProgressView().frame(width: 96, height: 36)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 96, height: 36)
                        .overlay(Image(systemName: "arrow.clockwise").foregroundStyle(.secondary))
                }
            }
            .onTapGesture { Task { await loader.reload() } }
            if let e = loader.error {
                Text(e).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
        }
        .task { await loader.reload() }
    }
}
