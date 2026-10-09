import 'dart:math' as math;

import '../../core/hex/hex_service.dart';

/// Sahiplenme ilerlemesinin harita geometrisi (bulunduğum altıgen).
///
/// - `ring`: altıgenin kenarlarından içe doğru dolan bant (dış halka hücre
///   sınırı, iç halka merkeze doğru küçülen altıgen; p = 1'de tam dolu).
/// - `trace`: kenar boyunca saat yönünde ilerleyen çizgi (p kadar çevre).
///
/// Karar sunucuda; bu sadece sunucunun bildirdiği süreyi gösterir.
class PresenceProgress {
  PresenceProgress(this._hex);

  final HexService _hex;

  Map<String, dynamic> collection(String h3, double p) {
    p = p.clamp(0.0, 1.0);
    if (p <= 0) return HexService.collection([]);
    final c = _hex.center(h3);
    // Kuzeydeki köşeden başla, saat yönünde (ekranda doğal okunur).
    var pts = _hex.boundary(h3);
    if (_signedArea(pts) > 0) pts = pts.reversed.toList();
    var top = 0;
    for (var i = 1; i < pts.length; i++) {
      if (pts[i][1] > pts[top][1]) top = i;
    }
    pts = [...pts.sublist(top), ...pts.sublist(0, top)];

    final outer = [...pts, pts.first];
    // İç halka: yumuşak hızlanan dolum (başta görünür bant, sonda kapanır).
    final k = (1 - p) * (1 - p);
    final inner = [
      for (final q in outer.reversed)
        [c[0] + (q[0] - c[0]) * k, c[1] + (q[1] - c[1]) * k],
    ];

    return HexService.collection([
      {
        'type': 'Feature',
        'properties': {'kind': 'ring'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            if (k > 0.01) ...[outer, inner] else outer,
          ],
        },
      },
      {
        'type': 'Feature',
        'properties': {'kind': 'trace'},
        'geometry': {'type': 'LineString', 'coordinates': _trace(outer, p)},
      },
    ]);
  }

  /// Kapalı halkanın ilk p oranı (uzunluğa göre).
  static List<List<double>> _trace(List<List<double>> ring, double p) {
    final mLng = math.cos(ring.first[1] * math.pi / 180);
    double len(List<double> a, List<double> b) =>
        math.sqrt(math.pow((b[0] - a[0]) * mLng, 2) + math.pow(b[1] - a[1], 2));
    var total = 0.0;
    for (var i = 0; i < ring.length - 1; i++) {
      total += len(ring[i], ring[i + 1]);
    }
    var left = total * p;
    final out = [ring.first];
    for (var i = 0; i < ring.length - 1 && left > 0; i++) {
      final a = ring[i], b = ring[i + 1];
      final l = len(a, b);
      if (l <= left) {
        out.add(b);
        left -= l;
      } else {
        final t = left / l;
        out.add([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]);
        left = 0;
      }
    }
    return out.length < 2 ? [ring.first, ring.first] : out;
  }

  static double _signedArea(List<List<double>> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[(i + 1) % p.length];
      a += p[i][0] * q[1] - q[0] * p[i][1];
    }
    return a / 2;
  }
}
