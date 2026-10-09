import 'dart:ui' show Color;

import '../../core/config/game_config.dart';
import '../../core/hex/hex_service.dart';
import '../../core/theme/app_colors.dart';
import 'tent_model.dart';

/// Adım 2.4: ev (2), otel (3), gökdelen (4) 3D geometrisi. Çadır gibi metre
/// ölçülü, düz renkli fill-extrusion parçaları ("oyuncak blok" tarzı); ölçüler
/// hücre yarıçapına oranlı, ön yüz (+u) hücre kenarına paralel. Her seviye
/// bir öncekinden daha büyük, daha detaylı ve daha renkli:
/// ev = bahçeli modern ev, otel = havuzlu resort, gökdelen = kademeli cam kule.
///
/// Her parçada kurulum zamanlaması var (`extrusionFeature`: gecikme/süre/
/// büyüme/oturma); animasyon katmanı bunu tek ifadeyle oynatır. Bayraklar
/// çadırdaki gibi yapı yönünden bağımsız hep doğuya (sağa) dalgalanır.
/// Gölge her parçadan ayrı düşer (ışık sol üstten) ve blok tepesine kırpılır.
class BuildingModel {
  BuildingModel(this._hex);

  final HexService _hex;
  final _cache = <String, _Builder>{};

  _Builder _get(String h3, int level, Color flag) =>
      _cache['$h3|$level|${flag.toARGB32()}'] ??= _make(h3, level, flag);

  /// Yapının parçaları. [flag] sahibin rengi.
  List<Map<String, dynamic>> parts(String h3, int level, Color flag) =>
      _get(h3, level, flag).parts;

  /// Parça parça gölge (renkten bağımsız).
  List<Map<String, dynamic>> shadow(String h3, int level) =>
      _get(h3, level, AppColors.text).shadows;

  /// Yapının blok tepesinden en yüksek noktası (m), efekt konumu için.
  double topHeight(String h3, int level) => _get(h3, level, AppColors.text).top;

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

