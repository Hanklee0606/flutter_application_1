/// API 配置
class ApiConfig {
  // 基礎 URL - 使用固定 ngrok URL
  static const String baseUrl = 'https://flowing-locally-gecko.ngrok-free.app';
  
  // WebAuthn RP ID (必須與後端一致)
  static const String rpId = 'flowing-locally-gecko.ngrok-free.app';
  
  // WebAuthn Origin
  static const String origin = 'https://flowing-locally-gecko.ngrok-free.app';
  
  // API 端點
  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String refreshEndpoint = '/api/auth/refresh';
  static const String checkAuthEndpoint = '/api/check-auth';
  
  // WebAuthn 端點
  static const String webauthnRegisterBegin = '/api/webauthn/register/begin';
  static const String webauthnRegisterComplete = '/api/webauthn/register/complete';
  static const String webauthnLoginBegin = '/api/webauthn/login/begin';
  static const String webauthnLoginComplete = '/api/webauthn/login/complete';
  
  // 投票端點
  static const String pollsEndpoint = '/api/polls';
  static const String voteEndpoint = '/api/vote';
  
  // 用戶端點
  static const String fingerprintStatusEndpoint = '/api/user/fingerprint/status';
  
  // 超時設置
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}