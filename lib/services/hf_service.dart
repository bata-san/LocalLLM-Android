import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/hf_model.dart';

class HfService {
  static const _apiBase = 'https://huggingface.co/api/models';
  static const _cdnBase = 'https://huggingface.co';
  static const _parallelChunks = 8;

  Future<List<HfFile>> listGgufFiles(String repoId) async {
    final url = Uri.parse('$_apiBase/$repoId');
    final resp = await http.get(url, headers: {'Accept': 'application/json'});
    if (resp.statusCode != 200) throw Exception('HuggingFace API error ${resp.statusCode}');
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
    return dir.listSync()
      .where((e) => e.path.endsWith('.gguf'))
      .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  // Parallel chunked download — 8 connections, typically 4-8x faster
  Stream<DownloadProgress> download(String repoId, String fileName) async* {
    final dir = await _modelsDir;
    final dest = File('$dir/$fileName');
    final url = '$_cdnBase/$repoId/resolve/main/$fileName';

    final headResp = await http.head(
      Uri.parse(url),
      headers: {'User-Agent': 'LocalLLM-Android/1.0'},
    );
    final total = int.tryParse(headResp.headers['content-length'] ?? '') ?? 0;
    final supportsRange = headResp.headers['accept-ranges']?.toLowerCase() == 'bytes';

    final ctrl = StreamController<DownloadProgress>();

    if (supportsRange && total > 1024 * 1024) {
      _parallelDownload(url, dest, dir, fileName, total, ctrl);
    } else {
      _singleDownload(url, dest, total, ctrl);
    }

    await for (final event in ctrl.stream) {
      yield event;
    }
  }

  void _singleDownload(
    String url, File dest, int total, StreamController<DownloadProgress> ctrl,
  ) async {
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'LocalLLM-Android/1.0';
      final resp = await req.send();
      var received = 0;
      final sink = dest.openWrite();
      final startMs = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        final elapsed = (DateTime.now().millisecondsSinceEpoch - startMs) / 1000;
        final speed = elapsed > 0.5 ? received / elapsed : null;
        ctrl.add(DownloadProgress(received, total, speedBps: speed));
      }
      await sink.close();
      ctrl.close();
    } catch (e) {
      ctrl.addError(e);
      ctrl.close();
    }
  }

  void _parallelDownload(
    String url, File dest, String dir, String fileName,
    int total, StreamController<DownloadProgress> ctrl,
  ) async {
    try {
      final chunkSize = (total + _parallelChunks - 1) ~/ _parallelChunks;
      final received = List.filled(_parallelChunks, 0);
      final tempPaths = List.generate(_parallelChunks, (i) => '$dir/${fileName}.part$i');
      final startMs = DateTime.now().millisecondsSinceEpoch;

      void reportProgress() {
        final totalReceived = received.fold(0, (a, b) => a + b);
        final elapsed = (DateTime.now().millisecondsSinceEpoch - startMs) / 1000;
        final speed = elapsed > 0.5 ? totalReceived / elapsed : null;
        if (!ctrl.isClosed) ctrl.add(DownloadProgress(totalReceived, total, speedBps: speed));
      }

      await Future.wait(List.generate(_parallelChunks, (i) async {
        final start = i * chunkSize;
        if (start >= total) return;
        final end = ((i + 1) * chunkSize - 1).clamp(0, total - 1);

        final req = http.Request('GET', Uri.parse(url));
        req.headers['Range'] = 'bytes=$start-$end';
        req.headers['User-Agent'] = 'LocalLLM-Android/1.0';

        final resp = await req.send();
        if (resp.statusCode != 206 && resp.statusCode != 200) {
          throw Exception('Chunk $i failed: HTTP ${resp.statusCode}');
        }

        final sink = File(tempPaths[i]).openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received[i] += chunk.length;
          reportProgress();
        }
        await sink.close();
      }));

      // 100% marker + assemble
      ctrl.add(DownloadProgress(total, total));
      final sink = dest.openWrite();
      for (var i = 0; i < _parallelChunks; i++) {
        final start = i * chunkSize;
        if (start >= total) break;
        final part = File(tempPaths[i]);
        if (await part.exists()) {
          await sink.addStream(part.openRead());
          await part.delete();
        }
      }
      await sink.close();
      ctrl.close();
    } catch (e) {
      // Clean up temp files
      final tempDir = await _modelsDir;
      for (var i = 0; i < _parallelChunks; i++) {
        final part = File('$tempDir/${fileName}.part$i');
        if (await part.exists()) await part.delete().catchError((_) {});
      }
      ctrl.addError(e);
      ctrl.close();
    }
  }

  Future<void> deleteModel(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
