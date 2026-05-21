import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/audiobookshelf_config.dart';

class AbsLibrary {
  final String id;
  final String name;
  final String mediaType;
  final int displayOrder;

  AbsLibrary({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.displayOrder,
  });

  factory AbsLibrary.fromJson(Map<String, dynamic> json) => AbsLibrary(
        id: json['id'] as String,
        name: json['name'] as String,
        mediaType: json['mediaType'] as String? ?? 'book',
        displayOrder: json['displayOrder'] as int? ?? 0,
      );
}

class AbsAudioTrack {
  final String title;
  final String contentUrl;
  final int index;
  final double? duration;

  AbsAudioTrack({
    required this.title,
    required this.contentUrl,
    required this.index,
    this.duration,
  });

  factory AbsAudioTrack.fromJson(Map<String, dynamic> json) => AbsAudioTrack(
        title: json['title'] as String? ?? '',
        contentUrl: json['contentUrl'] as String? ?? '',
        index: json['index'] as int? ?? 0,
        duration: json['duration'] as double?,
      );
}

class AbsLibraryItem {
  final String id;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String mediaType;
  final List<AbsAudioTrack> tracks;
  final Map<String, dynamic>? media; // 保存原始 media 数据

  AbsLibraryItem({
    required this.id,
    this.title,
    this.author,
    this.coverUrl,
    required this.mediaType,
    required this.tracks,
    this.media,
  });
}

class AudioBookshelfService {
  AudioBookshelfConfig? _config;
  String? _token;

  bool get isConnected => _token != null;
  AudioBookshelfConfig? get config => _config;

  Future<void> connect(AudioBookshelfConfig config) async {
    _config = config;

    final uri = _buildUri('/audiobookshelf/login');
    
    final loginBody = jsonEncode({
      'username': config.username ?? 'root',
      'password': config.password ?? '',
    });
    
    debugPrint('Connecting to AudioBookshelf: ${uri.toString()}');
    debugPrint('Request body: $loginBody');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: loginBody,
    );

