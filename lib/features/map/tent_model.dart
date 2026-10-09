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
  final _shadowCache = <String, List<Map<String, dynamic>>>{};

  /// Hücrenin ortalama yarıçapı (metre).
  double radius(String h3) => HexFrame(_hex, h3).r;

  /// Çadır gövdesi + kapı + direk + bayrak. [flag] sahibin rengi.
  List<Map<String, dynamic>> parts(String h3, Color flag) {
    final key = '$h3|${flag.toARGB32()}';
    return _cache[key] ??= _build(h3, flag);
  }

  /// Çadırın şeklinden düşen gölge (ayrı, yarı saydam katmanda çizilir).
  /// Işık sol üstten → gölge sağ alta: çadırın her yüksekliğindeki kesit,
  /// yüksekliğiyle orantılı kaydırılıp zemine yansıtılır; gövde gölgesi bu
  /// noktaların dış sınırı (dışbükey zarf). Direk ayrı ince bir şerit.
  List<Map<String, dynamic>> shadow(String h3) => _shadowCache[h3] ??= () {
    final f = HexFrame(_hex, h3);
    final s = _Shape(f.r);
    const k = GameConfig.tentShadowLength;
    // Işığın tersi (dünyada güney-doğu), birim vektör.
    const dx = 0.7071, dy = -0.7071;

    final pts = <List<double>>[];
    for (var i = 0; i <= 6; i++) {
      final p = i / 6 * 0.98;
      final z = s.height * p;
      final hu = s.frontAt(p), hw = s.widthAt(p);
      for (final c in const [
        [-1.0, -1.0],
        [1.0, -1.0],
        [1.0, 1.0],
        [-1.0, 1.0],
      ]) {
        final q = f.world(c[0] * hu, c[1] * hw);
        pts.add([q[0] + dx * k * z, q[1] + dy * k * z]);
      }
    }
    final body = convexHull(pts);

    // Direk: tabanı sırtta (0.9 H), tepesi topuzda (1.56 H).
    final pw = 0.012 * f.r;
    final z0 = s.height * 0.9, z1 = s.height * 1.56;
    final pole = [
      [dx * k * z0 - dy * pw, dy * k * z0 + dx * pw],
      [dx * k * z1 - dy * pw, dy * k * z1 + dx * pw],
      [dx * k * z1 + dy * pw, dy * k * z1 - dx * pw],
      [dx * k * z0 + dy * pw, dy * k * z0 - dx * pw],
    ];

    // Flama: her parçanın alt/üst köşeleri kendi yüksekliğiyle kaydırılır;
    // üçgen bir gölge düşer.
    final flagPts = <List<double>>[];
    for (final g in s.pennant()) {
      for (final x in [g.x0, g.x1]) {
        for (final z in [g.zLo, g.zHi]) {
          for (final y in [-g.t, g.t]) {
            flagPts.add([x + dx * k * z, y + dy * k * z]);
          }
        }
      }
    }

    return [
      for (final poly in [body, pole, convexHull(flagPts)])
        if (f.clip(poly) case final c when c.length >= 3)
          extrusionFeature(h3, f.ring(c), AppColors.text, 0, 0.3),
    ];
  }();

  List<Map<String, dynamic>> _build(String h3, Color flag) {
    final f = HexFrame(_hex, h3);
    final r = f.r;
    final s = _Shape(r);
    final height = s.height;
    const n = GameConfig.tentSlices;
    final widthAt = s.widthAt;
    final frontAt = s.frontAt;

    final out = <Map<String, dynamic>>[];

    // Gövde: daralan basamaklar; her iki basamakta bir renk → kalın çizgi.
    for (var k = 0; k < n; k++) {
      final pMid = (k + 0.5) / n;
      out.add(
        extrusionFeature(
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
        extrusionFeature(
          h3,
          f.rect(front + doorDepth, 0, doorDepth, dHalf),
          AppColors.tentDoor,
          b,
          t,
        ),
      );
      for (final side in const [-1.0, 1.0]) {
        out.add(
          extrusionFeature(
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
      extrusionFeature(
        h3,
        f.rect(0, 0, pole, pole),
        AppColors.tentPole,
        height * 0.9,
        height * 1.48,
      ),
    );
    out.add(
      extrusionFeature(
        h3,
        f.rect(0, 0, pole * 2.2, pole * 2.2),
        AppColors.tentKnob,
        height * 1.48,
        height * 1.56,
      ),
    );

    // Flama: her çadırda aynı yöne (sağa / doğuya) bakar, direkten
    // uzaklaştıkça incelir, sahibin renginde.
    for (final g in s.pennant()) {
      out.add(
        extrusionFeature(
          h3,
          f.ring([
            [g.x0, -g.t],
            [g.x1, -g.t],
            [g.x1, g.t],
            [g.x0, g.t],
          ]),
          flag,
          g.zLo,
          g.zHi,
        ),
      );
    }
    return out;
  }
}

/// Bir fill-extrusion parçası. `b`/`h` blok tepesine göre taban/tavan (m).
/// Kurulum animasyonu için (2.4): `d` gecikme ve `w` süre (0–1, kurulum
/// ilerlemesinde), `g` 1 = tabandan büyür / 0 = tam boy belirir, `drop`
/// yukarıdan oturma mesafesi (m). Varsayılanlar animasyonsuz parça.
Map<String, dynamic> extrusionFeature(
  String h3,
  List<List<double>> ring,
  Color color,
  double base,
  double top, {
  double delay = 0,
  double span = 1,
  bool grow = true,
  double drop = 0,
}) => {
  'type': 'Feature',
  'properties': {
    'h3': h3,
    'color': cssColor(color),
    'b': base,
    'h': top,
    'd': delay,
    'w': span,
    'g': grow ? 1 : 0,
    'drop': drop,
  },
  'geometry': {
    'type': 'Polygon',
    'coordinates': [ring],
  },
};

/// Çadır profili: p (0 taban → 1 tepe) yüksekliğinde yarım genişlik ve ön
/// yüzün konumu. Çan eğrisi: taban geniş, tepe sivri; uçlar hafif içe eğik.
class _Shape {
  _Shape(this.r)
    : halfW = GameConfig.tentHalfWidth * r,
      halfL = GameConfig.tentHalfLength * r,
      height = GameConfig.tentHeight * r;

  final double r, halfW, halfL, height;

  /// Flama parçaları, dünya metresinde (x doğu): direğin hemen sağından
  /// başlar, uca doğru dikey boyu azalır. [t] yarım kalınlık (kuzey-güney).
  List<({double x0, double x1, double zLo, double zHi, double t})> pennant() {
    const segs = GameConfig.tentPennantSegments;
    final pole = 0.010 * r;
    final segLen = 0.13 * r / segs;
    final mid = height * 1.34;
    final half0 = height * 0.1;
    return [
      for (var i = 0; i < segs; i++)
        (
          x0: pole + segLen * i,
          x1: pole + segLen * (i + 1),
          zLo: mid - half0 * (1 - 0.8 * i / segs),
          zHi: mid + half0 * (1 - 0.8 * i / segs),
          t: pole * 0.7,
        ),
    ];
  }

  double widthAt(double p) =>
      halfW * math.pow(1 - p, GameConfig.tentBellExp).toDouble();
  double frontAt(double p) => halfL * (1 - GameConfig.tentGableLean * p);
}

/// Dışbükey zarf (monotone chain), saat yönünün tersine.
List<List<double>> convexHull(List<List<double>> pts) {
  final p = [
    ...pts,
  ]..sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  double cross(List<double> o, List<double> a, List<double> b) =>
      (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  final lower = <List<double>>[];
  for (final q in p) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  final upper = <List<double>>[];
  for (final q in p.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  return [...lower..removeLast(), ...upper..removeLast()];
}

/// `#rrggbb` (MapLibre renk dizisi).
String cssColor(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Hücre merkezli yerel metre çerçevesi: x doğu, y kuzey. `u` ekseni
/// hücrenin ilk kenarına paralel (sırt yönü), `w` ona dik.
class HexFrame {
  HexFrame(HexService hex, String h3) {
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
    // Kırpma için saat yönünün tersine, kenardan hafif içeride.
    final ccw = _area(pts) > 0 ? pts : pts.reversed.toList();
    corners = [
      for (final q in ccw) [q[0] * 0.985, q[1] * 0.985],
    ];
  }

  static double _area(List<List<double>> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[(i + 1) % p.length];
      a += p[i][0] * q[1] - q[0] * p[i][1];
    }
    return a / 2;
  }

  /// Altıgen köşeleri (dünya metresi, saat yönünün tersine).
  late final List<List<double>> corners;

  /// Dışbükey çokgeni altıgenle kırpar (Sutherland–Hodgman): gölge blok
  /// tepesinin dışına, havaya taşmasın.
  List<List<double>> clip(List<List<double>> poly) {
    var out = poly;
    for (var i = 0; i < corners.length && out.isNotEmpty; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      double side(List<double> p) =>
          (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]);
      final input = out;
      out = [];
      for (var j = 0; j < input.length; j++) {
        final p = input[j], q = input[(j + 1) % input.length];
        final sp = side(p), sq = side(q);
        if (sp >= 0) out.add(p);
        if ((sp >= 0) != (sq >= 0)) {
          final t = sp / (sp - sq);
          out.add([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]);
        }
      }
    }
    return out;
  }

  static const _mLat = 110574.0;
  late final double lng0, lat0, mLng, r, ux, uy;

  /// (u, w) → dünya metresi [x doğu, y kuzey].
  List<double> world(double u, double w) => [u * ux - w * uy, u * uy + w * ux];

  /// Dünya metresi noktalarından kapalı [lng, lat] halka.
  List<List<double>> ring(List<List<double>> xy) {
    final out = [
      for (final q in xy) [lng0 + q[0] / mLng, lat0 + q[1] / _mLat],
    ];
    return [...out, out.first];
  }

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
