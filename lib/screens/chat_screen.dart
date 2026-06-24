import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../services/chat_db.dart';
import '../services/firecrawl_service.dart';
import '../services/hf_service.dart';
import '../services/llm_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/conversation_drawer.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _isModelLoaded = false;
  bool _isLoadingModel = false;
  String? _modelName;
  StreamSubscription<String>? _streamSub;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final has = _inputCtrl.text.trim().isNotEmpty;
      if (has != _hasInput) setState(() => _hasInput = has);
    });
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
    setState(() => _isLoadingModel = true);
    try {
      await widget.llm.loadModel(path, nCtx: widget.settings.nCtx);
      widget.settings.lastModelPath = path;
      final name = path.split('/').last.split('\\').last;
      if (mounted) setState(() {
        _isModelLoaded = true;
        _isLoadingModel = false;
        _modelName = name;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingModel = false);
        _showSnack('Failed to load model: $e', isError: true);
      }
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isGenerating || !_isModelLoaded) return;

    _inputCtrl.clear();
    _focusNode.requestFocus();

    final userMsg = ChatMessage(role: Role.user, content: text, timestamp: DateTime.now());
    await widget.db.insert(userMsg);
    setState(() => _messages.add(userMsg));

    String finalPrompt = text;
    if (widget.settings.searchEnabled && widget.settings.firecrawlKey.isNotEmpty) {
      try {
        final fc = FirecrawlService(widget.settings.firecrawlKey);
        final results = await fc.search(text, limit: 3);
        final ctx = fc.buildContext(results);
        if (ctx.isNotEmpty) {
          finalPrompt = '$ctx\n\nUser question: $text\n\nAnswer based on the search results above:';
        }
      } catch (_) {}
    }

    final prompt = _buildPrompt(finalPrompt, _messages.sublist(0, _messages.length - 1));

    final placeholder = ChatMessage(
      role: Role.assistant, content: '', isStreaming: true, timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(placeholder);
      _isGenerating = true;
    });
    _scrollToBottom();

    final buf = StringBuffer();
    await widget.llm.generate(prompt);

    _streamSub = widget.llm.tokenStream.listen(
      (token) {
        buf.write(token);
        final idx = _messages.length - 1;
        if (mounted) setState(() => _messages[idx] = _messages[idx].copyWith(content: buf.toString()));
        _scrollToBottom();
      },
      onDone: () async {
        final full = buf.toString();
        final finalMsg = ChatMessage(role: Role.assistant, content: full, timestamp: DateTime.now());
        await widget.db.insert(finalMsg);
        if (mounted) setState(() {
          _messages[_messages.length - 1] = finalMsg;
          _isGenerating = false;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _isGenerating = false);
        _showSnack('Error: $e', isError: true);
      },
    );
  }

  String _buildPrompt(String userText, List<ChatMessage> history) {
    final buf = StringBuffer();
    buf.writeln('<start_of_turn>system');
    buf.writeln(widget.settings.systemPrompt);
    buf.writeln('<end_of_turn>');

    final recent = history.length > 10 ? history.sublist(history.length - 10) : history;
    for (final m in recent) {
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

  Future<void> _stop() async {
    await widget.llm.stop();
    await _streamSub?.cancel();
    if (mounted) setState(() => _isGenerating = false);
  }

  Future<void> _newChat() async {
    if (_isGenerating) await _stop();
    await widget.db.clear();
    if (mounted) setState(() => _messages.clear());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: V.sans(size: 12)),
      backgroundColor: isError ? V.red.withAlpha(200) : V.card2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(V.rSm)),
    ));
  }

  void _openModels() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => ModelsScreen(
      hf: widget.hf,
      settings: widget.settings,
      onModelSelected: _loadModel,
    ),
  ));

  void _openSettings() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => SettingsScreen(settings: widget.settings),
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: V.bg,
      drawer: ConversationDrawer(
        onNewChat: _newChat,
        onModels: _openModels,
        onSettings: _openSettings,
        modelName: _modelName,
      ),
      body: SafeArea(
        child: Column(children: [
          _TopBar(
            isModelLoaded: _isModelLoaded,
            isLoadingModel: _isLoadingModel,
            modelName: _modelName,
            searchEnabled: widget.settings.searchEnabled,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onSearchToggle: () => setState(() =>
              widget.settings.searchEnabled = !widget.settings.searchEnabled),
            onNewChat: _newChat,
          ),
          Expanded(
            child: _messages.isEmpty
              ? _EmptyState(
                  isLoaded: _isModelLoaded,
                  isLoading: _isLoadingModel,
                  onOpenModels: _openModels,
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => MessageBubble(message: _messages[i]),
                ),
          ),
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            isGenerating: _isGenerating,
            isLoaded: _isModelLoaded,
            hasInput: _hasInput,
            searchEnabled: widget.settings.searchEnabled,
            onSend: _send,
            onStop: _stop,
          ),
        ]),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isModelLoaded, isLoadingModel, searchEnabled;
  final String? modelName;
  final VoidCallback onMenu, onSearchToggle, onNewChat;

  const _TopBar({
    required this.isModelLoaded,
    required this.isLoadingModel,
    required this.modelName,
    required this.searchEnabled,
    required this.onMenu,
    required this.onSearchToggle,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: V.bg,
        border: Border(bottom: BorderSide(color: V.border, width: 1)),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.menu, size: 20),
          color: V.textSub,
          onPressed: onMenu,
          splashRadius: 18,
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoadingModel)
                Row(children: [
                  SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(color: V.amber, strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 6),
                  Text('Loading model...', style: V.sans(size: 12, color: V.amber)),
                ])
              else if (modelName != null)
                Text(
                  modelName!,
                  style: V.mono(size: 11, color: V.textSub),
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text('No model loaded', style: V.sans(size: 12, color: V.textMute)),
            ],
          ),
        ),
        // Web search toggle
        _TopBarChip(
          icon: Icons.travel_explore_outlined,
          active: searchEnabled,
          onTap: onSearchToggle,
          tooltip: 'Web search',
        ),
        // New chat
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: V.textSub,
          onPressed: onNewChat,
          splashRadius: 18,
          tooltip: 'New chat',
        ),
      ]),
    );
  }
}

