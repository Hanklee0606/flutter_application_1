/// 用戶模型
class User {
  final int id;
  final String username;
  final String idCard;
  final bool isAdmin;
  final bool fingerprintEnabled;

  User({
    required this.id,
    required this.username,
    required this.idCard,
    required this.isAdmin,
    required this.fingerprintEnabled,
  });

  /// 從 JSON 創建
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      idCard: json['id_card'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      fingerprintEnabled: json['fingerprint_enabled'] as bool? ?? false,
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'id_card': idCard,
      'is_admin': isAdmin,
      'fingerprint_enabled': fingerprintEnabled,
    };
  }

  /// 複製並修改
  User copyWith({
    int? id,
    String? username,
    String? idCard,
    bool? isAdmin,
    bool? fingerprintEnabled,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      idCard: idCard ?? this.idCard,
      isAdmin: isAdmin ?? this.isAdmin,
      fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, isAdmin: $isAdmin, fingerprintEnabled: $fingerprintEnabled)';
  }
}

/// 登入回應
class LoginResponse {
  final String message;
  final String accessToken;
  final String refreshToken;
  final User user;

  LoginResponse({
    required this.message,
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// API 錯誤回應
class ApiError {
  final String message;
  final int? statusCode;

  ApiError({
    required this.message,
    this.statusCode,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['error'] as String? ?? json['message'] as String? ?? '未知錯誤',
    );
  }

  @override
  String toString() => message;
}