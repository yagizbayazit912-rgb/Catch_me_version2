import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../core/config/game_config.dart';
import '../../core/theme/app_colors.dart';

int _claimSoundCount = 0;

/// Claim anı: titreşim motoru + medya sesi (PROJE_PLANI 14.1-B/2).
/// Titreşim sistemin "dokunma geri bildirimi" ayarına bağlı değildir; cihazda
/// motor yoksa [HapticFeedback]'e düşer. Ses dosyası yoksa sessizce geçer.
/// Ardışık claim'lerde ses tonu hafifçe değişir (monotonluk olmasın).
Future<void> playClaimFeedback() async {
  if (GameConfig.hapticsEnabled) {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          duration: GameConfig.claimVibrateMs,
          amplitude: GameConfig.claimVibrateAmplitude,
        );
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }
  if (GameConfig.soundEnabled) {
    try {
      // Her claim için ayrı oynatıcı: tek oynatıcıyı tekrar çalmak takılıyordu.
      final player = AudioPlayer();
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.setPlaybackRate(1.0 + 0.06 * (_claimSoundCount++ % 4));
      await player.play(AssetSource(GameConfig.claimSoundAsset));
    } catch (_) {
      // Ses dosyası yok / çalınamadı: sessiz devam.
    }
  }
}

/// Claim kutlaması: ripple halkaları, parıltılar ve yukarı süzülen "+1 Bölge".
/// UI'yı bloklamaz: sadece "+1 Bölge" etiketi dokunma yakalar (dokununca
/// atlanır), gerisi dokunmayı haritaya geçirir. Bitince [onDone] çağrılır.
/// [reduceMotion] açıksa animasyonsuz, kısa bir bildirim gösterir.
class ClaimCelebration extends StatefulWidget {
  const ClaimCelebration({
    super.key,
    required this.onDone,
    this.reduceMotion = false,
    this.lite = false,
  });

  final VoidCallback onDone;
  final bool reduceMotion;

  /// Düşük donanım yedek modu: daha az parçacık, tek halka.
  final bool lite;

  @override
  State<ClaimCelebration> createState() => _ClaimCelebrationState();
}

class _ClaimCelebrationState extends State<ClaimCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.reduceMotion ? 700 : GameConfig.claimCelebrationMs,
    ),
  );
  late final List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    final n = widget.lite
        ? GameConfig.claimSparklesLite
        : GameConfig.claimSparkles;
    _sparkles = List.generate(n, (i) => _Sparkle(rnd, i, n));
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Dokununca animasyon hızlıca biter (atlanabilir).
  void _skip() {
    if (!_c.isAnimating) return;
    _c.animateTo(1, duration: const Duration(milliseconds: 80));
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // Yazı: t=0.2'den sonra belirir, yukarı süzülür, sonda silinir.
        final tt = ((t - 0.2) / 0.8).clamp(0.0, 1.0);
        final opacity = tt < 0.7 ? 1.0 : (1 - (tt - 0.7) / 0.3);
        return Stack(
          children: [
            if (!widget.reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CelebrationPainter(
                      t,
                      _sparkles,
                      widget.lite ? 1 : GameConfig.claimRippleRings,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: const Alignment(0, -0.15),
              child: Transform.translate(
                offset: Offset(0, widget.reduceMotion ? 0 : -70 * tt),
                child: Opacity(
                  opacity: tt == 0 ? 0 : opacity.clamp(0.0, 1.0),
                  child: GestureDetector(
                    onTap: _skip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text('+1 Bölge', style: style),
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

class _Sparkle {
  _Sparkle(math.Random r, int i, int n)
    : angle = (i / n) * 2 * math.pi + r.nextDouble() * 0.4,
      distance = 70 + r.nextDouble() * 90,
      size = 3 + r.nextDouble() * 4,
      color = const [
        AppColors.accentButter,
        AppColors.accentPeach,
        AppColors.accentLavender,
        AppColors.primary,
      ][i % 4];

  final double angle;
  final double distance;
  final double size;
  final Color color;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.t, this.sparkles, this.rings);

  final double t;
  final List<_Sparkle> sparkles;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    // Merkez: altıgen kullanıcının konumunda, kamera ona baktığı için ekranın
    // ortasına yakın (hafif yukarıda).
    final c = Offset(size.width / 2, size.height * 0.46);

    // Ripple halkaları (200–700 ms ≈ t 0.14–0.5), her biri biraz gecikmeli.
    for (var i = 0; i < rings; i++) {
      final rt = ((t - 0.14 - i * 0.12) / 0.4).clamp(0.0, 1.0);
      if (rt <= 0 || rt >= 1) continue;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - rt) + 1
        ..color = AppColors.primary.withValues(alpha: 0.6 * (1 - rt));
      canvas.drawCircle(c, 30 + 150 * Curves.easeOut.transform(rt), p);
    }

    // Parıltılar (300–900 ms ≈ t 0.21–0.65): dışa saçılır, solar.
    final st = ((t - 0.21) / 0.5).clamp(0.0, 1.0);
    if (st > 0 && st < 1) {
      final e = Curves.easeOutCubic.transform(st);
      for (final s in sparkles) {
        final pos =
            c + Offset(math.cos(s.angle), math.sin(s.angle)) * s.distance * e;
        canvas.drawCircle(
          pos,
          s.size * (1 - st * 0.5),
          Paint()..color = s.color.withValues(alpha: 1 - st),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.t != t;
}
