import 'dart:math' as math;
import 'dart:ui' show Color;

import '../../core/config/game_config.dart';
import '../../core/hex/hex_service.dart';
import '../../core/theme/app_colors.dart';

/// Adım 2.2: çadırın 3D geometrisi (MapLibre fill-extrusion parçaları).
///
/// İkon yerine gerçek metre ölçülü geometri: altıgen bloğun üstüne oturur,
/// zoom/eğim/döndürmeyle birlikte ölçeklenir ve ışık alır. Ölçüler hücre
/// yarıçapına oranladır ve sırt çizgisi hücrenin bir kenarına paraleldir;
/// böylece her hücreye aynı oranda, düzgün hizalı yerleşir.
///
/// Her parçanın `b`/`h` özelliği blok tepesine göre metre (taban/tavan);
/// katman ifadesi bunlara blok yüksekliğini ve animasyon ölçeğini ekler.
class TentModel {
  TentModel(this._hex);

  final HexService _hex;
  final _cache = <String, List<Map<String, dynamic>>>{};
  final _shadowCache = <String, Map<String, dynamic>>{};

  /// Hücrenin ortalama yarıçapı (metre).
  double radius(String h3) => _Frame(_hex, h3).r;

  /// Çadır gövdesi + kapı + direk + bayrak. [flag] sahibin rengi.
  List<Map<String, dynamic>> parts(String h3, Color flag) {
    final key = '$h3|${flag.toARGB32()}';
    return _cache[key] ??= _build(h3, flag);
  }

  /// Yerdeki yumuşak gölge (ayrı, yarı saydam katmanda çizilir).
  Map<String, dynamic> shadow(String h3) => _shadowCache[h3] ??= () {
    final f = _Frame(_hex, h3);
    final o = GameConfig.tentShadowOffset * f.r;
    return _feature(
      h3,
      f.rect(
        0,
        0,
        GameConfig.tentHalfLength * f.r * 1.12,
        GameConfig.tentHalfWidth * f.r * 1.3,
        dx: o,
        dy: -o,
      ),
      AppColors.text,
      0,
      0.4,
    );
  }();

  List<Map<String, dynamic>> _build(String h3, Color flag) {
    final f = _Frame(_hex, h3);
    final r = f.r;
    final halfW = GameConfig.tentHalfWidth * r;
    final halfL = GameConfig.tentHalfLength * r;
    final height = GameConfig.tentHeight * r;
    const n = GameConfig.tentSlices;

    final out = <Map<String, dynamic>>[];

    // Profil: p (0 taban → 1 tepe) yüksekliğinde yarım genişlik ve ön yüzün
    // konumu. Çan eğrisi: taban geniş, tepe sivri; uçlar hafif içe eğik.
    double widthAt(double p) =>
        halfW * math.pow(1 - p, GameConfig.tentBellExp).toDouble();
    double frontAt(double p) => halfL * (1 - GameConfig.tentGableLean * p);

    // Kilim: çadırın altında, önde biraz taşan ince lavanta zemin.
    out.add(
      _feature(
        h3,
        f.rect(halfL * 0.12, 0, halfL * 1.28, halfW * 1.22),
        AppColors.tentRug,
        0,
        0.5,
      ),
    );

    // Gövde: daralan basamaklar; her iki basamakta bir renk → kalın çizgi.
    for (var k = 0; k < n; k++) {
      final pMid = (k + 0.5) / n;
      out.add(
        _feature(
          h3,
          f.rect(0, 0, frontAt(pMid), math.max(widthAt(pMid), 0.012 * r)),
          (k ~/ 2).isEven ? AppColors.tentStripe : AppColors.tentCanvas,
          height * k / n,
          height * (k + 1) / n,
        ),
      );
    }

    // Kapı: ön yüzde üçgen açıklık (koyu kakao, hafif içeride) ve iki yanda
    // toplanmış kanatlar (açık şeftali, biraz dışarıda) → perde açılmış gibi.
    const m = GameConfig.tentDoorSlices;
    final doorTop = GameConfig.tentDoorHeight;
    final doorDepth = 0.006 * r;
    final flapDepth = 0.014 * r;
    for (var j = 0; j < m; j++) {
      final q = (j + 0.5) / m; // kapı içinde 0 → 1
      final p = q * doorTop; // çadır yüksekliğinde
      final dHalf = 0.42 * widthAt(0) * (1 - q);
      final fHalf = 0.11 * widthAt(0) * (1 - q * 0.85);
      final front = frontAt(p);
      final b = height * doorTop * j / m;
      final t = height * doorTop * (j + 1) / m;
      out.add(
        _feature(
          h3,
          f.rect(front + doorDepth, 0, doorDepth, dHalf),
          AppColors.tentDoor,
          b,
          t,
        ),
      );
      for (final side in const [-1.0, 1.0]) {
        out.add(
          _feature(
            h3,
            f.rect(front + flapDepth, side * (dHalf + fHalf), flapDepth, fHalf),
            AppColors.tentFlap,
            b,
            t,
          ),
        );
      }
    }

    // Direk (ahşap) + tepede sarı topuz.
    final pole = 0.010 * r;
    out.add(
      _feature(
        h3,
        f.rect(0, 0, pole, pole),
        AppColors.tentPole,
        height * 0.9,
        height * 1.48,
      ),
    );
    out.add(
      _feature(
        h3,
        f.rect(0, 0, pole * 2.2, pole * 2.2),
        AppColors.tentKnob,
        height * 1.48,
        height * 1.56,
      ),
    );

    // Flama: direkten uzaklaştıkça incelen parçalar, sahibin renginde.
    const segs = GameConfig.tentPennantSegments;
    final segLen = 0.13 * r / segs;
    final mid = height * 1.34;
    final half0 = height * 0.1;
    for (var i = 0; i < segs; i++) {
      final hh = half0 * (1 - 0.8 * i / segs);
      out.add(
        _feature(
          h3,
          f.rect(pole + segLen * (i + 0.5), 0, segLen / 2, pole * 0.7),
          flag,
          mid - hh,
          mid + hh,
        ),
      );
    }
    return out;
  }

