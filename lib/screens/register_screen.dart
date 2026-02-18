import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _selectedBirthday;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    final apiService = ApiService();
    _authService = AuthService(apiService: apiService);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _idCardController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '選擇生日',
      cancelText: '取消',
      confirmText: '確認',
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  String _formatBirthday(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBirthday == null) {
      _showErrorSnackBar('請選擇生日');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        idCard: _idCardController.text.trim().toUpperCase(),
        birthday: _formatBirthday(_selectedBirthday!),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('註冊成功！歡迎 ${user.username}'),
            backgroundColor: Colors.green,
          ),
        );

        // 註冊成功後導回登入頁
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } on ApiError catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('註冊失敗: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('註冊新帳號'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // Logo
                Icon(
                  Icons.person_add_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),

                Text(
                  '建立您的帳號',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '請填寫以下資料完成註冊',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 使用者名稱
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '使用者名稱',
                    hintText: '請輸入使用者名稱',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入使用者名稱';
                    }
                    if (value.trim().length < 2) {
                      return '使用者名稱至少需要 2 個字元';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 身分證字號
                TextFormField(
                  controller: _idCardController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '身分證字號',
                    hintText: '例：A123456789',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入身分證字號';
                    }
                    final id = value.trim().toUpperCase();
                    final regex = RegExp(r'^[A-Z][0-9]{9}$');
                    if (!regex.hasMatch(id)) {
                      return '身分證字號格式不正確（例：A123456789）';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 生日選擇
                InkWell(
                  onTap: _selectBirthday,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '生日',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: _formKey.currentState != null && _selectedBirthday == null
                          ? '請選擇生日'
                          : null,
                    ),
                    child: Text(
                      _selectedBirthday != null
                          ? _formatBirthday(_selectedBirthday!)
                          : '請選擇生日',
                      style: TextStyle(
                        color: _selectedBirthday != null
                            ? Colors.black87
                            : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 密碼
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '密碼',
                    hintText: '請設定密碼（至少 6 個字元）',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請輸入密碼';
                    }
                    if (value.length < 6) {
                      return '密碼至少需要 6 個字元';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 確認密碼
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '確認密碼',
                    hintText: '請再次輸入密碼',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '請確認密碼';
                    }
                    if (value != _passwordController.text) {
                      return '兩次密碼輸入不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // 註冊按鈕
                FilledButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '完成註冊',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // 返回登入
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('已有帳號？'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('返回登入'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}