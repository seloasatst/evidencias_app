class LoginRequest {
  final String user;
  final String password;

  LoginRequest({required this.user, required this.password});

  Map<String, dynamic> toJson() => {
    "user": user.trim(),
    "password": password,
  };
}

class AuthUser {
  final String code;
  final String username;
  final String name;
  final String type;
  final String? cardCode;

  AuthUser({
    required this.code,
    required this.username,
    required this.name,
    required this.type,
    this.cardCode,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    code: (json["code"] ?? "").toString(),
    username: (json["username"] ?? "").toString(),
    name: (json["name"] ?? "").toString(),
    type: (json["type"] ?? "").toString(),
    cardCode: json["cardCode"]?.toString(),
  );
}

class LoginResponse {
  final String token;
  final AuthUser user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: (json["token"] ?? "").toString(),
    user: AuthUser.fromJson(Map<String, dynamic>.from(json["user"] ?? {})),
  );
}
