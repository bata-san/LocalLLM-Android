class HfFile {
  final String name;
  final int? size;

  const HfFile({required this.name, this.size});

  String get displaySize {
    if (size == null) return '';
    final gb = size! / 1e9;
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    final mb = size! / 1e6;
    return '${mb.toStringAsFixed(0)} MB';
  }

  factory HfFile.fromMap(Map<String, dynamic> m) => HfFile(
    name: m['rfilename'] as String,
    size: m['size'] as int?,
  );
}

class DownloadProgress {
  final int received;
  final int total;
  const DownloadProgress(this.received, this.total);
  double get fraction => total > 0 ? received / total : 0;
  String get label {
    final mb = received / 1e6;
    final tot = total / 1e6;
    return '${mb.toStringAsFixed(0)} / ${tot.toStringAsFixed(0)} MB';
  }
}

// Presets shown in the model browser
const kPresetRepos = [
  (
    label: 'Gemma 4 E2B Mobile QAT',
    repo: 'unsloth/gemma-4-E2B-it-qat-mobile-GGUF',
    note: '2.19 GB • Mobile-optimized'
  ),
  (
    label: 'Gemma 4 E2B IT (Bartowski)',
    repo: 'bartowski/google_gemma-4-E2B-it-GGUF',
    note: 'Multiple quants available'
  ),
];
