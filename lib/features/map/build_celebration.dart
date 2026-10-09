import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../core/config/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// İnşa anının sesi ve titreşimi; claim'den ayrı. Çadır: toz "puf" + tahta
/// "tok" + marimba. Yükseltme (seviye ≥ 2): animasyonla senkron, baştan
/// sona süren iz (`upgrade_<seviye>.wav`; puf → yükselen kurulum notaları →
/// final), atlanırsa [stopUpgradeScore] ile kesilir. Titreşimde çift vuruş.
/// Medya sesi ve titreşim motoru (Altın Kural: sistem dokunma ayarına bağlı
/// API'ler kullanılmaz); her seferinde yeni oynatıcı.
Future<void> playBuildFeedback([int level = 1]) async {
  if (GameConfig.hapticsEnabled) {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: GameConfig.buildVibratePattern,
          intensities: GameConfig.buildVibrateIntensities,
        );
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }
  if (!GameConfig.soundEnabled) return;
  if (level <= 1) {
    _play(GameConfig.buildSoundAsset);
    return;
  }
  await stopUpgradeScore();
  try {
    final player = AudioPlayer();
    _score = player;
    player.onPlayerComplete.first.then((_) {
      if (_score == player) _score = null;
      player.dispose();
    });
    await player.play(AssetSource('audio/upgrade_$level.wav'));
  } catch (_) {
    _score = null;
  }
}

AudioPlayer? _score;

/// Çalan yükseltme izini keser (animasyon atlandı). Kesildiyse true.
Future<bool> stopUpgradeScore() async {
  final p = _score;
  _score = null;
  if (p == null) return false;
  try {
    await p.stop();
    await p.dispose();
  } catch (_) {}
  return true;
}

Future<void> _play(String asset) async {
  try {
    final player = AudioPlayer();
    player.onPlayerComplete.first.then((_) => player.dispose());
    await player.play(AssetSource(asset));
  } catch (_) {
    // Ses dosyası yok / çalınamadı: sessiz devam.
  }
}

/// Yükseltme finali (seviye ≥ 2): seviyeyle güçlenen titreşim ritmi. Ses
/// normalde kurulum izinin içinde; animasyon atlandıysa ([withSound]) sadece
/// final bölümü (`finale_<seviye>.wav`) çalınır.
Future<void> playFinaleFeedback(int level, {bool withSound = false}) async {
  if (GameConfig.hapticsEnabled) {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: GameConfig.finaleVibratePattern[level],
          intensities: GameConfig.finaleVibrateIntensities[level],
        );
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }
  if (GameConfig.soundEnabled && withSound) _play('audio/finale_$level.wav');
}

/// Gökdelende birkaç katta bir hafif "tık" titreşimi.
Future<void> floorTickFeedback() async {
  if (!GameConfig.hapticsEnabled) return;
  try {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: 14, amplitude: 70);
    } else {
      await HapticFeedback.selectionClick();
    }
  } catch (_) {}
}

/// Bir kurulumun parçacıkları ve zaman çizelgesi (bir kez üretilir; her
/// karede aynı). Seviye büyüdükçe final büyür:
/// çadır = halka + toz + parıltı; ev = + sikke yağmuru + başlık;
/// otel = + şok dalgası + konfeti; gökdelen = + havai fişek + ışık huzmesi
/// + parlama. Yükseltmede başta eski yapıdan "puf" duman yükselir.
class BuildFx {
  BuildFx(
    this.level, {
    bool lite = false,
    this.assembleEnd = 1,
    this.shrink = 0,
  }) {
    final rnd = math.Random();
    final div = lite ? 3 : 1;
    final nPuffs =
        (lite ? GameConfig.buildDustPuffsLite : GameConfig.buildDustPuffs) +
        (level - 1) * 3;
    puffs = List.generate(nPuffs, (i) => DustPuff(rnd, i, nPuffs));
    coins = List.generate(
      GameConfig.finaleCoins[level] ~/ div,
      (_) => FxCoin(rnd),
    );
    confetti = List.generate(
      GameConfig.finaleConfetti[level] ~/ div,
      (_) => FxConfetti(rnd),
    );
    bursts = List.generate(
      math.max(GameConfig.finaleFireworks[level] ~/ div, level >= 4 ? 1 : 0),
      (i) => FxBurst(rnd, i),
    );
  }

