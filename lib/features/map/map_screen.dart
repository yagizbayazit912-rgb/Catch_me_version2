import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/config/game_config.dart';
import '../../core/hex/hex_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/hex_repository.dart';
import '../../data/ping_repository.dart';
import '../../data/wallet_repository.dart';
import 'claim_celebration.dart';
import 'walk_controller.dart';

/// Ana harita ekranı: pastel MapLibre stili + ön plan konum izni.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.onSignOut});

  /// Geçici çıkış butonu (Adım 0.6); profil ekranı gelince oraya taşınacak.
  final VoidCallback? onSignOut;

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
  // Adım 1.4: görünür alandaki sahipli altıgenler (sabit yükseklikte bloklar).
  static const _ownedSource = 'owned-src';
  static const _ownedLayer = 'owned-layer';
  // Sadece son claim edilen hücre; yükselme animasyonu bu katmanda oynar,
  // böylece kare başı güncelleme sahipli altıgen sayısından bağımsızdır.
  static const _hex3dSource = 'hex3d-src';
  static const _hex3dLayer = 'hex3d-layer';

  final _hex = HexService();
  final _myCell = HexService(ringSize: 0);
  final _ping = PingRepository();
  final _hexRepo = HexRepository();
  final _wallet = WalletRepository();
  Wallet? _balance;

  /// Sahiplik önbelleği: sorulan her hücrenin zamanı, sahipliler ayrı.
  final _owned = <String, OwnedHex>{};
  final _fetchedAt = <String, DateTime>{};
  Set<String> _visible = {};
  String? _risingCell;
  bool _ownedBusy = false;
  bool _ownedAgain = false;
  late final WalkController _walk = WalkController(_ping, onPing: _onWalkPing)
    ..addListener(() {
      if (mounted) setState(() {});
    });
  bool _celebrating = false;
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
    _loadBalance();
  }

  /// Bakiyeyi sunucudan okur; hata olursa sayaç gizli kalır.
  Future<void> _loadBalance() async {
    try {
      final w = await _wallet.load();
      if (mounted) setState(() => _balance = w);
    } catch (_) {}
  }

  @override
  void dispose() {
    _walk.dispose();
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
        _hex3dProps(GameConfig.hexExtrusionHeight * t),
      );
      _riseUpdates++;
    } catch (_) {
      // Stil yeniden yüklenirken katman yoksa sessizce geç.
    } finally {
      _riseBusy = false;
    }
  }

  /// 3D altıgen katmanının tüm özellikleri. `setLayerProperties` null
  /// alanları varsayılana sıfırladığı için (renk → siyah) her güncellemede
  /// hepsi birlikte gönderilir.
  FillExtrusionLayerProperties _hex3dProps(double height) =>
      FillExtrusionLayerProperties(
        fillExtrusionColor: _hexColor(AppColors.ownHex),
        fillExtrusionOpacity: 0.9,
        fillExtrusionHeight: height,
        fillExtrusionBase: 0.0,
        fillExtrusionVerticalGradient: true,
      );

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
      setState(
        () => _riseUpdatesPerSec =
            _riseUpdates * 1000 / sw.elapsedMilliseconds.clamp(1, 1 << 30),
      );
    }
  }

  /// Adım 1.3: claim anı. Haptik + ses, blok yükselmesi ve kutlama overlay'i.
  /// Hiçbiri UI'yı beklemez; tekrar tetiklenirse kutlama baştan başlar.
  /// [h3] sunucunun verdiği yeni sahipli hücre (Adım 1.4: önbelleğe eklenir);
  /// test çipinde null → bulunduğum hücre sadece animasyon için yükselir.
  Future<void> _celebrateClaim([String? h3]) async {
    playClaimFeedback();
    final p = _position;
    final cell =
        h3 ?? (p == null ? null : _myCell.cellAt(p.latitude, p.longitude));
    if (h3 != null) {
      _owned[h3] = OwnedHex(h3: h3, isMine: true, colorSeed: 0);
      _fetchedAt[h3] = DateTime.now();
    }
    _rise.value = 0;
    _risingCell = cell;
    final map = _map;
    if (map != null && _hexDrawn && cell != null) {
      try {
        await map.setGeoJsonSource(
          _hex3dSource,
          HexService.collection([_hex.feature(cell)]),
        );
        await _renderOwned();
      } catch (_) {}
    }
    if (!mounted) return;
    _playRise();
    setState(() => _celebrating = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _celebrating = true);
    });
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
    if (_hexDrawn) {
      await map.setGeoJsonSource(_hexSource, data);
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
    await map.addGeoJsonSource(_ownedSource, _ownedCollection());
    await map.addFillExtrusionLayer(
      _ownedSource,
      _ownedLayer,
      FillExtrusionLayerProperties(
        fillExtrusionColor: [Expressions.get, 'color'],
        fillExtrusionOpacity: 0.9,
        fillExtrusionHeight: GameConfig.hexExtrusionHeight,
        fillExtrusionBase: 0.0,
        fillExtrusionVerticalGradient: true,
      ),
    );
    final rising = _risingCell;
    await map.addGeoJsonSource(
      _hex3dSource,
      HexService.collection([if (rising != null) _hex.feature(rising)]),
    );
    await map.addFillExtrusionLayer(
      _hex3dSource,
      _hex3dLayer,
      _hex3dProps(
        GameConfig.hexExtrusionHeight *
            Curves.elasticOut.transform(_rise.value),
      ),
    );
    _refreshOwned();
  }

  /// Görünür + sahipli hücreler (yükselen hücre hariç, üst üste binmesin).
  Map<String, dynamic> _ownedCollection() => HexService.collection([
    for (final h in _owned.values)
      if (_visible.contains(h.h3) && h.h3 != _risingCell)
        _hex.feature(h.h3, {'color': _hexColor(_ownedColor(h))}),
  ]);

  Color _ownedColor(OwnedHex h) {
    if (h.isMine) return AppColors.ownHex;
    const p = AppColors.otherPlayerPalette;
    return p[h.colorSeed % p.length];
  }

  Future<void> _renderOwned() async {
    final map = _map;
    if (map == null || !_hexDrawn) return;
    await map.setGeoJsonSource(_ownedSource, _ownedCollection());
  }

  /// Kamera durunca: görünür hücreleri hesapla, önbellekte olmayan veya
  /// eskiyenleri sunucuya sor, sonra sadece görünenleri çiz. Çok uzak
  /// zoom'da (hücre sayısı sınırı aşınca) sahiplik çizilmez.
  Future<void> _refreshOwned() async {
    final map = _map;
    if (map == null || !_hexDrawn) return;
    if (_ownedBusy) {
      _ownedAgain = true;
      return;
    }
    _ownedBusy = true;
    try {
      final b = await map.getVisibleRegion();
      final padLat =
          (b.northeast.latitude - b.southwest.latitude) *
          GameConfig.visibleBoundsPadding;
      final padLng =
          (b.northeast.longitude - b.southwest.longitude) *
          GameConfig.visibleBoundsPadding;
      final cells = _hex.cellsInBounds(
        b.southwest.latitude - padLat,
        b.southwest.longitude - padLng,
        b.northeast.latitude + padLat,
        b.northeast.longitude + padLng,
      );
      if (cells.length > GameConfig.maxVisibleHexes) {
        _visible = {};
      } else {
        _visible = cells.toSet();
        final now = DateTime.now();
        final stale = [
          for (final c in cells)
            if (now.difference(_fetchedAt[c] ?? DateTime(0)).inSeconds >=
                GameConfig.ownedCacheTtlSec)
              c,
        ];
        if (stale.isNotEmpty) {
          final rows = await _hexRepo.ownedIn(stale);
          for (final c in stale) {
            _owned.remove(c);
            _fetchedAt[c] = now;
          }
          for (final r in rows) {
            _owned[r.h3] = r;
          }
        }
      }
      await _renderOwned();
    } catch (_) {
      // Ağ/katman hatası: bir sonraki kamera hareketinde tekrar denenir.
    } finally {
      _ownedBusy = false;
      if (_ownedAgain && mounted) {
        _ownedAgain = false;
        _refreshOwned();
      }
    }
  }

  void _flyToUser() {
    final p = _position;
    if (p == null || _map == null) return;
    _drawHexes();
    _map!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(p.latitude, p.longitude),
          zoom: _defaultZoom,
          tilt: GameConfig.mapTilt,
        ),
      ),
    );
  }

  /// Yürüyüş modundan gelen her sunucu cevabı: claim olduysa kutlama.
  void _onWalkPing(PingResult res) {
    if (mounted && res.ok && res.claimed) _celebrateClaim(res.h3);
  }

  /// Yürüyüş modu başlat/durdur butonu + durum göstergesi (açık/duraklı/kapalı).
  Widget _walkPanel() {
    final s = _walk.state;
    final (label, icon, color) = switch (s) {
      WalkState.off => ('Yürüyüşe başla', Icons.directions_walk_rounded, null),
      WalkState.starting => ('Başlatılıyor…', Icons.hourglass_top_rounded, null),
      WalkState.active => (
        'Yürüyüş açık • durdur',
        Icons.stop_circle_rounded,
        AppColors.ownHex,
      ),
      WalkState.pausedFast => (
        'Duraklatıldı (hızlısın) • durdur',
        Icons.pause_circle_rounded,
        AppColors.secondary,
      ),
    };
    final note = _walk.status;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (note != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Text(note),
                ),
              ElevatedButton.icon(
                style: AppTheme.confirmButton,
                onPressed: s == WalkState.starting
                    ? null
                    : (_walk.running ? _walk.stop : _walk.start),
                icon: Icon(icon, color: color),
                label: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Geçici deneme paneli: 3D animasyonu tekrar oynatır (0.5).
  Widget _riseTestChip() {
    final rate = _riseUpdatesPerSec;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionChip(
                backgroundColor: AppColors.surface,
                avatar: const Icon(
                  Icons.view_in_ar_rounded,
                  color: AppColors.text,
                ),
                label: Text(
                  rate == null
                      ? '3D yükselt'
                      : '3D tekrar • ${rate.toStringAsFixed(0)} güncelleme/sn',
                ),
                onPressed: _playRise,
              ),
            ],
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
              onCameraIdle: _refreshOwned,
              onStyleLoadedCallback: () {
                _hexDrawn = false;
                _drawHexes();
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (ready) _riseTestChip(),
          if (ready) _walkPanel(),
          if (_balance != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Chip(
                    backgroundColor: AppColors.surface,
                    avatar: const Icon(
                      Icons.monetization_on_rounded,
                      color: AppColors.text,
                    ),
                    label: Text('${_balance!.coins}'),
                  ),
                ),
              ),
            ),
          if (_celebrating)
            ClaimCelebration(
              reduceMotion: MediaQuery.of(context).disableAnimations,
              onDone: () => setState(() => _celebrating = false),
            ),
          if (widget.onSignOut != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filledTonal(
                    tooltip: 'Çıkış yap',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ),
              ),
            ),
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
              Text(
                title,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
                      onPressed: onRetry,
                      child: const Text('Tekrar dene'),
                    ),
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
