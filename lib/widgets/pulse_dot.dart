import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PulseDot extends StatefulWidget {
  const PulseDot({Key? key}) : super(key: key);

  @override
  _PulseDotState createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.95), weight: 35),
      TweenSequenceItem(tween: ConstantTween<double>(0.95), weight: 30),
    ]).animate(_controller);

    _shadowAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 10.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 10.0, end: 0.0), weight: 35),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryNeonGreen,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNeonGreen.withOpacity(
                    0.7 * (1 - (_shadowAnimation.value / 10).clamp(0.0, 1.0)),
                  ),
                  blurRadius: 15,
                  spreadRadius: _shadowAnimation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
