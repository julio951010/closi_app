import 'package:flutter/material.dart';

class SkeletonFavoritos extends StatefulWidget {
  const SkeletonFavoritos({super.key});

  @override
  State<SkeletonFavoritos> createState() => _SkeletonFavoritosState();
}

class _SkeletonFavoritosState extends State<SkeletonFavoritos> with SingleTickerProviderStateMixin {
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

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 80),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _box(100, 100, skeletonColor, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(180, 16, skeletonColor),
                  const SizedBox(height: 8),
                  _box(120, 14, skeletonColor),
                  const SizedBox(height: 8),
                  _box(80, 12, skeletonColor),
                ],
              ),
            ),
            _box(28, 28, skeletonColor, radius: 14),
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
