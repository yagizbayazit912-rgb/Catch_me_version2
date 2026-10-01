import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/config/game_config.dart';
import '../../core/hex/hex_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Ana harita ekranı: pastel MapLibre stili + ön plan konum izni.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _LocState { loading, ready, denied, deniedForever, serviceOff }

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const _styleAsset = 'assets/map/pastel_style.json';
  static const _defaultZoom = 16.0;

  static const _hexSource = 'hex-src';
  static const _hexFill = 'hex-fill';
  static const _hexLine = 'hex-line';
  // Adım 0.5 deneme: kullanıcının hücresi 3D blok olarak yükselir.
  static const _hex3dSource = 'hex3d-src';
  static const _hex3dLayer = 'hex3d-layer';

  final _hex = HexService();
  final _myCell = HexService(ringSize: 0);
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: GameConfig.hexRiseMs),
  )..addListener(_onRiseTick);
  bool _riseBusy = false;
  int _riseUpdates = 0;
  double? _riseUpdatesPerSec;
  MapLibreMapController? _map;
  bool _hexDrawn = false;
  String? _style;
  Position? _position;
  _LocState _state = _LocState.loading;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString(_styleAsset).then((s) {
      if (mounted) setState(() => _style = s);
    });
    _resolveLocation();
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  /// Her karede yüksekliği native katmana yollar; önceki çağrı bitmeden
  /// yenisini atmaz (kanal tıkanmasın). Kaç güncelleme gittiği ölçülür.
  Future<void> _onRiseTick() async {
    final map = _map;
    if (map == null || _riseBusy) return;
    _riseBusy = true;
    final t = Curves.elasticOut.transform(_rise.value);
    try {
      await map.setLayerProperties(
        _hex3dLayer,
        FillExtrusionLayerProperties(
          fillExtrusionHeight: GameConfig.hexExtrusionHeight * t,
        ),
      );
      _riseUpdates++;
    } catch (_) {
      // Stil yeniden yüklenirken katman yoksa sessizce geç.
    } finally {
      _riseBusy = false;
    }
  }

  /// Yükselme animasyonunu oynatır. "Hareketi azalt" açıksa anında son hal.
  Future<void> _playRise() async {
    if (!_hexDrawn) return;
    if (MediaQuery.of(context).disableAnimations) {
      _rise.value = 1;
      return;
    }
    _riseUpdates = 0;
    final sw = Stopwatch()..start();
    await _rise.forward(from: 0).orCancel.catchError((_) {});
    sw.stop();
    if (mounted) {
      setState(() => _riseUpdatesPerSec =
          _riseUpdates * 1000 / sw.elapsedMilliseconds.clamp(1, 1 << 30));
    }
  }

  /// Sadece ön plan izni ister (arka plan konumu bu adımda yok).
  Future<void> _resolveLocation() async {
    setState(() => _state = _LocState.loading);
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _set(_LocState.serviceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return _set(_LocState.deniedForever);
    }
    if (perm == LocationPermission.denied) return _set(_LocState.denied);

    try {
      final pos = await Geolocator.getCurrentPosition();
      _position = pos;
      _set(_LocState.ready);
      _flyToUser();
    } catch (_) {
      _set(_LocState.serviceOff);
    }
  }

  void _set(_LocState s) {
    if (mounted) setState(() => _state = s);
  }

  String _hexColor(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// Konum etrafındaki altıgenleri düz (fill + çizgi) çizer.
  Future<void> _drawHexes() async {
    final p = _position;
    final map = _map;
    if (p == null || map == null) return;
    final data = _hex.hexagonsAround(p.latitude, p.longitude);
    final mine = _myCell.hexagonsAround(p.latitude, p.longitude);
    if (_hexDrawn) {
      await map.setGeoJsonSource(_hexSource, data);
      await map.setGeoJsonSource(_hex3dSource, mine);
      return;
    }
    _hexDrawn = true;
    await map.addGeoJsonSource(_hexSource, data);
    await map.addFillLayer(
      _hexSource,
      _hexFill,
      FillLayerProperties(
        fillColor: _hexColor(AppColors.secondary),
        fillOpacity: 0.18,
      ),
    );
    await map.addLineLayer(
      _hexSource,
      _hexLine,
      LineLayerProperties(
        lineColor: _hexColor(AppColors.secondary),
        lineWidth: 1.5,
        lineOpacity: 0.8,
      ),
    );
    await map.addGeoJsonSource(_hex3dSource, mine);
    await map.addFillExtrusionLayer(
      _hex3dSource,
      _hex3dLayer,
      FillExtrusionLayerProperties(
        // Düz "#hex" metni Android'de extrusion için renge çevrilmiyor
        // (siyah çıkıyor) → açık rgb ifadesi gönderilir.
        fillExtrusionColor: [
          'rgb',
          (AppColors.primary.r * 255).round(),
          (AppColors.primary.g * 255).round(),
          (AppColors.primary.b * 255).round(),
        ],
        fillExtrusionOpacity: 0.9,
        fillExtrusionHeight: 0.0,
        fillExtrusionBase: 0.0,
        fillExtrusionVerticalGradient: true,
      ),
    );
    _playRise();
  }

  void _flyToUser() {
    final p = _position;
    if (p == null || _map == null) return;
    _drawHexes();
    _map!.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(p.latitude, p.longitude),
        zoom: _defaultZoom,
        tilt: GameConfig.mapTilt,
      )),
    );
  }

  /// Adım 0.5 deneme paneli: animasyonu tekrar oynatır, ölçümü gösterir.
  Widget _riseTestChip() {
    final rate = _riseUpdatesPerSec;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ActionChip(
            backgroundColor: AppColors.surface,
            avatar: const Icon(Icons.view_in_ar_rounded, color: AppColors.text),
            label: Text(rate == null
                ? '3D yükselt'
                : '3D tekrar • ${rate.toStringAsFixed(0)} güncelleme/sn'),
            onPressed: _playRise,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _state == _LocState.ready;
    return Scaffold(
      body: Stack(
        children: [
          if (_style != null)
            MapLibreMap(
              styleString: _style!,
              initialCameraPosition: CameraPosition(
                target: _position == null
                    ? const LatLng(41.0082, 28.9784)
                    : LatLng(_position!.latitude, _position!.longitude),
                zoom: _position == null ? 11 : _defaultZoom,
                tilt: GameConfig.mapTilt,
              ),
              myLocationEnabled: ready,
              myLocationRenderMode: MyLocationRenderMode.normal,
              compassEnabled: false,
              onMapCreated: (c) {
                _map = c;
                _flyToUser();
              },
              onStyleLoadedCallback: () {
                _hexDrawn = false;
                _drawHexes();
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (ready) _riseTestChip(),
          if (_state != _LocState.ready && _state != _LocState.loading)
            _PermissionCard(state: _state, onRetry: _resolveLocation),
        ],
      ),
      floatingActionButton: ready
          ? FloatingActionButton(
              onPressed: _flyToUser,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.text,
              tooltip: 'Konumuma git',
              child: const Icon(Icons.my_location_rounded),
            )
          : null,
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.state, required this.onRetry});
  final _LocState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, body, action, onTap) = switch (state) {
      _LocState.deniedForever => (
          'Konum izni kapalı',
          'Haritada seni görebilmemiz için ayarlardan konum iznini aç.',
          'Ayarlara git',
          Geolocator.openAppSettings,
        ),
      _LocState.serviceOff => (
          'Konum servisi kapalı',
          'Telefonunun konumunu açıp tekrar dene.',
          'Konum ayarları',
          Geolocator.openLocationSettings,
        ),
      _ => (
          'Konum izni gerekli',
          'Bölgeleri keşfetmek için uygulama açıkken konumunu kullanırız.',
          'İzin ver',
          () async => onRetry(),
        ),
    };
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: AppTheme.confirmButton,
                    onPressed: () => onTap(),
                    child: Text(action),
                  ),
                  if (state == _LocState.deniedForever ||
                      state == _LocState.serviceOff) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                        onPressed: onRetry, child: const Text('Tekrar dene')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
