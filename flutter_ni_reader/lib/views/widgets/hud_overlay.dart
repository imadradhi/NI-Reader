import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Futuristic HUD Corner Brackets for document scanner
class HudOverlay extends StatelessWidget {
  final String title;
  final String hint;
  final bool isScanning;

  const HudOverlay({
    super.key,
    required this.title,
    required this.hint,
    this.isScanning = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    
    // Vertical/Tall Card Rectangle (ID-1 Aspect Ratio 54:85.6) so turning phone horizontally scans the card
    final double cardWidth;
    final double cardHeight;
    
    if (isLandscape) {
      cardHeight = size.height * 0.80;
      cardWidth = cardHeight * (85.60 / 53.98);
    } else {
      // Tall rectangle in portrait (height > width)
      cardHeight = size.height * 0.58;
      cardWidth = cardHeight * (53.98 / 85.60);
    }

    return Stack(
      children: [
        // Semi-transparent darkened background with clear cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.65),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Glowing Green Neon Rectangle Frame (Bounding Box)
        Center(
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.neonEmerald,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonEmerald.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // 4 Thick Glowing Corner Brackets
                const Positioned(top: 0, left: 0, child: _CornerBracket(isTop: true, isLeft: true)),
                const Positioned(top: 0, right: 0, child: _CornerBracket(isTop: true, isLeft: false)),
                const Positioned(bottom: 0, left: 0, child: _CornerBracket(isTop: false, isLeft: true)),
                const Positioned(bottom: 0, right: 0, child: _CornerBracket(isTop: false, isLeft: false)),
                
                // Active Green Scanning Laser Line
                if (isScanning) const _LaserScanAnimation(),
              ],
            ),
          ),
        ),

        // Header and Instruction Hints
        Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.neonEmerald, width: 1),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerBracket({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    const double length = 28;
    const double thickness = 3.5;
    const Color color = AppColors.neonEmerald;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
      ),
    );
  }
}

class _LaserScanAnimation extends StatefulWidget {
  const _LaserScanAnimation();

  @override
  State<_LaserScanAnimation> createState() => _LaserScanAnimationState();
}

class _LaserScanAnimationState extends State<_LaserScanAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
        return Align(
          alignment: Alignment(0, (_controller.value * 2) - 1),
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonCyan.withOpacity(0.0),
                  AppColors.neonCyan,
                  AppColors.neonEmerald,
                  AppColors.neonCyan.withOpacity(0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonCyan.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
