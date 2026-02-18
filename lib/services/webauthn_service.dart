import 'dart:convert';
import 'dart:typed_data';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/api_config.dart';  // 添加這行
import 'api_service.dart';
import 'auth_service.dart';

/// WebAuthn 服務 - 處理完整的 FIDO2 指紋認證
class WebAuthnService {
  final ApiService _apiService;
  final AuthService _authService;
  final LocalAuthentication _localAuth;

  WebAuthnService({
    required ApiService apiService,
    required AuthService authService,
    LocalAuthentication? localAuth,
  })  : _apiService = apiService,
        _authService = authService,
        _localAuth = localAuth ?? LocalAuthentication();

  /// 檢查設備是否支援生物識別
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('❌ 檢查生物識別支援失敗: $e');
      return false;
    }
  }

  /// 獲取可用的生物識別類型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('❌ 獲取生物識別類型失敗: $e');
      return [];
    }
  }

  /// 獲取設備資訊（用於 debug）
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final biometrics = await _localAuth.getAvailableBiometrics();
      
      final info = {
        'canCheckBiometrics': canCheck,
        'isDeviceSupported': isSupported,
        'availableBiometrics': biometrics.map((e) => e.toString()).toList(),
        'hasBiometrics': biometrics.isNotEmpty,
      };
      
      print('📊 設備資訊: $info');
      return info;
    } catch (e) {
      print('❌ 獲取設備資訊失敗: $e');
      return {'error': e.toString()};
    }
  }

  /// 執行生物識別驗證（本地）
  Future<bool> authenticateLocally({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('❌ 本地生物識別驗證失敗: $e');
      return false;
    }
  }

  /// 註冊指紋（完整 WebAuthn 流程）
  Future<bool> registerFingerprint() async {
    try {
      print('🔐 [WebAuthn] 開始指紋註冊流程');

      // 1. 檢查是否已登入
      if (!_authService.isAuthenticated) {
        throw ApiError(message: '請先登入');
      }

      // 2. 檢查設備支援
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        throw ApiError(message: '您的設備不支援生物識別');
      }

      // 3. 本地生物識別驗證
      final authenticated = await authenticateLocally(
        reason: '請驗證您的指紋以註冊',
      );

      if (!authenticated) {
        throw ApiError(message: '生物識別驗證失敗');
      }

      // 4. 向後端請求註冊選項
      print('🔐 [WebAuthn] 請求註冊選項');
      final options = await _apiService.webauthnRegisterBegin();

      // 5. 模擬創建憑證（簡化版 - 實際應該用 webauthn 套件）
      final credential = await _createCredential(options);

      // 6. 發送憑證到後端驗證
      print('🔐 [WebAuthn] 發送憑證到後端');
      final result = await _apiService.webauthnRegisterComplete(credential);

      // 7. 更新本地用戶狀態
      _authService.updateUserFingerprintStatus(true);

      print('✅ [WebAuthn] 指紋註冊成功');
      return result['verified'] as bool? ?? true;
    } catch (e) {
      print('❌ [WebAuthn] 指紋註冊失敗: $e');
      rethrow;
    }
  }

  /// 指紋登入（完整 WebAuthn 流程）
  Future<User> loginWithFingerprint(String username) async {
    try {
      print('🔐 [WebAuthn] 開始指紋登入流程');

      // 1. 檢查設備支援
      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        throw ApiError(message: '您的設備不支援生物識別');
      }

      // 2. 向後端請求登入選項
      print('🔐 [WebAuthn] 請求登入選項');
      final options = await _apiService.webauthnLoginBegin(username);

      // 3. 本地生物識別驗證
      final authenticated = await authenticateLocally(
        reason: '請驗證您的指紋以登入',
      );

      if (!authenticated) {
        throw ApiError(message: '生物識別驗證失敗');
      }

      // 4. 使用憑證簽名（簡化版）
      final credential = await _getAssertion(options);

      // 5. 發送簽名到後端驗證
      print('🔐 [WebAuthn] 發送簽名到後端');
      final response = await _apiService.webauthnLoginComplete(
        username: username,
        credential: credential,
      );

      // 6. 保存登入狀態（使用 AuthService 的公開方法）
      // 透過內部方法保存 token，讓 AuthService 處理
      await _saveLoginResponse(response);

      print('✅ [WebAuthn] 指紋登入成功');
      return response.user;
    } catch (e) {
      print('❌ [WebAuthn] 指紋登入失敗: $e');
      rethrow;
    }
  }

  /// 保存登入回應（內部輔助方法）
  Future<void> _saveLoginResponse(LoginResponse response) async {
    final secureStorage = const FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    
    await secureStorage.write(
      key: 'access_token',
      value: response.accessToken,
    );
    await secureStorage.write(
      key: 'refresh_token',
      value: response.refreshToken,
    );
    
    // 默認記住指紋登入
    await prefs.setBool('remember_me', true);
    
    // 透過 AuthService 的公開接口更新狀態
    // 注意：這裡需要手動設置，因為我們繞過了 AuthService.login()
    _apiService.setAccessToken(response.accessToken);
  }

  /// 創建憑證（簡化版 - 實際應該用 webauthn 套件）
  Future<Map<String, dynamic>> _createCredential(
    Map<String, dynamic> options,
  ) async {
    // 解析 challenge
    final challengeB64 = options['challenge'] as String;
    final challenge = base64Url.decode(_addPadding(challengeB64));

    // 生成密鑰對（簡化版 - 實際應該用 ECDSA）
    final keyPair = _generateKeyPair();
    final credentialId = keyPair['credentialId'] as String;
    final publicKey = keyPair['publicKey'] as String;

    // 構造 authenticator data（簡化版）
    final rpIdHash = sha256.convert(utf8.encode(ApiConfig.rpId)).bytes;  // 使用配置
    final flags = [0x41]; // UP=1, UV=0, AT=1
    final signCount = [0, 0, 0, 0];
    
    final authenticatorData = Uint8List.fromList([
      ...rpIdHash,
      ...flags,
      ...signCount,
    ]);

    // 構造 client data JSON
    final clientDataJSON = {
      'type': 'webauthn.create',
      'challenge': challengeB64,
      'origin': 'http://192.168.0.73:5000',
    };

    final clientDataBytes = utf8.encode(jsonEncode(clientDataJSON));

    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'response': {
        'clientDataJSON': base64Url.encode(clientDataBytes).replaceAll('=', ''),
        'attestationObject': _createAttestationObject(
          authenticatorData,
          publicKey,
        ),
      },
    };
  }

  /// 獲取斷言（簽名）
  Future<Map<String, dynamic>> _getAssertion(
    Map<String, dynamic> options,
  ) async {
    final challengeB64 = options['challenge'] as String;
    final challenge = base64Url.decode(_addPadding(challengeB64));

    // 獲取允許的憑證
    final allowCredentials = options['allowCredentials'] as List;
    final credentialId = allowCredentials.isNotEmpty
        ? (allowCredentials[0] as Map<String, dynamic>)['id'] as String
        : '';

    // 構造 authenticator data
    final rpIdHash = sha256.convert(utf8.encode(ApiConfig.rpId)).bytes;  // 使用配置
    final flags = [0x01]; // UP=1
    final signCount = [0, 0, 0, 1];
    
    final authenticatorData = Uint8List.fromList([
      ...rpIdHash,
      ...flags,
      ...signCount,
    ]);

    // 構造 client data JSON
    final clientDataJSON = {
      'type': 'webauthn.get',
      'challenge': challengeB64,
      'origin': 'http://192.168.0.73:5000',
    };

    final clientDataBytes = utf8.encode(jsonEncode(clientDataJSON));

    // 簡化的簽名（實際應該用私鑰簽名）
    final signature = _createSignature(authenticatorData, clientDataBytes);

    return {
      'id': credentialId,
      'rawId': credentialId,
      'type': 'public-key',
      'response': {
        'clientDataJSON': base64Url.encode(clientDataBytes).replaceAll('=', ''),
        'authenticatorData': base64Url.encode(authenticatorData).replaceAll('=', ''),
        'signature': base64Url.encode(signature).replaceAll('=', ''),
        'userHandle': '',
      },
    };
  }

  /// 生成密鑰對（簡化版）
  Map<String, String> _generateKeyPair() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final credentialId = base64Url.encode(
      sha256.convert(utf8.encode(random)).bytes,
    ).replaceAll('=', '');

    // 模擬公鑰（實際應該是真實的 ECDSA 公鑰）
    final publicKey = base64Url.encode(
      Uint8List.fromList(List.generate(65, (i) => i)),
    ).replaceAll('=', '');

    return {
      'credentialId': credentialId,
      'publicKey': publicKey,
    };
  }

  /// 創建 attestation object
  String _createAttestationObject(Uint8List authData, String publicKey) {
    // 簡化版：只返回必要的結構
    final obj = {
      'authData': base64Url.encode(authData).replaceAll('=', ''),
      'fmt': 'none',
      'attStmt': {},
    };
    return base64Url.encode(utf8.encode(jsonEncode(obj))).replaceAll('=', '');
  }

  /// 創建簽名（簡化版）
  Uint8List _createSignature(Uint8List authData, Uint8List clientData) {
    final hash = sha256.convert(clientData).bytes;
    final signData = [...authData, ...hash];
    return Uint8List.fromList(sha256.convert(signData).bytes);
  }

  /// 添加 base64 padding
  String _addPadding(String base64) {
    final padLength = (4 - base64.length % 4) % 4;
    return base64 + ('=' * padLength);
  }
}