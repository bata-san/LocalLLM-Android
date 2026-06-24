import 'dart:io';
import 'package:flutter/material.dart';
import '../models/hf_model.dart';
import '../services/hf_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class ModelsScreen extends StatefulWidget {
  final HfService hf;
  final SettingsService settings;
  final void Function(String path) onModelSelected;

  const ModelsScreen({
    super.key,
    required this.hf,
    required this.settings,
    required this.onModelSelected,
  });

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final _repoCtrl = TextEditingController();
  List<HfFile>? _files;
  List<FileSystemEntity> _localModels = [];
  String? _loadingRepo;
  String? _downloadingFile;
  double _downloadProgress = 0;
  String _downloadLabel = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void dispose() { _repoCtrl.dispose(); super.dispose(); }

  Future<void> _loadLocal() async {
    final models = await widget.hf.listLocalModels();
    if (mounted) setState(() => _localModels = models);
  }

  Future<void> _browseRepo(String repoId) async {
    setState(() { _loadingRepo = repoId; _files = null; _error = null; });
    try {
      final files = await widget.hf.listGgufFiles(repoId);
      if (mounted) setState(() { _files = files; _loadingRepo = null; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingRepo = null; });
    }
  }

  Future<void> _download(String repoId, HfFile file) async {
    // check if exists
    final existing = await widget.hf.findLocalFile(file.name);
    if (existing != null) {
      widget.onModelSelected(existing);
      Navigator.pop(context);
      return;
    }

    setState(() { _downloadingFile = file.name; _downloadProgress = 0; });

    try {
      await for (final prog in widget.hf.download(repoId, file.name)) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = prog.fraction;
          _downloadLabel = prog.label;
        });
      }
      final path = await widget.hf.findLocalFile(file.name);
      if (path != null) {
        widget.settings.lastModelPath = path;
        widget.onModelSelected(path);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _downloadingFile = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Local models
          if (_localModels.isNotEmpty) ...[
            _SectionLabel('Local models'),
            const SizedBox(height: 8),
            ..._localModels.map((f) {
              final name = f.path.split('/').last.split('\\').last;
              final size = f.statSync().size;
              final gb = (size / 1e9).toStringAsFixed(2);
              final isCurrent = widget.settings.lastModelPath == f.path;
              return _ModelTile(
                name: name,
                sub: '$gb GB',
                isActive: isCurrent,
                onTap: () {
                  widget.settings.lastModelPath = f.path;
                  widget.onModelSelected(f.path);
                  Navigator.pop(context);
                },
                onDelete: () async {
                  await widget.hf.deleteModel(f.path);
                  _loadLocal();
                },
              );
            }),
            const SizedBox(height: 20),
          ],

          // Preset repos
          _SectionLabel('Download from HuggingFace'),
          const SizedBox(height: 8),
          ...kPresetRepos.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PresetCard(
              label: p.label,
              repo: p.repo,
              note: p.note,
              onTap: () => _browseRepo(p.repo),
            ),
          )),
          const SizedBox(height: 8),

          // Custom repo input
          Row(children: [
            Expanded(
              child: TextField(
                controller: _repoCtrl,
                style: V.mono(size: 13),
                decoration: const InputDecoration(hintText: 'owner/repo-name'),
              ),
            ),
            const SizedBox(width: 8),
            _SmallBtn(
              label: 'Browse',
              onTap: () {
                final r = _repoCtrl.text.trim();
                if (r.isNotEmpty) _browseRepo(r);
              },
            ),
          ]),

          // Loading
          if (_loadingRepo != null) ...[
            const SizedBox(height: 16),
            Center(child: Column(children: [
              const CircularProgressIndicator(color: V.blue, strokeWidth: 1.5),
              const SizedBox(height: 8),
              Text('Fetching $_loadingRepo...', style: V.sans(size: 12, color: V.textSub)),
            ])),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: V.red.withAlpha(20),
                borderRadius: BorderRadius.all(V.rSm),
                border: Border.all(color: V.red.withAlpha(60)),
              ),
              child: Text(_error!, style: V.sans(size: 12, color: V.red)),
            ),
          ],

          // File list
          if (_files != null) ...[
            const SizedBox(height: 16),
            _SectionLabel('Select a file'),
            const SizedBox(height: 8),
            ..._files!.map((f) {
              final isDownloading = _downloadingFile == f.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: isDownloading ? null : () => _download(_loadingRepo ?? _repoCtrl.text.trim(), f),
                  borderRadius: BorderRadius.all(V.rSm),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: V.card,
                      borderRadius: BorderRadius.all(V.rSm),
                      border: Border.all(color: V.border2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(f.name, style: V.mono(size: 12))),
                          Text(f.displaySize, style: V.sans(size: 11, color: V.textSub)),
                        ]),
                        if (isDownloading) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: V.border2,
                            valueColor: const AlwaysStoppedAnimation(V.blue),
                            minHeight: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(_downloadLabel, style: V.sans(size: 11, color: V.textSub)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) =>
    Text(text.toUpperCase(), style: V.sans(size: 10, color: V.textMute, weight: FontWeight.w600));
}

class _PresetCard extends StatelessWidget {
  final String label, repo, note;
  final VoidCallback onTap;
  const _PresetCard({required this.label, required this.repo, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.all(V.rSm),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: V.card,
        borderRadius: BorderRadius.all(V.rSm),
        border: Border.all(color: V.border2),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: V.sans(size: 13, weight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(repo, style: V.mono(size: 11, color: V.textSub)),
          Text(note, style: V.sans(size: 11, color: V.textMute)),
        ])),
        const Icon(Icons.chevron_right, color: V.textMute, size: 16),
      ]),
    ),
  );
}

class _ModelTile extends StatelessWidget {
  final String name, sub;
  final bool isActive;
  final VoidCallback onTap, onDelete;
  const _ModelTile({required this.name, required this.sub, required this.isActive, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(V.rSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? V.blueBg : V.card,
          borderRadius: BorderRadius.all(V.rSm),
          border: Border.all(color: isActive ? V.blue.withAlpha(80) : V.border2),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: V.mono(size: 12)),
            Text(sub, style: V.sans(size: 11, color: V.textSub)),
          ])),
          if (isActive)
            const Icon(Icons.check_circle, color: V.blue, size: 16),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline, color: V.textMute, size: 16),
          ),
        ]),
      ),
    ),
  );
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: V.blue,
        borderRadius: BorderRadius.all(V.rSm),
      ),
      child: Text(label, style: V.sans(size: 13, weight: FontWeight.w500)),
    ),
  );
}
