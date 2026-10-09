import 'dart:ui' show Color;

import '../../core/config/game_config.dart';
import '../../core/hex/hex_service.dart';
import '../../core/theme/app_colors.dart';
import 'tent_model.dart';

/// Adım 2.4: ev (2), otel (3), gökdelen (4) 3D geometrisi. Çadır gibi metre
/// ölçülü fill-extrusion parçaları; ölçüler hücre yarıçapına oranlı, ön yüz
/// (+u) hücre kenarına paralel. Her parçada kurulum zamanlaması var
/// (`extrusionFeature`: gecikme/süre/büyüme/oturma), animasyon katmanı bunu
/// tek ifadeyle oynatır: ev/otel aşağıdan yükselir → ışıklar yanar → çatı
/// tepeden oturur; gökdelen katları tek tek dizilir, tepeye bayrak.
class BuildingModel {
  BuildingModel(this._hex);

  final HexService _hex;
  final _cache = <String, List<Map<String, dynamic>>>{};
  final _shadowCache = <String, List<Map<String, dynamic>>>{};

  /// Yapının parçaları. [flag] sahibin rengi.
  List<Map<String, dynamic>> parts(String h3, int level, Color flag) =>
      _cache['$h3|$level|${flag.toARGB32()}'] ??= _make(h3, level, flag).parts;

  /// Ana kütlenin sağ alta düşen gölgesi (ışık sol üstten).
  List<Map<String, dynamic>> shadow(String h3, int level) =>
      _shadowCache['$h3|$level'] ??= _make(h3, level, AppColors.text).shadow;

  /// Yapının blok tepesinden en yüksek noktası (m), efekt konumu için.
  double topHeight(String h3, int level) =>
      HexFrame(_hex, h3).r *
      switch (level) {
        2 => 0.42,
        3 => 0.62,
        _ => _skyTop + 0.22,
      };

  static double get _skyTop =>
      0.06 +
      GameConfig.skyTierFloors.fold<int>(0, (a, b) => a + b) *
          GameConfig.skyFloorHeight;

  _Builder _make(String h3, int level, Color flag) {
    final b = _Builder(h3, HexFrame(_hex, h3));
    switch (level) {
      case 2:
        _house(b, flag);
      case 3:
        _hotel(b, flag);
      default:
        _skyscraper(b, flag);
    }
    return b;
  }

  void _house(_Builder b, Color flag) {
    final r = b.r;
    const wallTop = 0.22;
    b.box(0, 0, 0.27, 0.23, AppColors.houseBase, 0, 0.02, span: 0.2);
    b.box(
      0,
      0,
      0.24,
      0.20,
      AppColors.houseWall,
      0.02,
      wallTop,
      delay: 0.08,
      span: 0.42,
      mass: true,
    );
    // Kapı + yanan pencereler (ön yüz ve yanlar).
    b.box(
      0.246,
      0,
      0.006,
      0.035,
      AppColors.tentDoor,
      0.02,
      0.13,
      delay: 0.45,
      span: 0.12,
    );
    for (final w in const [-0.12, 0.12]) {
      b.box(
        0.246,
        w,
        0.006,
        0.04,
        AppColors.windowLit,
        0.09,
        0.16,
        delay: 0.52,
        span: 0.1,
        grow: false,
      );
    }
    for (final s in const [-1.0, 1.0]) {
      b.box(
        0,
        s * 0.206,
        0.05,
        0.006,
        AppColors.windowLit,
        0.09,
        0.16,
        delay: 0.56,
        span: 0.1,
        grow: false,
      );
    }
    // Beşik çatı: sırta doğru daralan basamaklar, tepeden oturur.
    const n = 8;
    const roofH = 0.17;
    for (var k = 0; k < n; k++) {
      final p = (k + 0.5) / n;
      b.box(
        0,
        0,
        0.28,
        0.24 * (1 - p) + 0.012,
        AppColors.houseRoof,
        wallTop + roofH * k / n,
        wallTop + roofH * (k + 1) / n,
        delay: 0.62 + k * 0.012,
        span: 0.22,
        grow: false,
        drop: 0.25 * r,
        mass: true,
      );
    }
    // Sırtta sahip renginde şerit + baca.
    b.box(
      0,
      0,
      0.29,
      0.014,
      flag,
      wallTop + roofH,
      wallTop + roofH + 0.012,
      delay: 0.8,
      span: 0.15,
      grow: false,
      drop: 0.25 * r,
    );
    b.box(
      -0.1,
      0.12,
      0.026,
      0.026,
      AppColors.houseChimney,
      wallTop + 0.06,
      wallTop + 0.2,
      delay: 0.84,
      span: 0.14,
      grow: false,
      drop: 0.2 * r,
    );
  }

