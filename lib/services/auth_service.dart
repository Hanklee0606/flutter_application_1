import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// 認證服務 - 管理 JWT Token 和用戶狀態
class AuthService {
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage;
  
  User? _currentUser;
  
  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _rememberMeKey = 'remember_me';

  AuthService({
    ApiService? apiService,
    FlutterSecureStorage? secureStorage,
  })  : _apiService = apiService ?? ApiService(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 獲取當前用戶
  User? get currentUser => _currentUser;

  /// 是否已登入
  bool get isAuthenticated => _currentUser != null;

  /// 初始化 - 從存儲中恢復登入狀態
  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

      if (!rememberMe) {
        return false;
      }

      // 讀取 tokens
      final accessToken = await _secureStorage.read(key: _accessTokenKey);
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      if (accessToken == null || refreshToken == null) {
        return false;
      }

      // 設置 token
      _apiService.setAccessToken(accessToken);

      // 嘗試用當前 token 檢查認證
      try {
        _currentUser = await _apiService.checkAuth();
        return true;
      } catch (e) {
        // Token 可能過期，嘗試刷新
        try {
          final newAccessToken = await _apiService.refreshToken(refreshToken);
          await _secureStorage.write(key: _accessTokenKey, value: newAccessToken);
          _apiService.setAccessToken(newAccessToken);
          
          _currentUser = await _apiService.checkAuth();
          return true;
        } catch (e) {
          // 刷新失敗，清除所有資料
          await clearAuth();
          return false;
        }
      }
    } catch (e) {
      print('❌ 初始化認證失敗: $e');
      return false;
    }
  }

  /// 登入
  Future<User> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _apiService.login(username, password);

      // 保存 tokens
      await _secureStorage.write(
        key: _accessTokenKey,
        value: response.accessToken,
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: response.refreshToken,
      );

      // 保存記住我設置
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, rememberMe);

      // 設置當前用戶
      _currentUser = response.user;
      _apiService.setAccessToken(response.accessToken);

      return response.user;
    } catch (e) {
      rethrow;
    }
  }

  /// 註冊
  Future<User> register({
    required String username,
    required String password,
    required String idCard,
    required String birthday,
  }) async {
    try {
      final response = await _apiService.register(
        username: username,
        password: password,
        idCard: idCard,
        birthday: birthday,
      );

      // 保存 tokens
      await _secureStorage.write(
        key: _accessTokenKey,
        value: response.accessToken,
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: response.refreshToken,
      );

      // 設置當前用戶
      _currentUser = response.user;
      _apiService.setAccessToken(response.accessToken);

      // 默認記住登入狀態
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, true);

      return response.user;
    } catch (e) {
      rethrow;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      // 即使 API 調用失敗，也要清除本地資料
      print('⚠️ 登出 API 調用失敗: $e');
    } finally {
      await clearAuth();
    }
  }

  /// 清除認證資料
  Future<void> clearAuth() async {
    _currentUser = null;
    _apiService.setAccessToken(null);
    
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
  }

  /// 刷新用戶資料
  Future<void> refreshUserData() async {
    if (!isAuthenticated) return;
    
    try {
      _currentUser = await _apiService.checkAuth();
    } catch (e) {
      print('❌ 刷新用戶資料失敗: $e');
      rethrow;
    }
  }

  /// 獲取當前 access token
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// 獲取指紋狀態
  Future<bool> getFingerprintEnabled() async {
    try {
      final status = await _apiService.getFingerprintStatus();
      return status['fingerprint_enabled'] as bool? ?? false;
    } catch (e) {
      print('❌ 獲取指紋狀態失敗: $e');
      return false;
    }
  }

  /// 更新用戶指紋狀態
  void updateUserFingerprintStatus(bool enabled) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(fingerprintEnabled: enabled);
    }
  }

  /// 釋放資源
  void dispose() {
    _apiService.dispose();
  }
}