    debugPrint('Login response status: ${response.statusCode}');
    debugPrint('Login response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // 从 user 对象中获取 token
      _token = data['user']?['token'] as String?;
      if (_token == null) {
        throw Exception('无法获取认证token');
      }
      debugPrint('Login successful, token obtained');
    } else if (response.statusCode == 401) {
      throw Exception('认证失败：用户名或密码错误');
    } else if (response.statusCode == 404) {
      throw Exception('服务器地址错误：找不到 AudioBookshelf API');
    } else {
      throw Exception('连接失败: HTTP ${response.statusCode}\n${response.body}');
    }
  }

  Future<List<AbsLibrary>> getLibraries() async {
    _ensureConnected();

    final uri = _buildUri('/api/libraries');
    final response = await http.get(
      uri,
      headers: _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final libraries = data['libraries'] as List<dynamic>?;
      return libraries
              ?.map((l) => AbsLibrary.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [];
    } else {
      throw Exception('获取图书馆失败: ${response.statusCode}');
    }
  }

  Future<AbsLibraryItem> getLibraryItem(String itemId) async {
    _ensureConnected();

    final uri = _buildUri('/api/items/$itemId');
    final response = await http.get(
      uri,
      headers: _authHeaders(),
    );

    if (response.statusCode == 200) {
      return _parseLibraryItem(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('获取书籍失败: ${response.statusCode}');
    }
  }

  Future<List<AbsLibraryItem>> getLibraryItems(String libraryId,
      {int page = 0, int limit = 50}) async {
    _ensureConnected();

    final uri = _buildUri('/api/libraries/$libraryId/items');
    final response = await http.get(
      uri.replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        'expand': '1',  // 展开详细信息
        'include': 'media.tracks,media.audioFiles',  // 包含完整的音轨数据
      }),
      headers: _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      return results
              ?.map((i) => _parseLibraryItem(i as Map<String, dynamic>))
              .toList() ??
          [];
    } else {
      throw Exception('获取书籍列表失败: ${response.statusCode}');
    }
  }

  Future<String> getStreamUrl(String itemId) async {
    _ensureConnected();

    final item = await getLibraryItem(itemId);
    if (item.tracks.isEmpty) {
      throw Exception('该书籍没有音轨');
    }

    return item.tracks.first.contentUrl;
  }

  Future<void> disconnect() async {
    _token = null;
    _config = null;
  }

  void _ensureConnected() {
    if (_token == null) {
      throw StateError('未连接到 AudioBookshelf 服务器');
    }
  }

  Uri _buildUri(String path) {
    final url = _config!.serverUrl;
    final normalizedUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return Uri.parse('$normalizedUrl$path');
  }

  String buildFullUrl(String path) {
    final url = _config!.serverUrl;
    final normalizedUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return '$normalizedUrl$path';
  }

  Map<String, String> _authHeaders() => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  AbsLibraryItem _parseLibraryItem(Map<String, dynamic> json) {
    debugPrint('\n=== Parsing library item ===');
    debugPrint('Item ID: ${json['id']}');
    debugPrint('Top-level keys: ${json.keys.toList()}');
    
    final media = json['media'] as Map<String, dynamic>?;
    debugPrint('Media keys: ${media?.keys.toList()}');
    debugPrint('Media full data: $media');
    
    // 尝试从多个位置获取音轨
    final tracks = <AbsAudioTrack>[];
    
    // 优先从 media.tracks 获取（AudioBookshelf 的标准格式）
    final mediaTracks = media?['tracks'] as List<dynamic>?;
    debugPrint('media.tracks found: ${mediaTracks != null}, count: ${mediaTracks?.length ?? 0}');
    
    if (mediaTracks != null && mediaTracks.isNotEmpty) {
      for (final track in mediaTracks) {
        final trackJson = track as Map<String, dynamic>;
        debugPrint('Processing track: index=${trackJson['index']}, title=${trackJson['title']}');
        tracks.add(AbsAudioTrack(
          title: trackJson['title'] as String? ?? 
                 trackJson['metadata']?['filename'] as String? ?? '',
          contentUrl: buildFullUrl(trackJson['contentUrl'] as String? ?? ''),
          index: trackJson['index'] as int? ?? 0,
          duration: trackJson['duration'] as double?,
        ));
      }
    }
    
    // 如果 media.tracks 为空，尝试从 media.audioFiles 获取
    if (tracks.isEmpty) {
      debugPrint('media.tracks is empty, trying media.audioFiles');
      final audioFiles = media?['audioFiles'] as List<dynamic>?;
      debugPrint('media.audioFiles found: ${audioFiles != null}, count: ${audioFiles?.length ?? 0}');
      
      if (audioFiles != null) {
        for (final file in audioFiles) {
          if (file is Map<String, dynamic>) {
            debugPrint('Processing audioFile: ${file['metadata']?['filename']}');
            tracks.add(AbsAudioTrack(
              title: file['metadata']?['filename'] as String? ?? '',
              contentUrl: buildFullUrl(file['contentUrl'] as String? ?? ''),
              index: file['index'] as int? ?? 0,
              duration: file['duration'] as double?,
            ));
          }
        }
      }
    }

    debugPrint('Final parsed library item: ${media?['metadata']?['title']}, tracks count: ${tracks.length}');
    debugPrint('========================\n');

    return AbsLibraryItem(
      id: json['id'] as String,
      title: media?['metadata']?['title'] as String?,
      author: media?['metadata']?['authorName'] as String?,
      coverUrl: json['coverUrl'] != null ? buildFullUrl(json['coverUrl'] as String) : null,
      mediaType: json['mediaType'] as String? ?? 'book',
      tracks: tracks,
      media: media, // 保存完整的 media 数据
    );
  }
}