  /// Bahçeli modern ev: beyaz ana kütle + iki tonlu mercan beşik çatı,
  /// düz çatılı ahşap kanat ve cam vitrin, turkuaz kapı, çalılar, bayrak.
  void _house(_Builder b, Color flag) {
    // Bahçe ve yol.
    b.box(
      0,
      0,
      0.34,
      0.30,
      AppColors.lawn,
      0,
      0.012,
      span: 0.14,
      shadow: false,
    );
    b.box(
      0.24,
      -0.05,
      0.10,
      0.035,
      AppColors.paving,
      0.012,
      0.016,
      delay: 0.08,
      span: 0.1,
      shadow: false,
    );

    // Ana kütle + ahşap süpürgelik.
    const mu = -0.03, mw = -0.05;
    b.box(
      mu,
      mw,
      0.17,
      0.16,
      AppColors.houseWall,
      0.012,
      0.20,
      delay: 0.1,
      span: 0.36,
    );
    b.box(
      mu,
      mw,
      0.175,
      0.165,
      AppColors.houseWood,
      0.012,
      0.03,
      delay: 0.1,
      span: 0.1,
      shadow: false,
    );

    // Ahşap kanat: düz beyaz çatı, cam vitrin.
    b.box(
      0,
      0.18,
      0.13,
      0.085,
      AppColors.houseWood,
      0.012,
      0.15,
      delay: 0.2,
      span: 0.3,
    );
    b.box(
      0,
      0.18,
      0.145,
      0.10,
      AppColors.trimWhite,
      0.15,
      0.17,
      delay: 0.56,
      span: 0.14,
      grow: false,
      drop: 0.12,
    );
    b.box(
      0.133,
      0.18,
      0.005,
      0.06,
      AppColors.glass,
      0.035,
      0.13,
      delay: 0.44,
      span: 0.1,
      shadow: false,
    );
    b.box(
      0,
      0.268,
      0.09,
      0.005,
      AppColors.glass,
      0.05,
      0.12,
      delay: 0.46,
      span: 0.1,
      shadow: false,
    );

    // Kapı + saçak.
    b.box(
      0.143,
      mw,
      0.006,
      0.035,
      AppColors.houseDoor,
      0.03,
      0.13,
      delay: 0.4,
      span: 0.1,
      shadow: false,
    );
    b.box(
      0.16,
      mw,
      0.022,
      0.055,
      AppColors.trimWhite,
      0.135,
      0.145,
      delay: 0.5,
      span: 0.1,
      grow: false,
    );

    // Pencereler: beyaz pervaz, sonra "ışık yanar".
    for (final w in const [-0.15, 0.05]) {
      b.box(
        0.143,
        w,
        0.007,
        0.042,
        AppColors.trimWhite,
        0.065,
        0.155,
        delay: 0.42,
        span: 0.08,
        shadow: false,
      );
      b.box(
        0.147,
        w,
        0.006,
        0.032,
        AppColors.windowLit,
        0.072,
        0.148,
        delay: 0.5,
        span: 0.1,
        grow: false,
        shadow: false,
      );
    }
    for (final u in const [-0.11, 0.04]) {
      b.box(
        u,
        -0.213,
        0.032,
        0.006,
        AppColors.windowLit,
        0.075,
        0.145,
        delay: 0.54,
        span: 0.1,
        grow: false,
        shadow: false,
      );
    }
    b.box(
      -0.203,
      mw,
      0.006,
      0.05,
      AppColors.windowLit,
      0.075,
      0.145,
      delay: 0.54,
      span: 0.1,
      grow: false,
      shadow: false,
    );

    // Beşik çatı: sırta doğru daralan iki tonlu basamaklar, tepeden oturur.
    const n = 9;
    const roofB = 0.20, roofH = 0.15;
    for (var k = 0; k < n; k++) {
      final p = (k + 0.5) / n;
      b.box(
        mu,
        mw,
        0.19,
        0.18 * (1 - p) + 0.012,
        (k ~/ 2).isEven ? AppColors.houseRoof : AppColors.houseRoofLight,
        roofB + roofH * k / n,
        roofB + roofH * (k + 1) / n,
        delay: 0.6 + k * 0.01,
        span: 0.22,
        grow: false,
        drop: 0.22,
      );
    }
    b.box(
      mu,
      mw,
      0.2,
      0.012,
      AppColors.trimWhite,
      roofB + roofH,
      roofB + roofH + 0.01,
      delay: 0.82,
      span: 0.1,
      grow: false,
      drop: 0.15,
    );
    b.box(
      -0.12,
      -0.14,
      0.024,
      0.024,
      AppColors.houseChimney,
      0.22,
      0.37,
      delay: 0.8,
      span: 0.12,
      grow: false,
      drop: 0.18,
    );

    // Çalılar.
    b.bush(0.27, -0.22, 0.04, 0.3);
    b.bush(0.27, 0.10, 0.035, 0.34);
    b.bush(-0.27, 0.22, 0.045, 0.38);
    b.bush(-0.26, -0.22, 0.04, 0.36);

    // Bayrak kanadın çatısında.
    b.flag(-0.08, 0.22, 0.17, 0.2, flag, 0.86);
  }