  void _hotel(_Builder b, Color flag) {
    const floors = 5;
    const fh = 0.09;
    const base = 0.03;
    const top = base + floors * fh;
    b.box(0, 0, 0.30, 0.26, AppColors.hotelTrim, 0, base, span: 0.15);
    b.box(
      0,
      0,
      0.26,
      0.22,
      AppColors.hotelWall,
      base,
      top,
      delay: 0.06,
      span: 0.42,
      mass: true,
    );
    // Kat kat yanan pencere şeritleri (dört yüz, alttan üste).
    for (var i = 0; i < floors; i++) {
      final z0 = base + i * fh + 0.03, z1 = z0 + 0.035;
      final d = 0.48 + i * 0.04;
      for (final s in const [-1.0, 1.0]) {
        b.box(
          s * 0.266,
          0,
          0.006,
          0.18,
          AppColors.windowLit,
          z0,
          z1,
          delay: d,
          span: 0.08,
          grow: false,
        );
        b.box(
          0,
          s * 0.226,
          0.21,
          0.006,
          AppColors.windowLit,
          z0,
          z1,
          delay: d,
          span: 0.08,
          grow: false,
        );
      }
    }
    // Giriş: kapı + şeftali tente.
    b.box(
      0.268,
      0,
      0.006,
      0.05,
      AppColors.text,
      base,
      base + 0.06,
      delay: 0.45,
      span: 0.1,
    );
    b.box(
      0.29,
      0,
      0.03,
      0.09,
      AppColors.hotelAwning,
      base + 0.065,
      base + 0.085,
      delay: 0.5,
      span: 0.1,
      grow: false,
    );
    // Çatı kenarı + sahip renginde tabela, tepeden oturur.
    b.box(
      0,
      0,
      0.275,
      0.235,
      AppColors.hotelTrim,
      top,
      top + 0.025,
      delay: 0.72,
      span: 0.16,
      grow: false,
      drop: 0.2 * b.r,
      mass: true,
    );
    b.box(
      0,
      0,
      0.012,
      0.14,
      flag,
      top + 0.025,
      top + 0.11,
      delay: 0.82,
      span: 0.16,
      grow: false,
      drop: 0.2 * b.r,
    );
  }

  void _skyscraper(_Builder b, Color flag) {
    const tiers = [(0.22, 0.18), (0.17, 0.14), (0.12, 0.10)];
    const fh = GameConfig.skyFloorHeight;
    final total = GameConfig.skyTierFloors.fold<int>(0, (a, b) => a + b);
    b.box(0, 0, 0.30, 0.26, AppColors.skyBand, 0, 0.06, span: 0.06, mass: true);
    var z = 0.06;
    var i = 0;
    for (var t = 0; t < tiers.length; t++) {
      final (hu, hw) = tiers[t];
      for (var f = 0; f < GameConfig.skyTierFloors[t]; f++, i++) {
        // Katlar tek tek: her kat kısa sürede büyür, sıradaki ardından.
        final d = 0.06 + 0.78 * i / total;
        b.box(
          0,
          0,
          hu,
          hw,
          AppColors.skyGlass,
          z,
          z + fh * 0.78,
          delay: d,
          span: 0.06,
          mass: true,
        );
        b.box(
          0,
          0,
          hu + 0.006,
          hw + 0.006,
          AppColors.skyBand,
          z + fh * 0.78,
          z + fh,
          delay: d + 0.03,
          span: 0.03,
        );
        z += fh;
      }
    }
    // Anten + tepede sahip renginde bayrak.
    b.box(
      0,
      0,
      0.012,
      0.012,
      AppColors.skySpire,
      z,
      z + 0.22,
      delay: 0.88,
      span: 0.06,
    );
    b.box(
      0.045,
      0,
      0.035,
      0.006,
      flag,
      z + 0.15,
      z + 0.21,
      delay: 0.94,
      span: 0.06,
      grow: false,
      drop: 0.08 * b.r,
    );
  }
}

/// Parçaları toplar; ölçüler yarıçap oranı, metreye burada çevrilir.
class _Builder {
  _Builder(this.h3, this.f) : r = f.r;

  final String h3;
  final HexFrame f;
  final double r;
  final parts = <Map<String, dynamic>>[];
  final _massPts = <List<double>>[];

  void box(
    double cu,
    double cw,
    double hu,
    double hw,
    Color color,
    double b,
    double t, {
    double delay = 0,
    double span = 1,
    bool grow = true,
    double drop = 0,
    bool mass = false,
  }) {
    parts.add(
      extrusionFeature(
        h3,
        f.rect(cu * r, cw * r, hu * r, hw * r),
        color,
        b * r,
        t * r,
        delay: delay,
        span: span,
        grow: grow,
        drop: drop,
      ),
    );
    if (!mass) return;
    // Gölge için köşeler: tepe yüksekliğiyle sağ alta yansıtılır.
    const k = GameConfig.tentShadowLength;
    const dx = 0.7071, dy = -0.7071;
    for (final c in const [
      [-1.0, -1.0],
      [1.0, -1.0],
      [1.0, 1.0],
      [-1.0, 1.0],
    ]) {
      final q = f.world((cu + c[0] * hu) * r, (cw + c[1] * hw) * r);
      _massPts.add(q);
      _massPts.add([q[0] + dx * k * t * r, q[1] + dy * k * t * r]);
    }
  }

  List<Map<String, dynamic>> get shadow => [
    extrusionFeature(h3, f.ring(convexHull(_massPts)), AppColors.text, 0, 0.3),
  ];
}
