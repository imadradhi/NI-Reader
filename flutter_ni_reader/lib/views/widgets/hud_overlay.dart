import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Accurate, high-precision HUD overlay matching standard ICAO / ReadID MRZ Scanner interface
class HudOverlay extends StatelessWidget {
  final String title;
  final String hint;
  final bool isBackScanning;
  final bool isAutoCapturing;
  final bool isTorchOn;
  final VoidCallback? onToggleTorch;
  final VoidCallback? onManualInput;
  final VoidCallback? onClose;
  final VoidCallback? onShare;

  const HudOverlay({
    super.key,
    required this.title,
    required this.hint,
    this.isBackScanning = true,
    this.isAutoCapturing = false,
    this.isTorchOn = false,
    this.onToggleTorch,
    this.onManualInput,
    this.onClose,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Standard ID-1 Card Aspect Ratio (85.60mm x 53.98mm = ~1.5858)
    final double cardWidth;
    final double cardHeight;

    if (isLandscape) {
      cardHeight = size.height * 0.78;
      cardWidth = cardHeight * (85.60 / 53.98);
    } else {
      // Portrait orientation (card is vertical)
      cardWidth = math.min(size.width * 0.68, 280.0);
      cardHeight = cardWidth * (85.60 / 53.98);
    }

    return Stack(
      children: [
        // 1. Semi-transparent darkened vignette overlay with clear rounded rectangle cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.72),
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
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Crisp White Rounded Rectangle Border Frame & Internal Guides
        Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Stack(
              children: [
                // Solid White Border
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isAutoCapturing ? const Color(0xFF10B981) : Colors.white,
                      width: 2.2,
                    ),
                    boxShadow: isAutoCapturing
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.6),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),

                // 3-Row MRZ Chevron Position Guide (Left side of card in portrait)
                if (isBackScanning)
                  Positioned(
                    left: 14,
                    top: 24,
                    bottom: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChevronColumn(),
                        const SizedBox(width: 5),
                        _buildChevronColumn(),
                        const SizedBox(width: 5),
                        _buildChevronColumn(),
                      ],
                    ),
                  ),

                // Small diamond marker at bottom center of the card
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),

                // Subtle vertical scanning laser bar during auto-detection
                if (isAutoCapturing) const _LiveScanBar(),
              ],
            ),
          ),
        ),

        // 3. Side Instruction Pill Badge ("Align back of identity card here")
        if (!isLandscape)
          Positioned(
            right: (size.width - cardWidth) / 4 - 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: RotatedBox(
                quarterTurns: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xE6141414),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    isBackScanning
                        ? "Align back of identity card here"
                        : "Align front of identity card here",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 4. Top Action Buttons (Share & Dismiss)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Icons.ios_share_rounded,
                  onTap: onShare ?? () {},
                ),
                _buildCircularButton(
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: onClose ?? () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),

        // 5. Bottom Action Controls (Manual Input & Torch & Auto-capture indicator)
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Manual Input Button
                  _buildBottomActionButton(
                    icon: Icons.keyboard_alt_outlined,
                    label: "Manual input",
                    subLabel: "إدخال يدوي",
                    onTap: onManualInput,
                  ),

                  // Torch Flash Toggle Button
                  _buildBottomActionButton(
                    icon: isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                    label: "Torch",
                    subLabel: isTorchOn ? "مفعل" : "الفلاش",
                    iconColor: isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                    onTap: onToggleTorch,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a single vertical column of caret / chevron symbols `<`
  Widget _buildChevronColumn() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        26,
        (index) => const Text(
          "<",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            height: 0.9,
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x80222222),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required String subLabel,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x99252525),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveScanBar extends StatefulWidget {
  const _LiveScanBar();

  @override
  State<_LiveScanBar> createState() => _LiveScanBarState();
}

class _LiveScanBarState extends State<_LiveScanBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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
          alignment: Alignment((_controller.value * 2) - 1, 0),
          child: Container(
            width: 2.5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF10B981).withOpacity(0.0),
                  const Color(0xFF10B981),
                  const Color(0xFF00E5FF),
                  const Color(0xFF10B981).withOpacity(0.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.85),
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