  /// Havuzlu resort otel: cam lobi + turuncu tente, beyaz kule, kat kat
  /// renkli balkonlar ve yanan pencere şeritleri, çatı havuzu, palmiyeler,
  /// sahip renginde tabela ve bayrak.
  void _hotel(_Builder b, Color flag) {
    b.box(
      0,
      0,
      0.36,
      0.32,
      AppColors.paving,
      0,
      0.012,
      span: 0.12,
      shadow: false,
    );
    for (final s in const [-1.0, 1.0]) {
      b.box(
        0,
        s * 0.27,
        0.30,
        0.035,
        AppColors.lawn,
        0.012,
        0.016,
        delay: 0.05,
        span: 0.1,
        shadow: false,
      );
    }
    for (final (u, w, d) in const [
      (0.30, -0.27, 0.3),
      (0.30, 0.27, 0.33),
      (-0.30, -0.27, 0.36),
      (-0.30, 0.27, 0.39),
    ]) {
      b.palm(u, w, 0.15, d);
    }

    // Cam lobi + beyaz lobi çatısı, sütunlu tente.
    b.box(
      0.02,
      0,
      0.25,
      0.22,
      AppColors.glass,
      0.012,
      0.08,
      delay: 0.06,
      span: 0.2,
    );
    b.box(
      0.02,
      0,
      0.26,
      0.23,
      AppColors.trimWhite,
      0.08,
      0.095,
      delay: 0.2,
      span: 0.08,
    );
    for (final s in const [-1.0, 1.0]) {
      b.box(
        0.30,
        s * 0.085,
        0.008,
        0.008,
        AppColors.trimWhite,
        0.012,
        0.07,
        delay: 0.24,
        span: 0.08,
      );
    }
    b.box(
      0.30,
      0,
      0.035,
      0.11,
      AppColors.hotelAwning,
      0.07,
      0.085,
      delay: 0.3,
      span: 0.1,
      grow: false,
      drop: 0.06,
    );

    // Kule.
    const floors = 6;
    const fh = 0.075, base = 0.095, top = base + floors * fh;
    const tu = -0.03;
    b.box(
      tu,
      0,
      0.19,
      0.17,
      AppColors.hotelWall,
      base,
      top,
      delay: 0.14,
      span: 0.4,
    );
    for (final s in const [-1.0, 1.0]) {
      b.box(
        0.16,
        s * 0.17,
        0.012,
        0.012,
        AppColors.hotelAccent,
        base,
        top + 0.02,
        delay: 0.14,
        span: 0.4,
        shadow: false,
      );
    }
    for (var i = 0; i < floors; i++) {
      final z0 = base + i * fh;
      final d = 0.2 + i * 0.06;
      final lit = 0.5 + i * 0.04;
      // Balkon: beyaz döşeme + renkli korkuluk (mor/pembe sırayla).
      b.box(
        0.175,
        0,
        0.016,
        0.16,
        AppColors.trimWhite,
        z0,
        z0 + 0.01,
        delay: d,
        span: 0.08,
        grow: false,
      );
      b.box(
        0.189,
        0,
        0.004,
        0.16,
        i.isEven ? AppColors.hotelAccent : AppColors.hotelAccent2,
        z0 + 0.01,
        z0 + 0.03,
        delay: d + 0.02,
        span: 0.08,
        grow: false,
        shadow: false,
      );
      // Kat kat yanan pencere şeritleri (dört yüz).
      final zw0 = z0 + 0.025, zw1 = z0 + 0.062;
      b.box(
        0.163,
        0,
        0.004,
        0.14,
        AppColors.windowLit,
        zw0,
        zw1,
        delay: lit,
        span: 0.08,
        grow: false,
        shadow: false,
      );
      b.box(
        -0.223,
        0,
        0.004,
        0.14,
        AppColors.windowLit,
        zw0,
        zw1,
        delay: lit,
        span: 0.08,
        grow: false,
        shadow: false,
      );
      for (final s in const [-1.0, 1.0]) {
        b.box(
          tu,
          s * 0.173,
          0.16,
          0.004,
          AppColors.windowLit,
          zw0,
          zw1,
          delay: lit,
          span: 0.08,
          grow: false,
          shadow: false,
        );
      }
    }

    // Çatı: mor kenar, havuz, sahip renginde tabela, bayrak.
    b.box(
      tu,
      0,
      0.2,
      0.18,
      AppColors.hotelAccent,
      top,
      top + 0.02,
      delay: 0.7,
      span: 0.14,
      grow: false,
      drop: 0.15,
    );
    b.box(
      0.03,
      0.05,
      0.08,
      0.09,
      AppColors.trimWhite,
      top + 0.02,
      top + 0.028,
      delay: 0.78,
      span: 0.1,
      grow: false,
      drop: 0.1,
      shadow: false,
    );
    b.box(
      0.03,
      0.05,
      0.07,
      0.08,
      AppColors.pool,
      top + 0.02,
      top + 0.031,
      delay: 0.78,
      span: 0.1,
      grow: false,
      drop: 0.1,
      shadow: false,
    );
    b.box(
      -0.14,
      -0.06,
      0.012,
      0.09,
      flag,
      top + 0.02,
      top + 0.09,
      delay: 0.82,
      span: 0.1,
      grow: false,
      drop: 0.12,
    );
    b.flag(-0.15, 0.11, top + 0.02, 0.2, flag, 0.86);
  }

