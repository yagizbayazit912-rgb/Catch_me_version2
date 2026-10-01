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
    return collection([
      for (final cell in _h3.gridDisk(center, ringSize))
        feature(cell.toRadixString(16)),
    ]);
  }

  /// Dikdörtgen alanın (görünür bölge) içindeki hücreler.
  List<String> cellsInBounds(
    double south,
    double west,
    double north,
    double east,
  ) => [
    for (final c in _h3.polygonToCells(
      coordinates: [
        h3lib.LatLng(lat: south, lng: west),
        h3lib.LatLng(lat: south, lng: east),
        h3lib.LatLng(lat: north, lng: east),
        h3lib.LatLng(lat: north, lng: west),
      ],
      resolution: resolution,
    ))
      c.toRadixString(16),
  ];

  /// Tek hücrenin GeoJSON Feature'ı; [props] çizim için ek alanlar.
  Map<String, dynamic> feature(String h3, [Map<String, dynamic>? props]) {
    final ring = [
      for (final p in _h3.cellToBoundary(BigInt.parse(h3, radix: 16)))
        [p.lng, p.lat],
    ];
    ring.add(ring.first);
    return {
      'type': 'Feature',
      'properties': {'h3': h3, ...?props},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [ring],
      },
    };
  }

  static Map<String, dynamic> collection(List<Map<String, dynamic>> features) =>
      {'type': 'FeatureCollection', 'features': features};
}
