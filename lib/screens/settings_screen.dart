import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _systemPromptCtrl;
  late TextEditingController _nCtxCtrl;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _apiKeyCtrl = TextEditingController(text: s.firecrawlKey);
    _systemPromptCtrl = TextEditingController(text: s.systemPrompt);
    _nCtxCtrl = TextEditingController(text: s.nCtx.toString());
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _systemPromptCtrl.dispose();
    _nCtxCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final s = widget.settings;
    s.firecrawlKey = _apiKeyCtrl.text.trim();
    s.systemPrompt = _systemPromptCtrl.text.trim();
    s.nCtx = int.tryParse(_nCtxCtrl.text) ?? 4096;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved', style: V.sans(size: 12)),
        backgroundColor: V.card2,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: V.sans(size: 13, color: V.blue, weight: FontWeight.w500)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(title: 'Firecrawl', children: [
            _Label('API Key'),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: !_showKey,
              style: V.mono(size: 13),
              decoration: InputDecoration(
                hintText: 'fc-...',
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility, size: 16, color: V.textSub),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Stored locally, never synced or committed', style: V.sans(size: 11, color: V.textMute)),
          ]),
          const SizedBox(height: 20),
          _Section(title: 'Model', children: [
            _Label('Context length (tokens)'),
            const SizedBox(height: 6),
            TextField(
              controller: _nCtxCtrl,
              keyboardType: TextInputType.number,
              style: V.sans(size: 14),
            ),
            const SizedBox(height: 12),
            _Label('System prompt'),
            const SizedBox(height: 6),
            TextField(
              controller: _systemPromptCtrl,
              maxLines: 4,
              style: V.sans(size: 13),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title.toUpperCase(), style: V.sans(size: 10, color: V.textMute, weight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: V.card,
          borderRadius: BorderRadius.all(V.rMd),
          border: Border.all(color: V.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
    Text(text, style: V.sans(size: 12, color: V.textSub, weight: FontWeight.w500));
}
