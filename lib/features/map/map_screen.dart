import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

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
import 'build_celebration.dart';
import 'claim_celebration.dart';
import 'income_celebration.dart';
import 'tent_model.dart';
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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
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
  // Adım 2.2: yapılar. Gölge (yarı saydam), sabit çadırlar ve sadece inşa
  // edilen çadırın animasyon katmanı (kare başı maliyet tek çadırlık).
  static const _shadowSource = 'shadow-src';
  static const _shadowLayer = 'shadow-layer';
  static const _tentSource = 'tent-src';
  static const _tentLayer = 'tent-layer';
  static const _buildSource = 'build-src';
  static const _buildLayer = 'build-layer';

  final _hex = HexService();
  late final _tent = TentModel(_hex);

  /// Dokunulan kendi hücrem (inşa kartı açık).
  String? _selected;
  bool _buildBusy = false;
  String? _buildError;

  /// Animasyonu oynayan çadırın hücresi; sabit katmanda çizilmez.
  String? _buildingCell;
  (Offset ground, Offset top)? _buildAnchor;
  List<DustPuff> _puffs = const [];
  late final AnimationController _buildAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: GameConfig.buildAnimMs),
  )..addListener(_onBuildTick);
  bool _buildTickBusy = false;
  final _myCell = HexService(ringSize: 0);
  final _ping = PingRepository();
  final _hexRepo = HexRepository();
  final _wallet = WalletRepository();
  Wallet? _balance;

  /// Adım 2.3: yapıların kasası (sunucudan, periyodik). Toplama animasyonu
  /// sırasında yeni bakiye ilk sikke sayaca varınca uygulanır.
  final _incomeRepo = IncomeRepository();
  Map<String, IncomeSlot> _income = {};
  Timer? _incomeTimer;
  bool _collectBusy = false;
  final _counterKey = GlobalKey();
  final _collectKey = GlobalKey();
  List<FlyCoin> _flyCoins = const [];
  Offset? _collectTarget;
  int _collectTotal = 0;
  int? _collectBalance;
  late final AnimationController _collectAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: GameConfig.collectAnimMs),
  )..addListener(_onCollectTick);

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
    _loadIncome();
    _incomeTimer = Timer.periodic(
      const Duration(seconds: GameConfig.incomePollSec),
      (_) => _loadIncome(),
    );
  }

  /// Kasayı sunucudan okur; hata olursa çip eski haliyle kalır.
  Future<void> _loadIncome() async {
    try {
      final list = await _incomeRepo.load();
      if (mounted) setState(() => _income = {for (final i in list) i.h3: i});
    } catch (_) {}
  }

  int get _pendingTotal => _income.values.fold(0, (a, i) => a + i.pending);

  /// "Topla": sunucu tüm yapıların gelirini verir; sikkeler görünür
  /// yapılardan sayaca uçar. Hareketi azalt açıksa bakiye doğrudan güncellenir.
  Future<void> _collect() async {
    if (_collectBusy || _collectTarget != null) return;
    final chip = _centerOf(_collectKey);
    setState(() => _collectBusy = true);
    try {
      final r = await _incomeRepo.collect();
      if (!mounted) return;
      setState(() {
        _collectBusy = false;
        _income = {
          for (final e in _income.entries)
            e.key: IncomeSlot(
              h3: e.key,
              pending: 0,
              cap: e.value.cap,
              isFull: false,
            ),
        };
      });
      if (r.total > 0) {
        await _playCollect(r, chip);
      } else {
        _setCoins(r.coins);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _collectBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toplanamadı, tekrar dene')),
        );
      }
    }
    _loadIncome();
  }

  void _setCoins(int coins) {
    if (!mounted) return;
    setState(() => _balance = Wallet(coins: coins, gems: _balance?.gems ?? 0));
  }

  /// Bir widget'ın ekran merkezi (sikke hedefi/kaynağı).
  Offset? _centerOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  /// [chip] Topla çipinin konumu; ekranda yapı yoksa sikkeler oradan çıkar.
  Future<void> _playCollect(CollectResult r, Offset? chip) async {
    playCollectFeedback();
    final target = _centerOf(_counterKey);
    if (MediaQuery.of(context).disableAnimations || target == null) {
      _setCoins(r.coins);
      return;
    }
    final screen = MediaQuery.sizeOf(context);
    final sources = <Offset>[];
    for (final cell in r.perCell.keys) {
      if (!_visible.contains(cell)) continue;
      final a = await _screenAnchor(cell);
      if (a != null && (Offset.zero & screen).contains(a.$2)) sources.add(a.$2);
      if (sources.length >= GameConfig.collectCoins) break;
    }
    if (sources.isEmpty) sources.add(chip ?? screen.center(Offset.zero));
    if (!mounted) return;
    setState(() {
      _flyCoins = CollectCelebration.makeCoins(sources);
      _collectTarget = target;
      _collectTotal = r.total;
      _collectBalance = r.coins;
    });
    await _collectAnim.forward(from: 0).orCancel.catchError((_) {});
    final left = _collectBalance;
    if (left != null) _setCoins(left);
    if (mounted) {
      setState(() {
        _collectTarget = null;
        _collectBalance = null;
      });
    }
  }

  /// İlk sikke sayaca varınca bakiye uygulanır: sayaç sayarak sıçrar.
  void _onCollectTick() {
    final b = _collectBalance;
    if (b != null && _collectAnim.value >= CollectCelebration.firstArrival) {
      _collectBalance = null;
      _setCoins(b);
    }
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
    _buildAnim.dispose();
    _collectAnim.dispose();
    _incomeTimer?.cancel();
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

  /// Çadır katmanı özellikleri. Parçaların `b`/`h` değerleri blok tepesine
  /// göredir; [scale] dikey ölçek (squash & stretch). Tüm alanlar birlikte
  /// gönderilir (Altın Kural: null alan varsayılana sıfırlanır).
  FillExtrusionLayerProperties _tentProps(double scale) =>
      FillExtrusionLayerProperties(
        fillExtrusionColor: [Expressions.get, 'color'],
        fillExtrusionOpacity: 1.0,
        fillExtrusionBase: [
          '+',
          GameConfig.hexExtrusionHeight,
          [
            '*',
            ['get', 'b'],
            scale,
          ],
        ],
        fillExtrusionHeight: [
          '+',
          GameConfig.hexExtrusionHeight,
          [
            '*',
            ['get', 'h'],
            scale,
          ],
        ],
        // İnce basamaklarda gradyan şeritlenme yapar; düz renk daha temiz.
        fillExtrusionVerticalGradient: false,
      );

  FillExtrusionLayerProperties get _shadowProps => FillExtrusionLayerProperties(
    fillExtrusionColor: [Expressions.get, 'color'],
    fillExtrusionOpacity: GameConfig.tentShadowOpacity,
    fillExtrusionBase: [
      '+',
      GameConfig.hexExtrusionHeight,
      ['get', 'b'],
    ],
    fillExtrusionHeight: [
      '+',
      GameConfig.hexExtrusionHeight,
      ['get', 'h'],
    ],
    fillExtrusionVerticalGradient: false,
  );

  /// Squash & stretch eğrisi (plan 14.1-C: 0 → %110 → %100). İlk %15'te
  /// çadır yok (zeminde işaret + toz), sonra zıplayarak belirir.
  static double _tentScale(double t) {
    final p = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
    const up = GameConfig.buildStretch;
    const down = GameConfig.buildSquash;
    if (p < 0.45) return up * Curves.easeOutCubic.transform(p / 0.45);
    if (p < 0.7) {
      return up + (down - up) * Curves.easeInOut.transform((p - 0.45) / 0.25);
    }
    return down + (1 - down) * Curves.easeOut.transform((p - 0.7) / 0.3);
  }

  Future<void> _onBuildTick() async {
    final map = _map;
    if (map == null || _buildTickBusy) return;
    _buildTickBusy = true;
    try {
      await map.setLayerProperties(
        _buildLayer,
        _tentProps(_tentScale(_buildAnim.value)),
      );
    } catch (_) {
      // Stil yeniden yüklenirken katman yoksa sessizce geç.
    } finally {
      _buildTickBusy = false;
    }
  }

  /// Haritaya dokunma: dokunulan 3D bloğu/çadırı bulur (eğik kamerada zemin
  /// noktası komşu hücreye düşebilir), yoksa zemin noktasının hücresi.
  /// Kendi hücremse inşa kartı açılır.
  Future<void> _onMapTap(math.Point<double> pt, LatLng ll) async {
    String? cell;
    final map = _map;
    if (map != null && _hexDrawn) {
      try {
        final hits = await map.queryRenderedFeatures(pt, [
          _buildLayer,
          _tentLayer,
          _hex3dLayer,
          _ownedLayer,
        ], null);
        for (final f in hits) {
          final m = f is String ? jsonDecode(f) : f;
          final h = (m as Map)['properties']?['h3'];
          if (h is String) {
            cell = h;
            break;
          }
        }
      } catch (_) {}
    }
    cell ??= _myCell.cellAt(ll.latitude, ll.longitude);
    final o = _owned[cell];
    if (!mounted) return;
    setState(() {
      _selected = (o != null && o.isMine) ? cell : null;
      _buildError = null;
    });
  }

  /// Sunucuya inşa isteği; kabul edilirse bakiye güncellenir ve animasyon
  /// oynar. Ret nedeni kartta gösterilir.
  Future<void> _buildTent(String cell) async {
    if (_buildBusy || _buildingCell != null) return;
    setState(() {
      _buildBusy = true;
      _buildError = null;
    });
    try {
      final coins = await _hexRepo.buildTent(cell);
      final prev = _owned[cell];
      if (prev != null) _owned[cell] = prev.withLevel(1);
      if (!mounted) return;
      setState(() {
        _buildBusy = false;
        _selected = null;
        _balance = Wallet(coins: coins, gems: _balance?.gems ?? 0);
      });
      _playBuild(cell);
      _loadIncome();
    } on BuildException catch (e) {
      if (e.code == 'already_built' || e.code == 'not_owner') {
        _fetchedAt.remove(cell);
        _refreshOwned();
      }
      if (e.code == 'insufficient_funds') _loadBalance();
      if (mounted) {
        setState(() {
          _buildBusy = false;
          _buildError = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _buildBusy = false;
          _buildError = 'Bağlantı yok, tekrar dene';
        });
      }
    }
  }

  /// İnşa anı: kamera çadıra odaklanır, haptik + ses, çadır ayrı katmanda
  /// zıplar, ekranda toz/parıltı/"-100". "Hareketi azalt" açıksa çadır
  /// doğrudan son halinde belirir. Animasyon UI'yı bloklamaz, atlanabilir.
  Future<void> _playBuild(String cell) async {
    final map = _map;
    if (map == null || !_hexDrawn) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    final c = _hex.center(cell);
    final target = LatLng(c[1], c[0]);
    playBuildFeedback();

    if (reduce) {
      await _renderOwned();
      return;
    }

    _buildingCell = cell;
    try {
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(target, GameConfig.buildFocusZoom),
        duration: const Duration(milliseconds: GameConfig.buildFocusMs),
      );
      _buildAnim.value = 0;
      await map.setLayerProperties(_buildLayer, _tentProps(0));
      final o = _owned[cell];
      await map.setGeoJsonSource(
        _buildSource,
        HexService.collection(
          _tent.parts(cell, o == null ? AppColors.ownHex : _ownedColor(o)),
        ),
      );
      await _renderOwned();

      final anchor = await _screenAnchor(cell);
      if (!mounted || anchor == null) return;
      setState(() {
        _puffs = BuildCelebration.makePuffs();
        _buildAnchor = anchor;
      });
      await _buildAnim.forward(from: 0).orCancel.catchError((_) {});
    } catch (_) {
      // Harita/katman hatası: çadır yine sabit katmanda görünür.
    } finally {
      _buildingCell = null;
      if (mounted) setState(() => _buildAnchor = null);
      try {
        await _renderOwned();
        await map.setGeoJsonSource(_buildSource, HexService.collection([]));
      } catch (_) {}
    }
  }

  /// Hücredeki yapının ekran konumu (mantıksal piksel): blok tepesi ve çadır
  /// tepesi. Zemin noktası + yüksekliğin eğik kameradaki izdüşümü (yaklaşık).
  /// Android piksel döner → mantıksal piksele çevrilir.
  Future<(Offset ground, Offset top)?> _screenAnchor(String cell) async {
    final map = _map;
    if (map == null) return null;
    final c = _hex.center(cell);
    final p = await map.toScreenLocation(LatLng(c[1], c[0]));
    if (!mounted) return null;
    final s = Platform.isAndroid ? MediaQuery.devicePixelRatioOf(context) : 1.0;
    final cam = map.cameraPosition;
    final zoom = cam?.zoom ?? GameConfig.buildFocusZoom;
    final tilt = (cam?.tilt ?? GameConfig.mapTilt) * math.pi / 180;
    final mpp =
        40075016.686 *
        math.cos(c[1] * math.pi / 180) /
        (512 * math.pow(2, zoom));
    final up = math.sin(tilt) / mpp;
    final base = Offset(p.x / s, p.y / s);
    final tentTop =
        GameConfig.hexExtrusionHeight +
        GameConfig.tentHeight * _tent.radius(cell);
    return (
      base - Offset(0, GameConfig.hexExtrusionHeight * up),
      base - Offset(0, tentTop * up),
    );
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
    final empty = HexService.collection([]);
    await map.addGeoJsonSource(_shadowSource, empty);
    await map.addFillExtrusionLayer(
      _shadowSource,
      _shadowLayer,
      _shadowProps,
      minzoom: GameConfig.structureMinZoom,
    );
    await map.addGeoJsonSource(_tentSource, empty);
    await map.addFillExtrusionLayer(
      _tentSource,
      _tentLayer,
      _tentProps(1),
      minzoom: GameConfig.structureMinZoom,
    );
    await map.addGeoJsonSource(_buildSource, empty);
    await map.addFillExtrusionLayer(
      _buildSource,
      _buildLayer,
      _tentProps(_tentScale(_buildAnim.value)),
      minzoom: GameConfig.structureMinZoom,
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
    final shadows = <Map<String, dynamic>>[];
    final tents = <Map<String, dynamic>>[];
    for (final h in _owned.values) {
      if (h.level < 1 || !_visible.contains(h.h3)) continue;
      shadows.addAll(_tent.shadow(h.h3));
      if (h.h3 != _buildingCell) {
        tents.addAll(_tent.parts(h.h3, _ownedColor(h)));
      }
    }
    await map.setGeoJsonSource(_shadowSource, HexService.collection(shadows));
    await map.setGeoJsonSource(_tentSource, HexService.collection(tents));
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
      WalkState.starting => (
        'Başlatılıyor…',
        Icons.hourglass_top_rounded,
        null,
      ),
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

  /// Kendi hücreme dokununca alttan çıkan kart: yapı yoksa "Çadır kur",
  /// varsa yapı bilgisi. Fiyat gösterim içindir; kararı sunucu verir.
  String _incomeLine(String cell, int level) {
    final i = _income[cell];
    if (i == null) return 'Seviye $level • Bu bölge senin';
    return 'Seviye $level • Kasa ${i.pending} / ${i.cap}'
        '${i.isFull ? ' • Dolu!' : ''}';
  }

  Widget _buildCard(String cell) {
    final text = Theme.of(context).textTheme;
    final level = _owned[cell]?.level ?? 0;
    final coins = _balance?.coins;
    final canAfford = coins == null || coins >= GameConfig.tentCost;
    final err = _buildError;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level >= 1 ? '⛺ Çadır' : 'Bölgene çadır kur',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                level >= 1
                    ? _incomeLine(cell, level)
                    : 'İlk yapın bölgeni süsler.',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(
                  err,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _selected = null),
                    child: Text(level >= 1 ? 'Kapat' : 'Vazgeç'),
                  ),
                  if (level < 1) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: AppTheme.goldButton,
                      onPressed: _buildBusy || !canAfford
                          ? null
                          : () => _buildTent(cell),
                      icon: _buildBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.monetization_on_rounded),
                      label: Text(
                        canAfford
                            ? 'Kur • ${GameConfig.tentCost}'
                            : '${GameConfig.tentCost} altın gerekli',
                      ),
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

  /// "Topla • X" çipi; bir kasa doluysa şeftaliyle vurgulanır.
  Widget _collectChip() {
    final full = _income.values.any((i) => i.isFull);
    return ElevatedButton.icon(
      key: _collectKey,
      style: AppTheme.goldButton.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          full ? AppColors.accentPeach : AppColors.accentButter,
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      ),
      onPressed: _collectBusy ? null : _collect,
      icon: _collectBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.savings_rounded, size: 18),
      label: Text(
        full ? 'Kasa dolu! Topla • $_pendingTotal' : 'Topla • $_pendingTotal',
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
              trackCameraPosition: true,
              onMapClick: _onMapTap,
              onMapCreated: (c) {
                _map = c;
                // Etkileşimli katmandaki bir parçaya (blok/çadır) dokunulunca
                // eklenti onMapClick yerine bunu çağırır.
                c.onFeatureTapped.add(
                  (pt, ll, id, layerId, annotation) => _onMapTap(pt, ll),
                );
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
          if (ready && _selected == null) _walkPanel(),
          if (_selected != null) _buildCard(_selected!),
          if (_buildAnchor != null)
            BuildCelebration(
              progress: _buildAnim,
              ground: _buildAnchor!.$1,
              top: _buildAnchor!.$2,
              cost: GameConfig.tentCost,
              puffs: _puffs,
              onSkip: () => _buildAnim.animateTo(
                1,
                duration: const Duration(milliseconds: 80),
              ),
            ),
          if (_balance != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CoinCounter(
                        key: _counterKey,
                        coins: _balance!.coins,
                        reduceMotion: MediaQuery.of(context).disableAnimations,
                      ),
                      if (_pendingTotal > 0 || _collectBusy) ...[
                        const SizedBox(height: 6),
                        _collectChip(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_collectTarget != null)
            CollectCelebration(
              progress: _collectAnim,
              coins: _flyCoins,
              target: _collectTarget!,
              total: _collectTotal,
              onSkip: () => _collectAnim.animateTo(
                1,
                duration: const Duration(milliseconds: 80),
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

/// Altın sayacı (sol üst): tereyağı sarısı kart. Değer değişince sayarak
/// gider ve hafifçe sıçrar (plan 14.1-C "kasa" hissi).
class _CoinCounter extends StatelessWidget {
  const _CoinCounter({
    super.key,
    required this.coins,
    required this.reduceMotion,
  });

  final int coins;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    );
    final ms = reduceMotion ? 0 : 600;
    return TweenAnimationBuilder<double>(
      key: ValueKey(coins),
      tween: Tween(begin: reduceMotion ? 1 : 1.18, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(
          color: AppColors.accentButter,
          borderRadius: BorderRadius.circular(AppRadii.card),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded, color: AppColors.text),
            const SizedBox(width: 6),
            _CountUp(value: coins, ms: ms, style: style),
          ],
        ),
      ),
    );
  }
}

/// Sayıyı önceki değerden yenisine sayarak gösterir.
class _CountUp extends StatefulWidget {
  const _CountUp({required this.value, required this.ms, this.style});
  final int value;
  final int ms;
  final TextStyle? style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  late int _from = widget.value;

  @override
  void didUpdateWidget(_CountUp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(widget.value),
    tween: Tween(begin: _from.toDouble(), end: widget.value.toDouble()),
    duration: Duration(milliseconds: widget.ms),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('${v.round()}', style: widget.style),
  );
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
