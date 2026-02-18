import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';

/// API 服務 - 處理所有 HTTP 請求
class ApiService {
  final http.Client _client;
  String? _accessToken;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 設置 access token
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// 獲取通用 headers
  Map<String, String> _getHeaders({bool includeAuth = false}) {
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };

    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  /// 處理 HTTP 錯誤
  ApiError _handleError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiError.fromJson(json);
    } catch (e) {
      return ApiError(
        message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        statusCode: response.statusCode,
      );
    }
  }

  /// POST 請求
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final response = await _client
          .post(
            url,
            headers: _getHeaders(includeAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.connectTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(message: '網路錯誤: $e');
    }
  }

  /// GET 請求
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requiresAuth = false,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final response = await _client
          .get(
            url,
            headers: _getHeaders(includeAuth: requiresAuth),
          )
          .timeout(ApiConfig.connectTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(message: '網路錯誤: $e');
    }
  }

  /// 登入
  Future<LoginResponse> login(String username, String password) async {
    final response = await post(
      ApiConfig.loginEndpoint,
      body: {
        'username': username,
        'password': password,
      },
    );

    return LoginResponse.fromJson(response);
  }

  /// 註冊
  Future<LoginResponse> register({
    required String username,
    required String password,
    required String idCard,
    required String birthday,
  }) async {
    final response = await post(
      ApiConfig.registerEndpoint,
      body: {
        'username': username,
        'password': password,
        'id_card': idCard,
        'birthday': birthday,
      },
    );

    return LoginResponse.fromJson(response);
  }

  /// 刷新 Token
  Future<String> refreshToken(String refreshToken) async {
    // 暫時保存當前 token
    final oldToken = _accessToken;
    _accessToken = refreshToken;

    try {
      final response = await post(
        ApiConfig.refreshEndpoint,
        requiresAuth: true,
      );

      return response['access_token'] as String;
    } catch (e) {
      // 恢復舊 token
      _accessToken = oldToken;
      rethrow;
    }
  }

  /// 檢查認證狀態
  Future<User> checkAuth() async {
    final response = await get(
      ApiConfig.checkAuthEndpoint,
      requiresAuth: true,
    );

    return User.fromJson(response['user'] as Map<String, dynamic>);
  }

  /// 登出
  Future<void> logout() async {
    await post(
      '/api/auth/logout',
      requiresAuth: true,
    );
  }

  /// 獲取指紋狀態
  Future<Map<String, dynamic>> getFingerprintStatus() async {
    return await get(
      ApiConfig.fingerprintStatusEndpoint,
      requiresAuth: true,
    );
  }

  /// WebAuthn 註冊 - 開始
  Future<Map<String, dynamic>> webauthnRegisterBegin() async {
    return await post(
      ApiConfig.webauthnRegisterBegin,
      requiresAuth: true,
    );
  }

  /// WebAuthn 註冊 - 完成
  Future<Map<String, dynamic>> webauthnRegisterComplete(
    Map<String, dynamic> credential,
  ) async {
    return await post(
      ApiConfig.webauthnRegisterComplete,
      body: credential,
      requiresAuth: true,
    );
  }

  /// WebAuthn 登入 - 開始
  Future<Map<String, dynamic>> webauthnLoginBegin(String username) async {
    return await post(
      ApiConfig.webauthnLoginBegin,
      body: {'username': username},
    );
  }

  /// WebAuthn 登入 - 完成
  Future<LoginResponse> webauthnLoginComplete({
    required String username,
    required Map<String, dynamic> credential,
  }) async {
    final response = await post(
      ApiConfig.webauthnLoginComplete,
      body: {
        'username': username,
        'credential': credential,
      },
    );

    return LoginResponse.fromJson(response);
  }

  /// 釋放資源
  void dispose() {
    _client.close();
  }
}