  /// Kademeli cam gökdelen: ağaçlı meydan + fıskiye, cam podyum, yukarı
  /// doğru açılan cam tonlarında katlar (tek tek dizilir), nane köşe
  /// şeritleri, ışıklı taç, anten + ikaz ışığı, tepede bayrak.
  void _skyscraper(_Builder b, Color flag) {
    b.box(
      0,
      0,
      0.36,
      0.32,
      AppColors.paving,
      0,
      0.012,
      span: 0.06,
      shadow: false,
    );
    for (final (u, w, d) in const [
      (0.29, -0.26, 0.05),
      (0.29, 0.26, 0.06),
      (-0.29, -0.26, 0.07),
      (-0.29, 0.26, 0.08),
    ]) {
      b.bush(u, w, 0.045, d);
    }
    b.box(
      0.30,
      0,
      0.045,
      0.06,
      AppColors.trimWhite,
      0.012,
      0.022,
      delay: 0.06,
      span: 0.06,
      shadow: false,
    );
    b.box(
      0.30,
      0,
      0.035,
      0.05,
      AppColors.pool,
      0.012,
      0.026,
      delay: 0.08,
      span: 0.06,
      shadow: false,
    );

    // Podyum: cam + beyaz çatı + nane giriş saçağı.
    b.box(
      0,
      0,
      0.26,
      0.23,
      AppColors.glass,
      0.012,
      0.075,
      delay: 0.04,
      span: 0.1,
    );
    b.box(
      0,
      0,
      0.27,
      0.24,
      AppColors.trimWhite,
      0.075,
      0.09,
      delay: 0.1,
      span: 0.05,
    );
    b.box(
      0.275,
      0,
      0.025,
      0.07,
      AppColors.skyFin,
      0.045,
      0.055,
      delay: 0.12,
      span: 0.05,
      grow: false,
    );

    // Katlar: kademe kademe daralır, cam tonu yukarı doğru açılır.
    const tiers = [(0.20, 0.17), (0.155, 0.13), (0.11, 0.09)];
    const glass = [
      AppColors.skyGlass,
      AppColors.skyGlassMid,
      AppColors.skyGlassTop,
    ];
    const fh = GameConfig.skyFloorHeight;
    final total = GameConfig.skyTierFloors.fold<int>(0, (a, b) => a + b);
    double floorDelay(int i) => 0.14 + 0.62 * i / total;
    var z = 0.09;
    var i = 0;
    for (var t = 0; t < tiers.length; t++) {
      final (hu, hw) = tiers[t];
      final z0 = z, i0 = i;
      for (var f = 0; f < GameConfig.skyTierFloors[t]; f++, i++) {
        final d = floorDelay(i);
        b.box(
          0,
          0,
          hu,
          hw,
          glass[t],
          z,
          z + fh * 0.78,
          delay: d,
          span: 0.06,
          shadow: false,
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
          shadow: false,
        );
        z += fh;
      }
      // Kademe gölgesi tek parça; köşe şeritleri katlarla birlikte uzar.
      b.shadowBox(0, 0, hu, hw, z0, z);
      for (final su in const [-1.0, 1.0]) {
        for (final sw in const [-1.0, 1.0]) {
          b.box(
            su * hu,
            sw * hw,
            0.012,
            0.012,
            AppColors.skyFin,
            z0,
            z,
            delay: floorDelay(i0),
            span: floorDelay(i) - floorDelay(i0),
            shadow: false,
          );
        }
      }
    }

    // Işıklı taç, makine katı, anten + ikaz ışığı, bayrak.
    b.box(
      0,
      0,
      0.115,
      0.095,
      AppColors.windowLit,
      z,
      z + 0.03,
      delay: 0.8,
      span: 0.06,
    );
    b.box(
      0,
      0,
      0.06,
      0.05,
      AppColors.trimWhite,
      z + 0.03,
      z + 0.06,
      delay: 0.84,
      span: 0.05,
    );
    b.box(
      0,
      0,
      0.012,
      0.012,
      AppColors.poleMetal,
      z + 0.06,
      z + 0.32,
      delay: 0.87,
      span: 0.07,
    );
    b.box(
      0,
      0,
      0.02,
      0.02,
      AppColors.skyBeacon,
      z + 0.32,
      z + 0.345,
      delay: 0.94,
      span: 0.04,
      grow: false,
    );
    b.pennant(0, 0, z + 0.27, flag, 0.9, len: 0.14);
  }
}

