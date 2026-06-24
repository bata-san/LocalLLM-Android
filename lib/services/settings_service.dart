import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyFirecrawlKey = 'firecrawl_api_key';
  static const _keySystemPrompt = 'system_prompt';
  static const _keyNCtx = 'n_ctx';
  static const _keySearchEnabled = 'search_enabled';
  static const _keyLastModel = 'last_model_path';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get firecrawlKey => _prefs.getString(_keyFirecrawlKey) ?? '';
  set firecrawlKey(String v) => _prefs.setString(_keyFirecrawlKey, v);

  String get systemPrompt => _prefs.getString(_keySystemPrompt) ??
    'You are a helpful, knowledgeable assistant. Be concise and accurate.';
  set systemPrompt(String v) => _prefs.setString(_keySystemPrompt, v);

  int get nCtx => _prefs.getInt(_keyNCtx) ?? 4096;
  set nCtx(int v) => _prefs.setInt(_keyNCtx, v);

  bool get searchEnabled => _prefs.getBool(_keySearchEnabled) ?? false;
  set searchEnabled(bool v) => _prefs.setBool(_keySearchEnabled, v);

  String get lastModelPath => _prefs.getString(_keyLastModel) ?? '';
  set lastModelPath(String v) => _prefs.setString(_keyLastModel, v);
}
