import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/game_config.dart';
import '../../data/ping_repository.dart';

enum WalkState { off, starting, active, pausedFast }

/// Adım 1.6: yürüyüş modu. Foreground service (kalıcı bildirim) ile konum
/// akışını açık tutar, ekran kapalıyken de ping atar. Hız eşiğin üstündeyse
/// ping atmadan duraklar. Karar yine sunucuda; burası sadece konumu iletir.
class WalkController extends ChangeNotifier {
  WalkController(this._ping, {this.onPing});

  final PingRepository _ping;

  /// Kabul/ret fark etmez, her sunucu cevabında çağrılır (claim kutlaması için).
  final void Function(PingResult result)? onPing;

  WalkState _state = WalkState.off;
  String? _status;
  StreamSubscription<Position>? _sub;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sending = false;
  int _fastStreak = 0;
  int _slowStreak = 0;
  Position? _best;

  WalkState get state => _state;
  bool get running =>
      _state == WalkState.active || _state == WalkState.pausedFast;

  /// Oyuncuya gösterilecek kısa durum satırı.
  String? get status => _status;

  void _set(WalkState s, [String? status]) {
    _state = s;
    _status = status;
    notifyListeners();
  }

  /// Başlatır. Bildirim izni reddedilirse de takip başlar (bildirim görünmez
  /// olabilir; durum satırı uyarır).
  Future<void> start() async {
    if (_state != WalkState.off) return;
    _set(WalkState.starting);

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return _set(WalkState.off, 'Konum izni gerekli');
    }
    final notif = await Permission.notification.request();

    _fastStreak = 0;
    _slowStreak = 0;
    _best = null;
    _sub =Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: GameConfig.walkDistanceFilterM,
        intervalDuration: const Duration(
          seconds: GameConfig.walkFixIntervalSec,
        ),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: GameConfig.walkNotificationTitle,
          notificationText: GameConfig.walkNotificationText,
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen(_onPosition, onError: (_) => stop('Konum akışı kesildi'));
    _set(
      WalkState.active,
      notif.isGranted ? null : 'Bildirim izni kapalı: bildirim görünmeyebilir',
    );
  }

  Future<void> stop([String? reason]) async {
    await _sub?.cancel();
    _sub = null;
    _set(WalkState.off, reason);
  }

  Future<void> _onPosition(Position p) async {
    // Hız çok sıçramasın diye ardışık okumayla geçiş (histerezis).
    final fast = p.speed > GameConfig.walkMaxSpeedMps;
    if (fast) {
      _fastStreak++;
      _slowStreak = 0;
    } else {
      _slowStreak++;
      _fastStreak = 0;
    }
    if (_state == WalkState.active &&
        _fastStreak >= GameConfig.walkSpeedStreak) {
      _set(WalkState.pausedFast, 'Hızlısın, yürüyüş duraklatıldı');
    } else if (_state == WalkState.pausedFast &&
        _slowStreak >= GameConfig.walkSpeedStreak) {
      _set(WalkState.active);
    }
    if (_state != WalkState.active) return;

    // Penceredeki en iyi okumayı tut. Yeni okuma biraz kötü olsa da tercih
    // edilir (yürürken eski konum yanlış altıgende kalabilir).
    if (p.accuracy <= GameConfig.walkMaxSendAccuracyM &&
        (_best == null || p.accuracy <= _best!.accuracy * 1.2)) {
      _best = p;
    }

    final now = DateTime.now();
    if (_sending ||
        now.difference(_lastSent).inSeconds < GameConfig.walkPingIntervalSec) {
      return;
    }
    final best = _best;
    if (best == null ||
        now.difference(best.timestamp).inSeconds >
            GameConfig.walkMaxFixAgeSec) {
      // Zayıf sinyalde gönderme (ret yerine bekle); iyi okuma gelince
      // pencere beklenmeden hemen gönderilir.
      _best = null;
      final msg = 'GPS sinyali zayıf (±${p.accuracy.round()} m), bekleniyor';
      if (_status != msg) {
        _status = msg;
        notifyListeners();
      }
      return;
    }
    _best = null;
    _sending = true;
    _lastSent = now;
    try {
      final res = await _ping.send(best);
      if (!res.ok) {
        _status = 'Reddedildi: ${res.reasonText}';
        notifyListeners();
      } else if (_status != null && _state == WalkState.active) {
        _status = null;
        notifyListeners();
      }
      onPing?.call(res);
    } catch (_) {
      // Ağ yok: bir sonraki konumda tekrar denenir.
      _status = 'Bağlantı yok, yeniden denenecek';
      notifyListeners();
    } finally {
      _sending = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