/// Parçaları ve gölgelerini toplar; ölçüler yarıçap oranı, metreye burada
/// çevrilir.
class _Builder {
  _Builder(this.h3, this.f) : r = f.r;

  final String h3;
  final HexFrame f;
  final double r;
  final parts = <Map<String, dynamic>>[];
  final shadows = <Map<String, dynamic>>[];

  /// En yüksek nokta (m, blok tepesine göre).
  double top = 0;

  // Işık sol üstten → gölge sağ alta (dünyada güney-doğu).
  static const _k = GameConfig.tentShadowLength;
  static const _dx = 0.7071, _dy = -0.7071;

  /// Dünya metresi köşeleriyle bir parça; [b]/[t] metre.
  void part(
    List<List<double>> xy,
    Color color,
    double b,
    double t, {
    double delay = 0,
    double span = 1,
    bool grow = true,
    double drop = 0,
    bool shadow = true,
  }) {
    parts.add(
      extrusionFeature(
        h3,
        f.ring(xy),
        color,
        b,
        t,
        delay: delay,
        span: span,
        grow: grow,
        drop: drop * r,
      ),
    );
    if (t > top) top = t;
    if (shadow) _shadow(xy, b, t);
  }

  /// Parçanın gölgesi: taban ve tavan köşeleri yükseklikleriyle orantılı
  /// sağ alta yansıtılır, dışbükey zarfı alınır, altıgene kırpılır.
  void _shadow(List<List<double>> xy, double b, double t) {
    final pts = <List<double>>[
      for (final z in [b, t])
        for (final q in xy) [q[0] + _dx * _k * z, q[1] + _dy * _k * z],
    ];
    final c = f.clip(convexHull(pts));
    if (c.length >= 3) {
      shadows.add(extrusionFeature(h3, f.ring(c), AppColors.text, 0, 0.3));
    }
  }

  List<List<double>> _rect(double cu, double cw, double hu, double hw) => [
    for (final c in const [
      [-1.0, -1.0],
      [1.0, -1.0],
      [1.0, 1.0],
      [-1.0, 1.0],
    ])
      f.world((cu + c[0] * hu) * r, (cw + c[1] * hw) * r),
  ];

