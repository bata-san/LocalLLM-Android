import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/hf_model.dart';

class HfService {
  static const _apiBase = 'https://huggingface.co/api/models';
  static const _cdnBase = 'https://huggingface.co';

  Future<List<HfFile>> listGgufFiles(String repoId) async {
    final url = Uri.parse('$_apiBase/$repoId');
    final resp = await http.get(url, headers: {'Accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('HuggingFace API error ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final siblings = data['siblings'] as List<dynamic>? ?? [];
    return siblings
      .map((s) => HfFile.fromMap(s as Map<String, dynamic>))
      .where((f) => f.name.toLowerCase().endsWith('.gguf'))
      .toList();
  }

  Future<String> get _modelsDir async {
    final dir = await getApplicationDocumentsDirectory();
    final models = Directory('${dir.path}/models');
    if (!await models.exists()) await models.create(recursive: true);
    return models.path;
  }

  Future<String?> findLocalFile(String fileName) async {
    final dir = await _modelsDir;
    final f = File('$dir/$fileName');
    return await f.exists() ? f.path : null;
  }

  Future<List<FileSystemEntity>> listLocalModels() async {
    final dir = Directory(await _modelsDir);
    if (!await dir.exists()) return [];
    return dir
      .listSync()
      .where((e) => e.path.endsWith('.gguf'))
      .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  Stream<DownloadProgress> download(
    String repoId,
    String fileName,
  ) async* {
    final dir = await _modelsDir;
    final dest = File('$dir/$fileName');
    final url = '$_cdnBase/$repoId/resolve/main/$fileName';

    final req = http.Request('GET', Uri.parse(url));
    req.headers['Accept'] = 'application/octet-stream';

    final respStream = await req.send();
    if (respStream.statusCode != 200) {
      throw Exception('Download failed: ${respStream.statusCode}');
    }

    final total = respStream.contentLength ?? 0;
    var received = 0;
    final sink = dest.openWrite();

    await for (final chunk in respStream.stream) {
      sink.add(chunk);
      received += chunk.length;
      yield DownloadProgress(received, total);
    }

    await sink.close();
  }

  Future<void> deleteModel(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
