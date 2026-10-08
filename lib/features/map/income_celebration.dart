import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../core/config/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

final _rnd = math.Random();

/// Toplama sesi (sikke şıngırtısı) ve kısa titreşim. Her seferinde ton
/// hafifçe değişir (monotonluk olmasın); yeni oynatıcı, bitince atılır.
Future<void> playCollectFeedback() async {
  if (GameConfig.hapticsEnabled) {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          duration: GameConfig.collectVibrateMs,
          amplitude: GameConfig.collectVibrateAmplitude,
        );
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }
  if (GameConfig.soundEnabled) {
    try {
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      const j = GameConfig.collectPitchJitter;
      await player.setPlaybackRate(1 - j + _rnd.nextDouble() * 2 * j);
      await player.play(AssetSource(GameConfig.collectSoundAsset));
    } catch (_) {
      // Ses çalınamadı: sessiz devam.
    }
  }
}

/// Uçan tek sikke: kaynağı, başlama gecikmesi ve yay sapması.
class FlyCoin {
  FlyCoin(this.from, this.delay, this.sway);

  final Offset from;
  final double delay;
  final double sway;
}

/// Adım 2.3: gelir toplama anı (plan 14.1-C). Sikkeler yapılardan çıkıp
/// (küçük zıplama) yay çizerek altın sayacına uçar; varınca sayaç sayar
/// (sayaç dışarıda güncellenir). Kaynakta süzülen "+X" etiketi.
///
/// [progress] dışarıdan sürülür. Sadece etiket dokunma yakalar ([onSkip]);
/// gerisi dokunmayı haritaya geçirir.
class CollectCelebration extends StatelessWidget {
  const CollectCelebration({
    super.key,
    required this.progress,
    required this.coins,
    required this.target,
    required this.total,
    this.onSkip,
  });

  final Animation<double> progress;
  final List<FlyCoin> coins;
  final Offset target;
  final int total;
  final VoidCallback? onSkip;

  /// Sikkeleri kaynaklara sırayla dağıtır (her kaynaktan en az biri).
  static List<FlyCoin> makeCoins(List<Offset> sources, {bool lite = false}) {
    final n = math.max(
      sources.length,
      lite ? GameConfig.collectCoinsLite : GameConfig.collectCoins,
    );
    return List.generate(n, (i) {
      final from = sources[i % sources.length];
      return FlyCoin(
        from + Offset(_rnd.nextDouble() * 16 - 8, _rnd.nextDouble() * 8 - 4),
        GameConfig.collectStagger * i / math.max(n - 1, 1),
        _rnd.nextDouble() * 2 - 1,
      );
    });
  }

  /// İlk sikkenin sayaca vardığı an (sayaç o zaman saymaya başlar).
  static double get firstArrival => 1 - GameConfig.collectStagger;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    final label = coins.first.from;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final lt = (t / 0.8).clamp(0.0, 1.0);
        final opacity = lt < 0.7 ? 1.0 : 1 - (lt - 0.7) / 0.3;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CoinPainter(t, coins, target)),
              ),
            ),
            Positioned(
              left: label.dx - 60,
              width: 120,
              top: label.dy - 64 - 40 * Curves.easeOut.transform(lt),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
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
                          Text('+$total', style: style),
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

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.t, this.coins, this.target);

  final double t;
  final List<FlyCoin> coins;
  final Offset target;

  static const _r = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final span = 1 - GameConfig.collectStagger;
    for (final c in coins) {
      final p = ((t - c.delay) / span).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      // İlk %20: yerinde zıplayarak belirir; sonra hızlanarak yay çizer.
      final pop = (p / 0.2).clamp(0.0, 1.0);
      final fly = ((p - 0.2) / 0.8).clamp(0.0, 1.0);
      final e = Curves.easeInCubic.transform(fly);
      final start = c.from - Offset(0, 18 * Curves.easeOut.transform(pop));
      final ctrl =
          Offset.lerp(start, target, 0.3)! +
          Offset(c.sway * 50, -GameConfig.collectArc);
      final a = Offset.lerp(start, ctrl, e)!;
      final b = Offset.lerp(ctrl, target, e)!;
      final pos = Offset.lerp(a, b, e)!;
      final scale = Curves.elasticOut.transform(pop) * (1 - 0.35 * e);
      // Dönüyormuş gibi: yatay genişlik salınır.
      final spin = 0.55 + 0.45 * math.cos(p * 5 * math.pi + c.sway).abs();
      _coin(canvas, pos, _r * scale, spin);
    }
  }

  void _coin(Canvas c, Offset p, double r, double spin) {
    if (r <= 0.3) return;
    final rect = Rect.fromCenter(center: p, width: r * 2 * spin, height: r * 2);
    c.drawOval(
      rect.shift(const Offset(0, 1.5)),
      Paint()..color = AppColors.text.withValues(alpha: 0.15),
    );
    c.drawOval(rect, Paint()..color = AppColors.coinRim);
    c.drawOval(rect.deflate(r * 0.22), Paint()..color = AppColors.coinFace);
    c.drawOval(
      Rect.fromCenter(
        center: p + Offset(-r * 0.25 * spin, -r * 0.3),
        width: r * 0.5 * spin,
        height: r * 0.35,
      ),
      Paint()..color = AppColors.surface.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.t != t;
}
