import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConversationDrawer extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onModels;
  final VoidCallback onSettings;
  final String? modelName;

  const ConversationDrawer({
    super.key,
    required this.onNewChat,
    required this.onModels,
    required this.onSettings,
    this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: V.amberBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: V.amberDim.withAlpha(120)),
                  ),
                  child: const Text('✦', style: TextStyle(fontSize: 15, color: V.amber)),
                ),
                const SizedBox(width: 10),
                Text('LocalLLM', style: V.sans(size: 16, weight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: V.textMute, size: 18),
                ),
              ]),
            ),

            // New chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _DrawerBtn(
                icon: Icons.add,
                label: 'New chat',
                accent: true,
                onTap: () { Navigator.pop(context); onNewChat(); },
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: V.border, height: 1),
            ),
            const SizedBox(height: 8),

            // Model info
            if (modelName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE MODEL', style: V.sans(size: 10, color: V.textMute, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      modelName!,
                      style: V.mono(size: 11, color: V.textSub),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(color: V.border, height: 1),
            ),
            const SizedBox(height: 8),

            // Bottom nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _DrawerBtn(
                icon: Icons.storage_outlined,
                label: 'Models',
                onTap: () { Navigator.pop(context); onModels(); },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _DrawerBtn(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () { Navigator.pop(context); onSettings(); },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  final VoidCallback onTap;
  const _DrawerBtn({required this.icon, required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.all(V.rSm),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: accent
        ? BoxDecoration(
            color: V.amberBg,
            borderRadius: BorderRadius.all(V.rSm),
            border: Border.all(color: V.amberDim.withAlpha(100)),
          )
        : null,
      child: Row(children: [
        Icon(icon, size: 17, color: accent ? V.amber : V.textSub),
        const SizedBox(width: 10),
        Text(label, style: V.sans(size: 14, color: accent ? V.amber : V.text, weight: FontWeight.w500)),
      ]),
    ),
  );
}
