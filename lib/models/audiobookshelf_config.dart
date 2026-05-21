import 'dart:convert';

class AudioBookshelfConfig {
  final String serverUrl;
  final String? username;
  final String? password;

  AudioBookshelfConfig({
    required this.serverUrl,
    this.username,
    this.password,
  });

  String get displayName => username ?? serverUrl;

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };

  factory AudioBookshelfConfig.fromJson(Map<String, dynamic> json) =>
      AudioBookshelfConfig(
        serverUrl: json['serverUrl'] as String,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory AudioBookshelfConfig.decode(String source) =>
      AudioBookshelfConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  AudioBookshelfConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
  }) =>
      AudioBookshelfConfig(
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
      );
}