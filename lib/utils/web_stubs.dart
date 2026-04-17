class File {
  final String path;
  File(this.path);
  Future<void> writeAsString(String content) async {}
  Future<String> readAsString() async => '';
  String readAsStringSync() => '';
  bool existsSync() => false;
}
