import 'package:flutter/material.dart';
import '../../state/app_store.dart';
import '../widgets/brand_mark.dart';
import 'welcome_page.dart';

/// Animated brand transition shown after the OS-native static splash.
class LaunchScreen extends StatefulWidget {
  final AppStore store;
  final Duration displayDuration;
  const LaunchScreen({
    super.key, required this.store,
    this.displayDuration = const Duration(milliseconds: 1350),
  });

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 950),
    )..forward();
    Future<void>.delayed(widget.displayDuration, () {
      if (mounted) setState(() => _showApp = true);
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: _showApp
        ? WelcomeGate(key: const ValueKey('vadesi-ready'), store: widget.store)
        : Scaffold(
            key: const ValueKey('vadesi-launch'),
            backgroundColor: const Color(0xFF243F56),
            body: SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_animation.value);
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - t)),
                        child: Transform.scale(
                          scale: 0.88 + 0.12 * t, child: child,
                        ),
                      ),
                    );
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandMark(size: 108),
                      SizedBox(height: 26),
                      Text('VADESİ', style: TextStyle(
                        color: Colors.white, fontSize: 28, letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                      )),
                      SizedBox(height: 10),
                      Text('Vadeni unutma.', style: TextStyle(
                        color: Color(0xFFCEE7F5), fontSize: 14,
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
