import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .login
    @State private var identifier = ""
    @State private var password = ""
    @State private var password2 = ""
    @State private var nickname = ""
    @State private var emailCode = ""
    @State private var captcha = ""
    @State private var config: JSONValue?
    @State private var busy = false
    @State private var error: String?
    @State private var info: String?

    enum Mode: String, CaseIterable { case login = "登录", register = "注册" }

    private var captchaNeeded: Bool {
        if mode == .login { return config?["captcha_enabled"]?.boolValue ?? false }
        return config?["register_captcha_needed"]?.boolValue ?? false
    }

    private var mailVerify: Bool {
        (config?["mail_verify"]?.boolValue ?? false) && (config?["mail_ready"]?.boolValue ?? false)
    }

    private var allowRegister: Bool { config?["allow_register"]?.boolValue ?? true }
    private var domainHint: String { config?["register_email_domains"]?.stringValue ?? "" }

    var body: some View {
        Form {
            Section {
                Picker("模式", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m as Mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("账号") {
                TextField("邮箱 / 用户名", text: $identifier)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("密码", text: $password)
                if mode == .register {
                    SecureField("确认密码", text: $password2)
                    TextField("昵称（可选）", text: $nickname)
                    if mailVerify {
                        HStack {
                            TextField("邮箱验证码", text: $emailCode)
                                .keyboardType(.numberPad)
                            Button("发送") { Task { await sendCode() } }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if captchaNeeded {
                Section {
                    CaptchaView(code: $captcha)
                } header: {
                    Text("图形验证码")
                }
            }

            if let info {
                Section { Text(info).font(.footnote).foregroundStyle(.secondary) }
            }
            if let error {
                Section { Text(error).font(.footnote).foregroundStyle(.red) }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView().padding(.trailing, 6) }
                        Text(mode == .login ? "登录" : "注册")
                        Spacer()
                    }
                }
                .disabled(busy || identifier.isEmpty || password.isEmpty)
            }

            if !allowRegister && mode == .register {
                Section {
                    Text("该实例已关闭注册，请向管理员申请账号。")
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("账号")
        .task { await loadConfig() }
    }

    private func loadConfig() async {
        do {
            config = try await ApiClient.shared.request(API.registerConfig)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendCode() async {
        guard !identifier.isEmpty else { error = "请先填邮箱"; return }
        do {
            _ = try await ApiClient.shared.request(API.emailCode, method: "POST",
                                                  body: ["email": identifier])
            info = "验证码已发送，请查收邮件"
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submit() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            if mode == .login {
                var body: [String: Any] = ["username": identifier, "password": password]
                if captchaNeeded { body["captcha"] = captcha }
                _ = try await ApiClient.shared.request(API.login, method: "POST", body: body)
            } else {
                guard password == password2 else { error = "两次密码不一致"; return }
                var body: [String: Any] = ["email": identifier, "password": password]
                if !nickname.isEmpty { body["nickname"] = nickname }
                if mailVerify, !emailCode.isEmpty { body["email_code"] = emailCode }
                if captchaNeeded { body["captcha"] = captcha }
                _ = try await ApiClient.shared.request(API.register, method: "POST", body: body)
            }
            await app.refreshMe()
            await app.loadModels()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
