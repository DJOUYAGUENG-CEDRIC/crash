import 'dart:async';

import 'package:flutter/material.dart';

/// Short success message displayed inside the flight area, as in the
/// reference game. A single controller lets either betting slot publish a
/// notice without coupling the panels to the stage widget.
final gameNoticeController = GameNoticeController();

class GameNoticeController extends ValueNotifier<String?> {
  GameNoticeController() : super(null);

  void show(String message) {
    value = message;
  }
}

class GameNoticeOverlay extends StatefulWidget {
  const GameNoticeOverlay({super.key});

  @override
  State<GameNoticeOverlay> createState() => _GameNoticeOverlayState();
}

class _GameNoticeOverlayState extends State<GameNoticeOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    gameNoticeController.addListener(_scheduleDismissal);
  }

  void _scheduleDismissal() {
    _timer?.cancel();
    if (gameNoticeController.value == null) return;
    _timer = Timer(const Duration(milliseconds: 2300), () {
      gameNoticeController.value = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    gameNoticeController.removeListener(_scheduleDismissal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: gameNoticeController,
      builder: (context, message, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: message == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(message),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B102D).withValues(alpha: .96),
                    border: Border.all(
                      color: const Color(0xFF242A50),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF91EA55),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