  final int level;

  /// Kurulumun bittiği oran; final bundan sonra oynar (çadırda 1).
  final double assembleEnd;

  /// Yükseltmede eski yapının küçülme payı (0 = ilk kurulum).
  final double shrink;

  late final List<DustPuff> puffs;
  late final List<FxCoin> coins;
  late final List<FxConfetti> confetti;
  late final List<FxBurst> bursts;

  bool get upgrade => level >= 2;

  /// Final yerel ilerlemesi (0–1).
  double finale(double t) =>
      upgrade ? ((t - assembleEnd) / (1 - assembleEnd)).clamp(0.0, 1.0) : 0;
}

/// Adım 2.2/2.4: inşa anının ekran efektleri (plan 14.1-C). Yapının
/// kendisi haritada 3D çizilir; bu katman toz/parıltı/final efektlerini ve
/// yazıları ekler. [ground] yapı tabanının, [top] tepesinin ekran noktası.
/// [progress] dışarıdan sürülür (harita animasyonuyla aynı saat). Sadece
/// etiketler dokunma yakalar ([onSkip]); gerisi dokunmayı haritaya geçirir.
class BuildCelebration extends StatelessWidget {
  const BuildCelebration({
    super.key,
    required this.progress,
    required this.ground,
    required this.top,
    required this.cost,
    required this.fx,
    this.reduceMotion = false,
    this.onSkip,
  });

