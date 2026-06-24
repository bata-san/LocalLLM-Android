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
  String? _browsedRepo;
  List<HfFile>? _files;
  List<FileSystemEntity> _localModels = [];
  bool _loadingRepo = false;
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
    setState(() { _loadingRepo = true; _files = null; _error = null; _browsedRepo = repoId; });
    try {
      final files = await widget.hf.listGgufFiles(repoId);
      if (mounted) setState(() { _files = files; _loadingRepo = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loadingRepo = false; });
    }
  }

  Future<void> _download(String repoId, HfFile file) async {
    final existing = await widget.hf.findLocalFile(file.name);
    if (existing != null) {
      widget.onModelSelected(existing);
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() { _downloadingFile = file.name; _downloadProgress = 0; });

    try {
      await for (final prog in widget.hf.download(repoId, file.name)) {
        if (!mounted) return;
        setState(() { _downloadProgress = prog.fraction; _downloadLabel = prog.label; });
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
      backgroundColor: V.bg,
      appBar: AppBar(
        title: const Text('Models'),
        backgroundColor: V.bg,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: V.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Local models
          if (_localModels.isNotEmpty) ...[
            _Label('On device'),
            const SizedBox(height: 8),
            ..._localModels.map((f) {
              final name = f.path.split('/').last.split('\\').last;
              final size = f.statSync().size;
              final gb = (size / 1e9).toStringAsFixed(2);
              final isCurrent = widget.settings.lastModelPath == f.path;
              return _LocalModelTile(
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

          // Presets
          _Label('Download'),
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

          const SizedBox(height: 12),
          _Label('Custom repo'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _repoCtrl,
                style: V.mono(size: 13),
                decoration: const InputDecoration(hintText: 'owner/repo-name'),
              ),
            ),
            const SizedBox(width: 8),
            _SmallBtn(label: 'Browse', onTap: () {
              final r = _repoCtrl.text.trim();
              if (r.isNotEmpty) _browseRepo(r);
            }),
          ]),

          if (_loadingRepo) ...[
            const SizedBox(height: 24),
            Center(child: Column(children: [
              SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: V.amber, strokeWidth: 1.5)),
              const SizedBox(height: 10),
              Text('Fetching file list...', style: V.sans(size: 12, color: V.textSub)),
            ])),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBox(_error!),
          ],

          if (_files != null) ...[
            const SizedBox(height: 16),
            _Label('Select file'),
            const SizedBox(height: 8),
            ..._files!.map((f) {
              final isDown = _downloadingFile == f.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _FileTile(
                  file: f,
                  isDownloading: isDown,
                  progress: isDown ? _downloadProgress : 0,
                  progressLabel: isDown ? _downloadLabel : '',
                  onTap: isDown ? null : () => _download(_browsedRepo!, f),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
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
    borderRadius: BorderRadius.all(V.rMd),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: V.surface,
        borderRadius: BorderRadius.all(V.rMd),
        border: Border.all(color: V.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: V.sans(size: 14, weight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(repo, style: V.mono(size: 11, color: V.textSub)),
          const SizedBox(height: 1),
          Text(note, style: V.sans(size: 11, color: V.textMute)),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: V.textMute, size: 18),
      ]),
    ),
  );
}

class _LocalModelTile extends StatelessWidget {
  final String name, sub;
  final bool isActive;
  final VoidCallback onTap, onDelete;
  const _LocalModelTile({required this.name, required this.sub, required this.isActive, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.all(V.rMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? V.amberBg : V.surface,
          borderRadius: BorderRadius.all(V.rMd),
          border: Border.all(color: isActive ? V.amberDim.withAlpha(120) : V.border),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: V.mono(size: 12, color: isActive ? V.amber : V.text)),
            Text(sub, style: V.sans(size: 11, color: V.textSub)),
          ])),
          if (isActive) const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.check_circle, color: V.amber, size: 16),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline, color: V.textMute, size: 18),
          ),
        ]),
      ),
    ),
  );
}

class _FileTile extends StatelessWidget {
  final HfFile file;
  final bool isDownloading;
  final double progress;
  final String progressLabel;
  final VoidCallback? onTap;
  const _FileTile({required this.file, required this.isDownloading, required this.progress, required this.progressLabel, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.all(V.rMd),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: V.surface,
        borderRadius: BorderRadius.all(V.rMd),
        border: Border.all(color: V.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(file.name, style: V.mono(size: 12))),
          Text(file.displaySize, style: V.sans(size: 11, color: V.textSub)),
          if (!isDownloading) const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.download_outlined, color: V.textMute, size: 16),
          ),
        ]),
        if (isDownloading) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: V.border2,
              valueColor: const AlwaysStoppedAnimation(V.amber),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 5),
          Text(progressLabel, style: V.sans(size: 11, color: V.textSub)),
        ],
      ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: V.amber, borderRadius: BorderRadius.all(V.rSm)),
      child: Text(label, style: V.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: V.red.withAlpha(20),
      borderRadius: BorderRadius.all(V.rSm),
      border: Border.all(color: V.red.withAlpha(60)),
    ),
    child: Text(message, style: V.sans(size: 12, color: V.red)),
  );
}
