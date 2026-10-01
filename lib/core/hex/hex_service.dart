import 'package:h3_flutter_plus/h3_flutter_plus.dart' as h3lib;

import '../config/game_config.dart';

/// H3 işlemleri. Çözünürlük [GameConfig]'ten okunur.
class HexService {
  HexService({int? resolution, int? ringSize})
    : resolution = resolution ?? GameConfig.h3Resolution,
      ringSize = ringSize ?? GameConfig.hexRingSize;

  final int resolution;
  final int ringSize;
  final h3lib.H3 _h3 = const h3lib.H3Factory().load();

  /// Konumun hücre indeksi (string olarak saklanır).
  String cellAt(double lat, double lng) => _h3
      .latLngToCell(h3lib.LatLng(lat: lat, lng: lng), resolution)
      .toRadixString(16);

  /// Konum etrafındaki altıgenleri GeoJSON FeatureCollection olarak döner.
  Map<String, dynamic> hexagonsAround(double lat, double lng) {
    final center = _h3.latLngToCell(
      h3lib.LatLng(lat: lat, lng: lng),
      resolution,
    );
    final features = <Map<String, dynamic>>[];
    for (final cell in _h3.gridDisk(center, ringSize)) {
      final ring = [
        for (final p in _h3.cellToBoundary(cell)) [p.lng, p.lat],
      ];
      ring.add(ring.first);
      features.add({
        'type': 'Feature',
        'properties': {'h3': cell.toRadixString(16)},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
  }
}