  /// Hücre eksenlerine hizalı kutu; tüm ölçüler yarıçap oranı.
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
    bool shadow = true,
  }) => part(
    _rect(cu, cw, hu, hw),
    color,
    b * r,
    t * r,
    delay: delay,
    span: span,
    grow: grow,
    drop: drop,
    shadow: shadow,
  );

  /// Sadece gölge (çok katlı kütlenin tek parça gölgesi için).
  void shadowBox(
    double cu,
    double cw,
    double hu,
    double hw,
    double b,
    double t,
  ) => _shadow(_rect(cu, cw, hu, hw), b * r, t * r);

  /// İki katlı yuvarlak hissi veren çalı/ağaç tepesi.
  void bush(double cu, double cw, double s, double delay) {
    box(
      cu,
      cw,
      s,
      s,
      AppColors.bush,
      0.012,
      0.012 + s * 1.3,
      delay: delay,
      span: 0.12,
    );
    box(
      cu,
      cw,
      s * 0.68,
      s * 0.68,
      AppColors.bushLight,
      0.012 + s * 1.3,
      0.012 + s * 1.9,
      delay: delay + 0.04,
      span: 0.1,
    );
  }

  /// Palmiye: ince gövde, çapraz yapraklar, açık yeşil tepe.
  void palm(double cu, double cw, double h, double delay) {
    box(
      cu,
      cw,
      0.011,
      0.011,
      AppColors.palmTrunk,
      0.012,
      h,
      delay: delay,
      span: 0.12,
    );
    box(
      cu,
      cw,
      0.06,
      0.013,
      AppColors.bush,
      h,
      h + 0.012,
      delay: delay + 0.08,
      span: 0.1,
      grow: false,
      drop: 0.04,
    );
    box(
      cu,
      cw,
      0.013,
      0.06,
      AppColors.bush,
      h,
      h + 0.012,
      delay: delay + 0.08,
      span: 0.1,
      grow: false,
      drop: 0.04,
    );
    box(
      cu,
      cw,
      0.028,
      0.028,
      AppColors.bushLight,
      h + 0.012,
      h + 0.03,
      delay: delay + 0.1,
      span: 0.1,
      grow: false,
      drop: 0.04,
    );
  }

  /// Direk + sarı topuz + flama. [zBase] direk tabanı, [h] boyu (r oranı).
  void flag(
    double cu,
    double cw,
    double zBase,
    double h,
    Color color,
    double delay,
  ) {
    box(
      cu,
      cw,
      0.008,
      0.008,
      AppColors.poleMetal,
      zBase,
      zBase + h,
      delay: delay,
      span: 0.08,
    );
    box(
      cu,
      cw,
      0.016,
      0.016,
      AppColors.windowLit,
      zBase + h,
      zBase + h + 0.016,
      delay: delay + 0.06,
      span: 0.06,
      grow: false,
    );
    pennant(cu, cw, zBase + h - 0.045, color, delay + 0.04);
  }

  /// Flama: direkten başlayıp dünyada hep doğuya (sağa) uzanır, uca doğru
  /// incelir (çadırdaki gibi). [zMid] orta yükseklik (r oranı).
  void pennant(
    double cu,
    double cw,
    double zMid,
    Color color,
    double delay, {
    double len = 0.12,
  }) {
    const segs = GameConfig.tentPennantSegments;
    final q = f.world(cu * r, cw * r);
    final pole = 0.010 * r;
    final segLen = len * r / segs;
    final half0 = 0.035 * r;
    final t = pole * 0.7;
    for (var i = 0; i < segs; i++) {
      final x0 = q[0] + pole + segLen * i, x1 = x0 + segLen;
      final half = half0 * (1 - 0.8 * i / segs);
      part(
        [
          [x0, q[1] - t],
          [x1, q[1] - t],
          [x1, q[1] + t],
          [x0, q[1] + t],
        ],
        color,
        zMid * r - half,
        zMid * r + half,
        delay: delay + i * 0.01,
        span: 0.06,
        grow: false,
      );
    }
  }
}
