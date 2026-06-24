import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_db.dart';
import '../services/firecrawl_service.dart';
import '../services/hf_service.dart';
import '../services/llm_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import 'models_screen.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final LlmService llm;
  final SettingsService settings;
  final HfService hf;
  final ChatDb db;

  const ChatScreen({
    super.key,
    required this.llm,
    required this.settings,
    required this.hf,
    required this.db,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isModelLoaded = false;
  bool _isLoadingModel = false;
  String? _modelName;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkModel();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await widget.db.loadAll();
    if (mounted) setState(() => _messages = msgs);
    _scrollToBottom();
  }

  Future<void> _checkModel() async {
    final loaded = await widget.llm.isLoaded();
    if (mounted) setState(() => _isModelLoaded = loaded);
    if (!loaded && widget.settings.lastModelPath.isNotEmpty) {
      await _loadModel(widget.settings.lastModelPath);
    }
  }

  Future<void> _loadModel(String path) async {
    setState(() { _isLoadingModel = true; });
    try {
      await widget.llm.loadModel(path, nCtx: widget.settings.nCtx);
      widget.settings.lastModelPath = path;
      final name = path.split('/').last.split('\\').last;
      if (mounted) setState(() { _isModelLoaded = true; _isLoadingModel = false; _modelName = name; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingModel = false);
        _showError('Failed to load model: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: V.sans(size: 12)),
      backgroundColor: V.red.withAlpha(200),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isGenerating || !_isModelLoaded) return;

    _inputCtrl.clear();
    _focusNode.requestFocus();

    // Add user message
    final userMsg = ChatMessage(role: Role.user, content: text, timestamp: DateTime.now());
    final userId = await widget.db.insert(userMsg);
    setState(() => _messages.add(userMsg.copyWith()));

    // Build prompt with optional web context
    String finalPrompt = text;
    if (widget.settings.searchEnabled && widget.settings.firecrawlKey.isNotEmpty) {
      try {
        final fc = FirecrawlService(widget.settings.firecrawlKey);
        final results = await fc.search(text, limit: 3);
        final context = fc.buildContext(results);
        if (context.isNotEmpty) {
          finalPrompt = '$context\n\nUser question: $text\n\nAnswer based on the search results above:';
        }
      } catch (_) {
        // continue without search
      }
    }

    // Build full prompt with history + system prompt
    final history = _messages.take(_messages.length - 1).toList();
    final prompt = _buildPrompt(finalPrompt, history);

    // Streaming assistant message
    final assistantMsg = ChatMessage(
      role: Role.assistant, content: '', isStreaming: true, timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(assistantMsg);
      _isGenerating = true;
    });
    _scrollToBottom();

    final buf = StringBuffer();
    await widget.llm.generate(prompt);

    _streamSub = widget.llm.tokenStream.listen(
      (token) {
        buf.write(token);
        final idx = _messages.length - 1;
        setState(() {
          _messages[idx] = _messages[idx].copyWith(content: buf.toString());
        });
        _scrollToBottom();
      },
      onDone: () async {
        final full = buf.toString();
        final finalMsg = ChatMessage(role: Role.assistant, content: full, timestamp: DateTime.now());
        final aid = await widget.db.insert(finalMsg);
        if (mounted) setState(() {
          _messages[_messages.length - 1] = finalMsg.copyWith();
          _isGenerating = false;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _isGenerating = false);
        _showError('Generation error: $e');
      },
    );
  }

  String _buildPrompt(String userText, List<ChatMessage> history) {
    final sys = widget.settings.systemPrompt;
    final buf = StringBuffer();
    buf.writeln('<start_of_turn>system');
    buf.writeln(sys);
    buf.writeln('<end_of_turn>');

    final relevant = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final m in relevant) {
      final role = m.role == Role.user ? 'user' : 'model';
      buf.writeln('<start_of_turn>$role');
      buf.writeln(m.content);
      buf.writeln('<end_of_turn>');
    }

    buf.writeln('<start_of_turn>user');
    buf.writeln(userText);
    buf.writeln('<end_of_turn>');
    buf.write('<start_of_turn>model\n');
    return buf.toString();
  }

  Future<void> _stopGeneration() async {
    await widget.llm.stop();
    await _streamSub?.cancel();
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _clearChat() async {
    await widget.db.clear();
    if (mounted) setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V.bg,
      appBar: AppBar(
        backgroundColor: V.bg,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LocalLLM'),
          if (_isLoadingModel)
            Text('Loading model...', style: V.sans(size: 10, color: V.amber))
          else if (_isModelLoaded && _modelName != null)
            Text(_modelName!, style: V.mono(size: 10, color: V.green), overflow: TextOverflow.ellipsis)
          else if (!_isModelLoaded)
            Text('No model loaded', style: V.sans(size: 10, color: V.textMute)),
        ]),
        actions: [
          // Search toggle
          GestureDetector(
            onTap: () => setState(() => widget.settings.searchEnabled = !widget.settings.searchEnabled),
            child: Tooltip(
              message: 'Web search',
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: widget.settings.searchEnabled ? V.blueBg : V.card,
                  borderRadius: BorderRadius.all(V.rSm),
                  border: Border.all(
                    color: widget.settings.searchEnabled ? V.blue.withAlpha(100) : V.border2,
                  ),
                ),
                child: Icon(
                  Icons.travel_explore,
                  size: 16,
                  color: widget.settings.searchEnabled ? V.blue : V.textMute,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.model_training_outlined, size: 18),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ModelsScreen(
                hf: widget.hf,
                settings: widget.settings,
                onModelSelected: _loadModel,
              ),
            )),
            tooltip: 'Models',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SettingsScreen(settings: widget.settings),
            )),
            tooltip: 'Settings',
          ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: V.card,
                  title: Text('Clear chat', style: V.sans(size: 14)),
                  content: Text('Delete all messages?', style: V.sans(size: 13, color: V.textSub)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: V.sans(size: 13, color: V.textSub)),
                    ),
                    TextButton(
                      onPressed: () { Navigator.pop(ctx); _clearChat(); },
                      child: Text('Clear', style: V.sans(size: 13, color: V.red)),
                    ),
                  ],
                ),
              ),
              tooltip: 'Clear chat',
            ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
              ? _EmptyState(isLoaded: _isModelLoaded, isLoading: _isLoadingModel)
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => MessageBubble(message: _messages[i]),
                ),
          ),
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            isGenerating: _isGenerating,
            isLoaded: _isModelLoaded,
            searchEnabled: widget.settings.searchEnabled,
            onSend: _send,
            onStop: _stopGeneration,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isLoaded, isLoading;
  const _EmptyState({required this.isLoaded, required this.isLoading});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: V.card,
            borderRadius: BorderRadius.all(V.rMd),
            border: Border.all(color: V.border2),
          ),
          child: const Icon(Icons.smart_toy_outlined, color: V.textSub, size: 24),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          Column(children: [
            const CircularProgressIndicator(color: V.blue, strokeWidth: 1.5),
            const SizedBox(height: 8),
            Text('Loading model...', style: V.sans(color: V.textSub)),
          ])
        else if (!isLoaded)
          Column(children: [
            Text('No model loaded', style: V.sans(size: 15, weight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Tap ⊞ to download a model', style: V.sans(size: 13, color: V.textSub)),
          ])
        else
          Column(children: [
            Text('Ready', style: V.sans(size: 15, weight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('Ask me anything', style: V.sans(size: 13, color: V.textSub)),
          ]),
      ],
    ),
  );
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating, isLoaded, searchEnabled;
  final VoidCallback onSend, onStop;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isLoaded,
    required this.searchEnabled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: V.bg,
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: V.card,
                borderRadius: BorderRadius.all(V.rMd),
                border: Border.all(color: V.border2),
              ),
              child: Row(children: [
                if (searchEnabled)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(Icons.travel_explore, size: 14, color: V.blue),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 4,
                    minLines: 1,
                    style: V.sans(size: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: false,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isGenerating ? onStop : (isLoaded ? onSend : null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isGenerating ? V.red.withAlpha(200) : (isLoaded ? V.blue : V.card2),
                borderRadius: BorderRadius.all(V.rSm),
              ),
              child: Icon(
                isGenerating ? Icons.stop : Icons.arrow_upward,
                color: isLoaded || isGenerating ? Colors.white : V.textMute,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
