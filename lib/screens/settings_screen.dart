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
    widget.settings.firecrawlKey = _apiKeyCtrl.text.trim();
    widget.settings.systemPrompt = _systemPromptCtrl.text.trim();
    widget.settings.nCtx = int.tryParse(_nCtxCtrl.text) ?? 4096;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Saved', style: V.sans(size: 12)),
      backgroundColor: V.card2,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(V.rSm)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V.bg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: V.bg,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: V.border, height: 1),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: V.sans(size: 13, color: V.amber, weight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Web Search',
            children: [
              _FieldLabel('Firecrawl API key'),
              const SizedBox(height: 6),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: !_showKey,
                style: V.mono(size: 13),
                decoration: InputDecoration(
                  hintText: 'fc-...',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 16, color: V.textSub,
                    ),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stored on device only — never synced or committed to source control.',
                style: V.sans(size: 11, color: V.textMute),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Model',
            children: [
              _FieldLabel('Context length (tokens)'),
              const SizedBox(height: 6),
              TextField(
                controller: _nCtxCtrl,
                keyboardType: TextInputType.number,
                style: V.sans(size: 14),
                decoration: const InputDecoration(hintText: '4096'),
              ),
              const SizedBox(height: 14),
              _FieldLabel('System prompt'),
              const SizedBox(height: 6),
              TextField(
                controller: _systemPromptCtrl,
                maxLines: 5,
                style: V.sans(size: 13),
              ),
            ],
          ),
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
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(title.toUpperCase(), style: V.sans(size: 10, color: V.textMute, weight: FontWeight.w600)),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: V.surface,
          borderRadius: BorderRadius.all(V.rMd),
          border: Border.all(color: V.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) =>
    Text(text, style: V.sans(size: 12, color: V.textSub, weight: FontWeight.w500));
}
