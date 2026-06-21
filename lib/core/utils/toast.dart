import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ToastType { success, error, info }

class Toast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration autoDismiss = _defaultAutoDismiss,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
    Future.delayed(autoDismiss, () {
      if (entry.mounted) entry.remove();
    });
  }

  static const _defaultAutoDismiss = Duration(seconds: 2);

  static void success(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.success);

  static void error(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.error);

  static void info(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.info);
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.type) {
        ToastType.success => Icons.check_circle_outline,
        ToastType.error => Icons.error_outline,
        ToastType.info => Icons.info_outline,
      };

  /// Toast 彩色图标色，跟随主题语义色（success→收入绿，error→支出红，info→品牌绿）。
  Color _iconColor(BuildContext context) => switch (widget.type) {
        ToastType.success => AppColors.income(context),
        ToastType.error => AppColors.expense(context),
        ToastType.info => AppColors.primary(context),
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.15,
      left: 40,
      right: 40,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.border(context),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, color: _iconColor(context), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
