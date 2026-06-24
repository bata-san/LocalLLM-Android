import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    return isUser ? _UserBubble(message: message) : _AssistantBubble(message: message);
  }
}

// User: right-aligned warm pill
class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 6, 16, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: () => _copy(context, message.content),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: V.card,
              borderRadius: const BorderRadius.only(
                topLeft: V.rLg,
                topRight: V.rLg,
                bottomLeft: V.rLg,
                bottomRight: V.rSm,
              ),
              border: Border.all(color: V.border2),
            ),
            child: SelectableText(
              message.content,
              style: V.sans(size: 15, height: 1.55),
            ),
          ),
        ),
      ),
    );
  }
}

// Assistant: no bubble, ✦ icon + text directly
class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 48, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✦ icon
          Container(
            margin: const EdgeInsets.only(top: 1, right: 12),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: V.amberBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: V.amberDim.withAlpha(120)),
            ),
            child: const Text('✦', style: TextStyle(fontSize: 12, color: V.amber)),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copy(context, message.content),
              child: message.isStreaming && message.content.isEmpty
                ? _ThinkingRow()
                : _StreamingText(
                    text: message.content,
                    isStreaming: message.isStreaming,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamingText extends StatefulWidget {
  final String text;
  final bool isStreaming;
  const _StreamingText({required this.text, required this.isStreaming});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> with SingleTickerProviderStateMixin {
  late AnimationController _cursor;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _cursor.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStreaming) {
      return SelectableText(widget.text, style: V.sans(size: 15, height: 1.6));
    }

    return AnimatedBuilder(
      animation: _cursor,
      builder: (_, __) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: widget.text,
              style: V.sans(size: 15, height: 1.6),
            ),
            TextSpan(
              text: _cursor.value > 0.5 ? '│' : '',
              style: V.sans(size: 15, color: V.amber, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// "Thinking" row shown before first token arrives
class _ThinkingRow extends StatefulWidget {
  @override
  State<_ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<_ThinkingRow> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (_ctrl.value - i * 0.18) % 1.0;
        final opacity = (t < 0.4 ? t / 0.4 : t < 0.7 ? 1.0 : (1.0 - t) / 0.3).clamp(0.15, 1.0);
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: V.amber, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        );
      }),
    ),
  );
}

void _copy(BuildContext ctx, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text('Copied', style: V.sans(size: 12)),
    backgroundColor: V.card2,
    duration: const Duration(seconds: 1),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(V.rSm)),
  ));
}
