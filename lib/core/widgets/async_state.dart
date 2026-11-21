import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/side_b_theme.dart';

class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _StatePanel(
    icon: LucideIcons.cloudOff,
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(LucideIcons.rotateCcw, size: 16),
      label: const Text('Reintentar'),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      _StatePanel(icon: LucideIcons.disc3, message: message);
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: SideBColors.olive, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    ),
  );
}
