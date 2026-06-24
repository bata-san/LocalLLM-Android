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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied', style: V.sans(size: 12)),
                    backgroundColor: V.card2,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? V.blue : V.card,
                  borderRadius: BorderRadius.all(V.rMd).subtract(BorderRadius.only(
                    bottomRight: isUser ? V.rSm : Radius.zero,
                    bottomLeft: isUser ? Radius.zero : V.rSm,
                  )),
                  border: isUser ? null : Border.all(color: V.border2),
                ),
                child: message.isStreaming && message.content.isEmpty
                  ? const _TypingDots()
                  : SelectableText(
                      message.content,
                      style: V.sans(
                        size: 14,
                        color: isUser ? Colors.white : V.text,
                      ),
                    ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? V.blue.withAlpha(40) : V.card2,
        borderRadius: BorderRadius.all(V.rSm),
        border: Border.all(color: isUser ? V.blue.withAlpha(80) : V.border2),
      ),
      child: Text(
        isUser ? 'U' : 'A',
        style: V.sans(size: 11, weight: FontWeight.w600, color: isUser ? V.blue : V.textSub),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = (_anim.value - i * 0.2).clamp(0.0, 1.0);
        final opacity = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: V.textSub, shape: BoxShape.circle),
            ),
          ),
        );
      }),
    ),
  );
}
