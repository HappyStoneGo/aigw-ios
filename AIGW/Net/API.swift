import Foundation

/// 后端 108 个用户端接口的集中定义（对齐 aigw-backend routes/user.php）
enum API {
    // 鉴权 / 账号
    static let captcha = "/api/captcha"
    static let registerConfig = "/api/user/register-config"
    static let emailCode = "/api/user/email-code"
    static let register = "/api/user/register"
    static let login = "/api/user/login"
    static let logout = "/api/user/logout"
    static let me = "/api/user/me"
    static let profile = "/api/user/profile"
    static let password = "/api/user/password"
    static let resetPassword = "/api/user/reset-password"
    static let regenerateKey = "/api/user/api-key/regenerate"
    static let dashboard = "/api/user/dashboard"

    // 账号池
    static let poolOverview = "/api/user/account-pool/overview"
    static let accounts = "/api/user/accounts"
    static let checkinAll = "/api/user/accounts/checkin-all"
    static let refreshAll = "/api/user/accounts/refresh-all"
    static let tasksAll = "/api/user/accounts/tasks-all"
    static let travelAll = "/api/user/accounts/travel-all"
    static let activityAll = "/api/user/accounts/activity-all"
    static let checkinLogs = "/api/user/accounts/checkin-logs"
    static let travelLogs = "/api/user/accounts/travel-logs"
    static let activityLogs = "/api/user/accounts/activity-logs"
    static let actionTask = "/api/user/accounts/action-task"
    static let growth = "/api/user/accounts/growth"
    static let creditsMonitor = "/api/user/accounts/credits/monitor"

    // 供应商 / 模型
    static let providers = "/api/user/providers"
    static let models = "/api/user/models"
    static let modelsSync = "/api/user/models/sync"
    static let toggleProvider = "/api/user/models/toggle-provider"
    static let modelProfiles = "/api/user/model-profiles"

    // 设置 / 模板 / Persona
    static let settings = "/api/user/settings"
    static let chatSettings = "/api/user/chat-settings"
    static let promptTemplates = "/api/user/prompt-templates"
    static let personas = "/api/user/personas"
    static let personaPlatform = "/api/user/personas/platform"
    static let personaEnable = "/api/user/personas/enable"
    static let personaSelfcheck = "/api/user/personas/selfcheck"

    // 会话资产
    static let worldbook = "/api/user/worldbook"
    static let worldbookImport = "/api/user/worldbook/import"
    static let worldbookTest = "/api/user/worldbook/test"
    static let characterCards = "/api/user/character-cards"
    static let characterImport = "/api/user/character-cards/import"
    static let memory = "/api/user/memory"
    static let memoryClear = "/api/user/memory/clear"
    static let memoryRecall = "/api/user/memory/recall"

    // 扩展能力
    static let mcp = "/api/user/mcp"
    static let mcpTools = "/api/user/mcp/tools"
    static let mcpInvoke = "/api/user/mcp/invoke"
    static let mcpTest = "/api/user/mcp/test"
    static let plugins = "/api/user/plugins"
    static let pluginCaps = "/api/user/plugins/capabilities"
    static let pluginValidate = "/api/user/plugins/validate"
    static let subagentRuns = "/api/user/subagent/runs"
    static let subagentRun = "/api/user/subagent/run"
    static let workflows = "/api/user/workflows"
    static let workflowValidate = "/api/user/workflows/validate"
    static let tools = "/api/user/tools"
    static let toolsInvoke = "/api/user/tools/invoke"
    static let research = "/api/user/research"
    static let speechCaps = "/api/user/speech/capabilities"
    static let speechLogs = "/api/user/speech/logs"
    static let speechSTT = "/api/user/speech/stt"
    static let speechTTS = "/api/user/speech/tts"
    static let envInfo = "/api/user/env/info"
    static let envPackages = "/api/user/env/packages"
    static let envVariables = "/api/user/env/variables"
    static let plan = "/api/user/plan"
    static let planGenerate = "/api/user/plan/generate"
    static let planConfirm = "/api/user/plan/confirm"

    // 日志 / 审计
    static let logs = "/api/user/logs"
    static let logsDetail = "/api/user/logs/detail"
    static let logsStats = "/api/user/logs/stats"
    static let logsExport = "/api/user/logs/export"
    static let audit = "/api/user/audit"
    static let auditTimeline = "/api/user/audit/timeline"

    // 上游账号 OAuth
    static func authStart(_ provider: String) -> String { "/api/user/auth/\(provider)/start" }
    static func authPoll(_ provider: String) -> String { "/api/user/auth/\(provider)/poll" }
    static func authCallback(_ provider: String) -> String { "/api/user/auth/\(provider)/callback" }

    // 网关（OpenAI 兼容）
    static let health = "/v1/health"
    static let v1Models = "/v1/models"
    static let chatCompletions = "/v1/chat/completions"
    static let responses = "/v1/responses"
}

/// 动态路径拼接
enum APIPath {
    static func accounts(_ id: JSONValue) -> String { "\(API.accounts)/\(id.stringValue)" }
    static func models(_ id: JSONValue) -> String { "\(API.models)/\(id.stringValue)" }
    static func persona(_ id: JSONValue) -> String { "\(API.personas)/\(id.stringValue)" }
    static func mcp(_ id: JSONValue) -> String { "\(API.mcp)/\(id.stringValue)" }
    static func plugin(_ id: JSONValue) -> String { "\(API.plugins)/\(id.stringValue)" }
    static func memory(_ id: JSONValue) -> String { "\(API.memory)/\(id.stringValue)" }
    static func worldbook(_ id: JSONValue) -> String { "\(API.worldbook)/\(id.stringValue)" }
    static func character(_ id: JSONValue) -> String { "\(API.characterCards)/\(id.stringValue)" }
    static func template(_ id: JSONValue) -> String { "\(API.promptTemplates)/\(id.stringValue)" }
    static func profile(_ id: JSONValue) -> String { "\(API.modelProfiles)/\(id.stringValue)" }
    static func workflow(_ id: JSONValue) -> String { "\(API.workflows)/\(id.stringValue)" }
    static func envVar(_ id: JSONValue) -> String { "\(API.envVariables)/\(id.stringValue)" }
    static func provider(_ key: String) -> String { "\(API.providers)/\(key)" }
}
