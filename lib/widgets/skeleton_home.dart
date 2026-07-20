import 'package:flutter/material.dart';

class SkeletonHome extends StatefulWidget {
  const SkeletonHome({super.key});

  @override
  State<SkeletonHome> createState() => _SkeletonHomeState();
}

class _SkeletonHomeState extends State<SkeletonHome> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return _buildSkeleton(context);
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;
    final skeletonColor = (esOscuro ? Colors.white : Colors.black).withValues(alpha: _animation.value * (esOscuro ? 0.12 : 0.08));

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
          const SizedBox(height: 16),
          // Category chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => _box(80, 36, skeletonColor, radius: 18),
            ),
          ),
          const SizedBox(height: 24),
          // Section title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(160, 20, skeletonColor),
                const SizedBox(height: 16),
                // Cards
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => _box(220, 180, skeletonColor, radius: 16),
                  ),
                ),
                const SizedBox(height: 24),
                _box(140, 20, skeletonColor),
                const SizedBox(height: 16),
                // Feed items
                ...List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      _box(56, 56, skeletonColor, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _box(double.infinity, 16, skeletonColor),
                            const SizedBox(height: 8),
                            _box(140, 14, skeletonColor),
                          ],
                        ),
                      ),
                      _box(24, 24, skeletonColor, radius: 12),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _box(double w, double h, Color color, {double radius = 8}) {
    return Container(
      width: w.isFinite ? w : null,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