class _TopBarChip extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;
  const _TopBarChip({required this.icon, required this.active, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? V.amberBg : Colors.transparent,
          borderRadius: BorderRadius.all(V.rSm),
          border: Border.all(color: active ? V.amberDim.withAlpha(120) : V.border2),
        ),
        child: Icon(icon, size: 16, color: active ? V.amber : V.textMute),
      ),
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isLoaded, isLoading;
  final VoidCallback onOpenModels;
  const _EmptyState({required this.isLoaded, required this.isLoading, required this.onOpenModels});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: V.amberBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: V.amberDim.withAlpha(140)),
            ),
            child: const Text('✦', style: TextStyle(fontSize: 26, color: V.amber)),
          ),
          const SizedBox(height: 20),
          if (isLoading) ...[
            SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(color: V.amber, strokeWidth: 1.5)),
            const SizedBox(height: 12),
            Text('Loading model...', style: V.sans(size: 15, color: V.textSub)),
          ] else if (!isLoaded) ...[
            Text('No model loaded', style: V.sans(size: 17, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Download a GGUF model to get started', style: V.sans(size: 14, color: V.textSub)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onOpenModels,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: V.amberBg,
                  borderRadius: BorderRadius.all(V.rMd),
                  border: Border.all(color: V.amberDim.withAlpha(120)),
                ),
                child: Text('Browse models', style: V.sans(size: 14, color: V.amber, weight: FontWeight.w500)),
              ),
            ),
          ] else ...[
            Text('What\'s on your mind?', style: V.sans(size: 17, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Ask anything', style: V.sans(size: 14, color: V.textSub)),
          ],
        ],
      ),
    ),
  );
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating, isLoaded, hasInput, searchEnabled;
  final VoidCallback onSend, onStop;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.isLoaded,
    required this.hasInput,
    required this.searchEnabled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      color: V.bg,
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad > 0 ? bottomPad + 8 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: V.surface,
          borderRadius: BorderRadius.all(V.rLg),
          border: Border.all(color: V.border2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Search indicator dot
            if (searchEnabled)
              Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 13),
                child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(color: V.amber, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 6,
                minLines: 1,
                style: V.sans(size: 15),
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: searchEnabled ? 'Ask anything (web search on)' : 'Message',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.fromLTRB(
                    searchEnabled ? 8 : 16, 12, 8, 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: _SendBtn(
                isGenerating: isGenerating,
                isLoaded: isLoaded,
                hasInput: hasInput,
                onSend: onSend,
                onStop: onStop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  final bool isGenerating, isLoaded, hasInput;
  final VoidCallback onSend, onStop;
  const _SendBtn({
    required this.isGenerating, required this.isLoaded,
    required this.hasInput, required this.onSend, required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = isLoaded && hasInput && !isGenerating;
    final active = isGenerating || canSend;

    return GestureDetector(
      onTap: isGenerating ? onStop : (canSend ? onSend : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: active ? V.amber : V.border2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
          size: 18,
          color: active ? Colors.white : V.textMute,
        ),
      ),
    );
  }
}
