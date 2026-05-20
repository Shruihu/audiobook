class SmbConnect {
  static Future<SmbConnect> connectAuth({
    required String host,
    required String username,
    required String password,
    required String domain,
  }) async {
    throw UnsupportedError('SMB is not supported on web platform');
  }

  Future<dynamic> file(String path) async {
    throw UnsupportedError('SMB is not supported on web platform');
  }

  Future<List<dynamic>> listFiles(dynamic folder) async {
    throw UnsupportedError('SMB is not supported on web platform');
  }

  Future<List<Share>> listShares() async {
    throw UnsupportedError('SMB is not supported on web platform');
  }

  Future<void> close() async {}
}

class Share {
  final String name;

  Share({required this.name});
}