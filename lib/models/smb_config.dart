import 'dart:convert';
import 'package:flutter/foundation.dart';

class SmbConfig {
  final String host;
  final String share;
  final String? username;
  final String? password;
  final String? domain;

  SmbConfig({
    required this.host,
    required this.share,
    this.username,
    this.password,
    this.domain,
  });

  String get displayName => '$host/$share';

  String buildSmbUrl(String path) {
    final credentials = username != null && username!.isNotEmpty
        ? '$username:${password ?? ''}@'
        : '';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    // 对路径进行 URL 编码（保留斜杠）
    final encodedPath = cleanPath
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    
    final url = 'smb://$credentials$host/$share/$encodedPath';
    debugPrint('SMB URL: $url');
    return url;
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'share': share,
        'username': username,
        'password': password,
        'domain': domain,
      };

  factory SmbConfig.fromJson(Map<String, dynamic> json) => SmbConfig(
        host: json['host'] as String,
        share: json['share'] as String,
        username: json['username'] as String?,
        password: json['password'] as String?,
        domain: json['domain'] as String?,
      );

  String encode() => jsonEncode(toJson());

  factory SmbConfig.decode(String source) =>
      SmbConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