  final Animation<double> progress;
  final Offset ground;
  final Offset top;
  final int cost;
  final BuildFx fx;
  final bool reduceMotion;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = theme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    final titleStyle = theme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        // Etiket: çadırda kurulumla, yükseltmede finalle gelir.
        final lt = fx.upgrade
            ? fx.finale(t)
            : ((t - 0.35) / 0.65).clamp(0.0, 1.0);
        final opacity = lt < 0.75 ? 1.0 : 1 - (lt - 0.75) / 0.25;
        final f = fx.finale(t);
        final titleScale = f <= 0
            ? 0.0
            : Curves.elasticOut.transform((f / 0.4).clamp(0.0, 1.0));
        final titleOpacity = f < 0.85 ? 1.0 : 1 - (f - 0.85) / 0.15;
        // Yüksek yapıda tepe ekranın üstüne yakın olabilir; yazılar içeride.
        final labelY = math.max(top.dy - 44, pad + 120);
        return Stack(
          children: [
            if (!reduceMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BuildPainter(t, ground, top, fx, screen),
                  ),
                ),
              ),
            if (fx.upgrade)
              Positioned(
                left: 0,
                right: 0,
                top: labelY - 58,
                child: Opacity(
                  opacity: titleOpacity.clamp(0.0, 1.0),
                  child: Center(
                    child: Transform.scale(
                      scale: titleScale,
                      child: GestureDetector(
                        onTap: onSkip,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: Text(
                            '${GameConfig.structureEmoji[fx.level]} '
                            '${GameConfig.structureNames[fx.level]} kuruldu!',
                            style: titleStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: top.dx - 60,
              width: 120,
              top: labelY - (reduceMotion ? 0 : 50 * lt) + (fx.upgrade ? 6 : 0),
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

class FxCoin {
  FxCoin(math.Random r)
    : dx = (r.nextDouble() - 0.5) * 150,
      land = (r.nextDouble() - 0.5) * 40,
      delay = r.nextDouble() * 0.4,
      spin = r.nextDouble() * 6;

  final double dx, land, delay, spin;
}

class FxConfetti {
  FxConfetti(math.Random r)
    : angle = -math.pi / 2 + (r.nextDouble() - 0.5) * 2.4,
      speed = 160 + r.nextDouble() * 200,
      size = 5 + r.nextDouble() * 5,
      spin = (r.nextDouble() - 0.5) * 20,
      delay = r.nextDouble() * 0.12,
      color = _palette[r.nextInt(_palette.length)];

  final double angle, speed, size, spin, delay;
  final Color color;
}

class FxBurst {
  FxBurst(math.Random r, int i)
    : offset = Offset((r.nextDouble() - 0.5) * 180, -60 - r.nextDouble() * 90),
      delay = i * 0.18,
      color = _palette[(i * 2 + r.nextInt(2)) % _palette.length];

  final Offset offset;
  final double delay;
  final Color color;
}

const _palette = [
  AppColors.accentButter,
  AppColors.accentLavender,
  AppColors.primary,
  AppColors.accentPeach,
  AppColors.secondary,
  AppColors.warning,
];

class _BuildPainter extends CustomPainter {
  _BuildPainter(this.t, this.ground, this.top, this.fx, this.screen);

  final double t;
  final Offset ground;
  final Offset top;
  final BuildFx fx;
  final Size screen;

  // Eğik kamerada zemin basık görünür; halka ve toz elips üzerinde yayılır.
  static const _flat = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    if (fx.upgrade) {
      // 1) Eski yapıdan "puf" duman (küçülürken): daha iri, daha yükseğe.
      _dust(canvas, 0, fx.shrink + 0.15, rise: 40, grow: 1.5);
    } else {
      _marker(canvas);
      _dust(canvas, 0.14, 0.46);
    }

    final f = fx.finale(t);
    if (fx.upgrade && f > 0 && f < 1) {
      if (fx.level >= 4) _flash(canvas, f);
      if (fx.level >= 4) _beam(canvas, f);
      if (fx.level >= 3) _shockwave(canvas, f);
      if (fx.level >= 4) _fireworks(canvas, f);
      if (fx.level >= 3) _confetti(canvas, f);
      _coins(canvas, f);
    }

    // Parıltı: çadırda kurulum sonunda, yükseltmede finalde (daha çok).
    final st = fx.upgrade
        ? (f / 0.6).clamp(0.0, 1.0)
        : ((t - 0.5) / 0.4).clamp(0.0, 1.0);
    if (st > 0 && st < 1) _sparkle(canvas, st, 6 + (fx.level - 1) * 3);
  }

  // Zeminde dışarıdan içeri daralan işaret halkası (t 0–0.22).
  void _marker(Canvas canvas) {
    final mt = (t / 0.22).clamp(0.0, 1.0);
    if (mt >= 1) return;
    final rad = 70 - 40 * Curves.easeOutCubic.transform(mt);
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: rad * 2, height: rad * 2 * _flat),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.surface.withValues(alpha: 0.9 * (1 - mt)),
    );
  }

  // Toz/duman bulutu: tabandan dışa yayılır, yükselir, solar.
  void _dust(
    Canvas canvas,
    double start,
    double dur, {
    double rise = 10,
    double grow = 1,
  }) {
    for (final p in fx.puffs) {
      final dt = ((t - start - p.delay) / dur).clamp(0.0, 1.0);
      if (dt <= 0 || dt >= 1) continue;
      final e = Curves.easeOutCubic.transform(dt);
      final pos =
          ground +
          Offset(
            math.cos(p.angle) * p.distance * e * grow,
            math.sin(p.angle) * p.distance * e * _flat - rise * e,
          );
      final rr = p.size * (0.6 + 0.6 * e) * grow;
      canvas.drawCircle(
        pos,
        rr,
        Paint()
          ..color = AppColors.background.withValues(alpha: 0.88 * (1 - dt)),
      );
      canvas.drawCircle(
        pos,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.textSecondary.withValues(alpha: 0.25 * (1 - dt)),
      );
    }
  }

  // Gökdelen: ekranın kısa beyaz parlaması.
  void _flash(Canvas canvas, double f) {
    final a = f < 0.25 ? 0.35 * (1 - f / 0.25) : 0.0;
    if (a <= 0) return;
    canvas.drawRect(
      Offset.zero & screen,
      Paint()..color = AppColors.surface.withValues(alpha: a),
    );
  }

  // Gökdelen: tepeden yukarı sıcak ışık huzmesi.
  void _beam(Canvas canvas, double f) {
    final a = f < 0.2 ? f / 0.2 : (1 - (f - 0.2) / 0.6).clamp(0.0, 1.0);
    if (a <= 0) return;
    final w = 30.0 + 20 * f;
    final rect = Rect.fromLTRB(top.dx - w / 2, 0, top.dx + w / 2, top.dy);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.accentButter.withValues(alpha: 0.55 * a),
            AppColors.accentButter.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  // Otel+: zeminden yayılan şok dalgası (iki halka).
  void _shockwave(Canvas canvas, double f) {
    for (final lag in const [0.0, 0.14]) {
      final w = ((f - lag) / 0.6).clamp(0.0, 1.0);
      if (w <= 0 || w >= 1) continue;
      final rad =
          30 + (fx.level >= 4 ? 190 : 140) * Curves.easeOut.transform(w);
      canvas.drawOval(
        Rect.fromCenter(
          center: ground,
          width: rad * 2,
          height: rad * 2 * _flat,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - w) + 1
          ..color = AppColors.surface.withValues(alpha: 0.9 * (1 - w)),
      );
    }
  }

  // Gökdelen: tepenin üstünde sırayla patlayan havai fişekler.
  void _fireworks(Canvas canvas, double f) {
    for (final b in fx.bursts) {
      final w = ((f - b.delay) / 0.5).clamp(0.0, 1.0);
      if (w <= 0 || w >= 1) continue;
      final c = top + b.offset;
      final e = Curves.easeOutCubic.transform(w);
      const n = 14;
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * math.pi;
        final dir = Offset(math.cos(a), math.sin(a));
        final p = c + dir * (60 * e) + Offset(0, 18 * w * w);
        final tail = c + dir * (60 * e * 0.7) + Offset(0, 14 * w * w);
        canvas.drawLine(
          tail,
          p,
          Paint()
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..color = b.color.withValues(alpha: 1 - w),
        );
        canvas.drawCircle(
          p,
          2.6 * (1 - w * 0.5),
          Paint()..color = AppColors.surface.withValues(alpha: 1 - w),
        );
      }
    }
  }

  // Otel+: tepeden fışkıran, dönerek düşen konfeti.
  void _confetti(Canvas canvas, double f) {
    for (final c in fx.confetti) {
      final w = ((f - c.delay) / 0.9).clamp(0.0, 1.0);
      if (w <= 0 || w >= 1) continue;
      final time = w * 1.4;
      final p =
          top +
          Offset(
            math.cos(c.angle) * c.speed * time,
            math.sin(c.angle) * c.speed * time + 260 * time * time,
          );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(c.spin * time);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: c.size,
          height: c.size * 0.55,
        ),
        Paint()..color = c.color.withValues(alpha: w < 0.8 ? 1 : (1 - w) / 0.2),
      );
      canvas.restore();
    }
  }

  // Ev+: yapının üstünden dönerek düşen sikkeler, zeminde solar.
  void _coins(Canvas canvas, double f) {
    for (final c in fx.coins) {
      final w = ((f - c.delay) / 0.6).clamp(0.0, 1.0);
      if (w <= 0 || w >= 1) continue;
      final y0 = top.dy - 110;
      final y1 = ground.dy + c.land * _flat;
      final pos = Offset(
        top.dx + c.dx,
        y0 + (y1 - y0) * Curves.easeIn.transform(w),
      );
      final fade = w < 0.8 ? 1.0 : 1 - (w - 0.8) / 0.2;
      final spin = math.cos((w * 3 + c.spin) * math.pi).abs();
      final rect = Rect.fromCenter(
        center: pos,
        width: 17 * (0.25 + 0.75 * spin),
        height: 17,
      );
      canvas.drawOval(
        rect,
        Paint()..color = AppColors.coinFace.withValues(alpha: fade),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.coinRim.withValues(alpha: fade),
      );
    }
  }

  void _sparkle(Canvas canvas, double st, int n) {
    final e = Curves.easeOut.transform(st);
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + (i - (n - 1) / 2) * (math.pi * 1.6 / n);
      final pos = top + Offset(math.cos(a), math.sin(a)) * (14 + 34 * e);
      _star(
        canvas,
        pos,
        4.5 * (1 - st * 0.6),
        _palette[i % _palette.length].withValues(alpha: 1 - st),
      );
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
  bool shouldRepaint(_BuildPainter old) => old.t != t || old.fx != fx;
}
