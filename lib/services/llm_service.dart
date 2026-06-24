import 'dart:async';
import 'package:flutter/services.dart';

class LlmService {
  static const _method = MethodChannel('com.bata.localllm/llm');
  static const _stream = EventChannel('com.bata.localllm/llm_stream');

  Stream<String>? _tokenStream;

  Stream<String> get tokenStream {
    _tokenStream ??= _stream
      .receiveBroadcastStream()
      .map((e) => e as String);
    return _tokenStream!;
  }

  Future<void> loadModel(String path, {int nCtx = 4096}) async {
    await _method.invokeMethod('loadModel', {'path': path, 'nCtx': nCtx});
  }

  Future<void> generate(String prompt) async {
    await _method.invokeMethod('generate', {'prompt': prompt});
  }

  Future<void> stop() async {
    await _method.invokeMethod('stopGeneration');
  }

  Future<void> freeModel() async {
    await _method.invokeMethod('freeModel');
  }

  Future<bool> isLoaded() async {
    return await _method.invokeMethod<bool>('isModelLoaded') ?? false;
  }
}
