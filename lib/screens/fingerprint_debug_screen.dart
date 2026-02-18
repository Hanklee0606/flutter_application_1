import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/webauthn_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class FingerprintDebugScreen extends StatefulWidget {
  const FingerprintDebugScreen({super.key});

  @override
  State<FingerprintDebugScreen> createState() => _FingerprintDebugScreenState();
}

class _FingerprintDebugScreenState extends State<FingerprintDebugScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final List<String> _logs = [];
  bool _isLoading = false;
  
  late WebAuthnService _webAuthnService;

  @override
  void initState() {
    super.initState();
    _initServices();
    _addLog('🔍 Debug 頁面已載入');
  }

  void _initServices() {
    final apiService = ApiService();
    final authService = AuthService(apiService: apiService);
    _webAuthnService = WebAuthnService(
      apiService: apiService,
      authService: authService,
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    print(message);
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _testBasicBiometrics() async {
    _clearLogs();
    _addLog('========== 測試 1: 基本生物識別功能 ==========');
    setState(() => _isLoading = true);

    try {
      // 1. canCheckBiometrics
      _addLog('📊 檢查 canCheckBiometrics...');
      final canCheck = await _localAuth.canCheckBiometrics;
      _addLog('✅ canCheckBiometrics: $canCheck');

      // 2. isDeviceSupported
      _addLog('📊 檢查 isDeviceSupported...');
      final isSupported = await _localAuth.isDeviceSupported();
      _addLog('✅ isDeviceSupported: $isSupported');

      // 3. getAvailableBiometrics
      _addLog('📊 獲取可用的生物識別類型...');
      final biometrics = await _localAuth.getAvailableBiometrics();
      _addLog('✅ 可用類型: $biometrics');

      if (biometrics.isEmpty) {
        _addLog('⚠️ 警告: 沒有可用的生物識別方式');
        _addLog('💡 可能原因:');
        _addLog('   1. 設備沒有指紋感應器');
        _addLog('   2. 設備未設定指紋');
        _addLog('   3. 權限未授予');
      }

      _addLog('========== 測試 1 完成 ==========');
    } catch (e, stackTrace) {
      _addLog('❌ 錯誤: $e');
      _addLog('Stack: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSimpleAuth() async {
    _clearLogs();
    _addLog('========== 測試 2: 簡單驗證 (biometricOnly: false) ==========');
    setState(() => _isLoading = true);

    try {
      _addLog('🔐 開始驗證...');
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: '測試指紋驗證',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        _addLog('✅ 驗證成功！');
      } else {
        _addLog('❌ 驗證失敗');
      }

      _addLog('========== 測試 2 完成 ==========');
    } catch (e, stackTrace) {
      _addLog('❌ 驗證異常: $e');
      _addLog('Stack: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testStrictAuth() async {
    _clearLogs();
    _addLog('========== 測試 3: 嚴格驗證 (biometricOnly: true) ==========');
    setState(() => _isLoading = true);

    try {
      _addLog('🔐 開始嚴格驗證（僅生物識別）...');
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: '測試嚴格指紋驗證',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        _addLog('✅ 嚴格驗證成功！');
      } else {
        _addLog('❌ 嚴格驗證失敗');
      }

      _addLog('========== 測試 3 完成 ==========');
    } catch (e, stackTrace) {
      _addLog('❌ 嚴格驗證異常: $e');
      _addLog('Stack: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testWebAuthnService() async {
    _clearLogs();
    _addLog('========== 測試 4: WebAuthn Service 檢查 ==========');
    setState(() => _isLoading = true);

    try {
      // 1. canCheckBiometrics
      _addLog('📊 WebAuthn: canCheckBiometrics...');
      final canCheck = await _webAuthnService.canCheckBiometrics();
      _addLog('✅ 結果: $canCheck');

      // 2. getAvailableBiometrics
      _addLog('📊 WebAuthn: getAvailableBiometrics...');
      final biometrics = await _webAuthnService.getAvailableBiometrics();
      _addLog('✅ 結果: $biometrics');

      // 3. getDeviceInfo
      _addLog('📊 WebAuthn: getDeviceInfo...');
      final info = await _webAuthnService.getDeviceInfo();
      _addLog('✅ 設備資訊:');
      info.forEach((key, value) {
        _addLog('   $key: $value');
      });

      // 4. authenticateLocally
      _addLog('📊 WebAuthn: authenticateLocally...');
      _addLog('🔐 準備顯示驗證對話框...');
      
      final authenticated = await _webAuthnService.authenticateLocally(
        reason: 'WebAuthn Service 測試驗證',
      );
      
      _addLog('✅ authenticateLocally 結果: $authenticated');

      _addLog('========== 測試 4 完成 ==========');
    } catch (e, stackTrace) {
      _addLog('❌ WebAuthn Service 測試失敗: $e');
      _addLog('Stack: ${stackTrace.toString().substring(0, 200)}...');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('指紋 Debug 工具'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: '清除日誌',
          ),
        ],
      ),
      body: Column(
        children: [
          // 測試按鈕
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testBasicBiometrics,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('測試 1: 基本功能檢查'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testSimpleAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('測試 2: 簡單驗證'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testStrictAuth,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('測試 3: 嚴格驗證'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testWebAuthnService,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('測試 4: WebAuthn Service'),
                ),
              ],
            ),
          ),

          const Divider(),

          // 日誌區域
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bug_report,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '選擇上方按鈕開始測試',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color textColor = Colors.black87;
                      
                      if (log.contains('❌')) {
                        textColor = Colors.red;
                      } else if (log.contains('✅')) {
                        textColor = Colors.green;
                      } else if (log.contains('⚠️')) {
                        textColor = Colors.orange;
                      } else if (log.contains('🔐') || log.contains('📊')) {
                        textColor = Colors.blue;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 載入指示器
          if (_isLoading)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}