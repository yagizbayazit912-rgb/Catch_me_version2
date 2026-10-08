import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Adım 2.2: çadır inşa anının ekran efektleri (plan 14.1-C).
/// Zeminde işaret halkası → toz bulutu → (çadır haritada zıplar) → parıltı
/// ve süzülen "-100" etiketi. Çadırın kendisi haritada 3D çizilir; bu katman
/// sadece toz/parıltı/yazı ekler.
///
/// [ground] çadır tabanının ekran noktası, [top] tepesinin. [progress]
/// dışarıdan sürülür (harita animasyonuyla aynı saat). Sadece etiket dokunma
/// yakalar ([onSkip]); gerisi dokunmayı haritaya geçirir.
class BuildCelebration extends StatelessWidget {
  const BuildCelebration({
    super.key,
    required this.progress,
    required this.ground,
    required this.top,
    required this.cost,
    required this.puffs,
    this.reduceMotion = false,
    this.onSkip,
  });

  final Animation<double> progress;
  final Offset ground;
  final Offset top;
  final int cost;
  final List<DustPuff> puffs;
  final bool reduceMotion;
  final VoidCallback? onSkip;

  /// Toz bulutu parçacıkları (her inşada bir kez üretilir).
  static List<DustPuff> makePuffs({bool lite = false}) {
    final rnd = math.Random();
    final n = lite ? GameConfig.buildDustPuffsLite : GameConfig.buildDustPuffs;
    return List.generate(n, (i) => DustPuff(rnd, i, n));
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final lt = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
        final opacity = lt < 0.75 ? 1.0 : 1 - (lt - 0.75) / 0.25;
        return Stack(
          children: [
            if (!reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BuildPainter(t, ground, top, puffs),
                  ),
                ),
              ),
            Positioned(
              left: top.dx - 60,
              width: 120,
              top: top.dy - 44 - (reduceMotion ? 0 : 50 * lt),
              child: Opacity(
                opacity: lt == 0 ? 0 : opacity.clamp(0.0, 1.0),
                child: Center(
                  child: GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentButter,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 18,
                            color: AppColors.text,
                          ),
                          const SizedBox(width: 4),
                          Text('-$cost', style: style),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DustPuff {
  DustPuff(math.Random r, int i, int n)
    : angle = (i / n) * 2 * math.pi + r.nextDouble() * 0.5,
      distance = 34 + r.nextDouble() * 26,
      size = 9 + r.nextDouble() * 8,
      delay = r.nextDouble() * 0.08;

  final double angle;
  final double distance;
  final double size;
  final double delay;
}

class _BuildPainter extends CustomPainter {
  _BuildPainter(this.t, this.ground, this.top, this.puffs);

  final double t;
  final Offset ground;
  final Offset top;
  final List<DustPuff> puffs;

  // Eğik kamerada zemin basık görünür; halka ve toz elips üzerinde yayılır.
  static const _flat = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Zeminde işaret (t 0–0.22): dışarıdan içeri daralan halka.
    final mt = (t / 0.22).clamp(0.0, 1.0);
    if (mt < 1) {
      final rad = 70 - 40 * Curves.easeOutCubic.transform(mt);
      canvas.drawOval(
        Rect.fromCenter(
          center: ground,
          width: rad * 2,
          height: rad * 2 * _flat,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.surface.withValues(alpha: 0.9 * (1 - mt)),
      );
    }

    // 2) Toz bulutu (t 0.14–0.6): tabandan dışa yayılır, hafif yükselir, solar.
    for (final p in puffs) {
      final dt = ((t - 0.14 - p.delay) / 0.46).clamp(0.0, 1.0);
      if (dt <= 0 || dt >= 1) continue;
      final e = Curves.easeOutCubic.transform(dt);
      final pos =
          ground +
          Offset(
            math.cos(p.angle) * p.distance * e,
            math.sin(p.angle) * p.distance * e * _flat - 10 * e,
          );
      canvas.drawCircle(
        pos,
        p.size * (0.6 + 0.6 * e),
        Paint()
          ..color = AppColors.background.withValues(alpha: 0.85 * (1 - dt)),
      );
      canvas.drawCircle(
        pos,
        p.size * (0.6 + 0.6 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.textSecondary.withValues(alpha: 0.25 * (1 - dt)),
      );
    }

    // 3) Parıltı (t 0.5–0.9): tepede küçük yıldızlar.
    final st = ((t - 0.5) / 0.4).clamp(0.0, 1.0);
    if (st > 0 && st < 1) {
      final e = Curves.easeOut.transform(st);
      const colors = [
        AppColors.accentButter,
        AppColors.accentLavender,
        AppColors.primary,
        AppColors.accentPeach,
      ];
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + (i - 2.5) * 0.45;
        final pos = top + Offset(math.cos(a), math.sin(a)) * (14 + 30 * e);
        _star(
          canvas,
          pos,
          4.5 * (1 - st * 0.6),
          colors[i % colors.length].withValues(alpha: 1 - st),
        );
      }
    }
  }

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r * 1.8 : r * 0.55;
      final a = i * math.pi / 4;
      final o = p + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BuildPainter old) => old.t != t;
}