  static Map<String, dynamic> _feature(
    String h3,
    List<List<double>> ring,
    Color color,
    double base,
    double top,
  ) => {
    'type': 'Feature',
    'properties': {'h3': h3, 'color': cssColor(color), 'b': base, 'h': top},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  };
}

/// `#rrggbb` (MapLibre renk dizisi).
String cssColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Hücre merkezli yerel metre çerçevesi: x doğu, y kuzey. `u` ekseni
/// hücrenin ilk kenarına paralel (sırt yönü), `w` ona dik.
class _Frame {
  _Frame(HexService hex, String h3) {
    final c = hex.center(h3);
    lng0 = c[0];
    lat0 = c[1];
    mLng = 111320 * math.cos(lat0 * math.pi / 180);
    final pts = [
      for (final p in hex.boundary(h3))
        [(p[0] - lng0) * mLng, (p[1] - lat0) * _mLat],
    ];
    r =
        pts
            .map((p) => math.sqrt(p[0] * p[0] + p[1] * p[1]))
            .reduce((a, b) => a + b) /
        pts.length;
    final a = math.atan2(pts[1][1] - pts[0][1], pts[1][0] - pts[0][0]);
    ux = math.cos(a);
    uy = math.sin(a);
  }

  static const _mLat = 110574.0;
  late final double lng0, lat0, mLng, r, ux, uy;

  /// [cu],[cw] merkezli, u boyunca ±[hu], w boyunca ±[hw] dikdörtgen;
  /// [dx],[dy] ek dünya kayması (metre). Kapalı halka [lng, lat].
  List<List<double>> rect(
    double cu,
    double cw,
    double hu,
    double hw, {
    double dx = 0,
    double dy = 0,
  }) {
    List<double> at(double u, double w) {
      final x = u * ux - w * uy + dx;
      final y = u * uy + w * ux + dy;
      return [lng0 + x / mLng, lat0 + y / _mLat];
    }

    final ring = [
      at(cu - hu, cw - hw),
      at(cu + hu, cw - hw),
      at(cu + hu, cw + hw),
      at(cu - hu, cw + hw),
    ];
    return [...ring, ring.first];
  }
}
