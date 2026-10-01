import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `location-ping` edge function'ının cevabı. Karar sunucuda; burada sadece okunur.
class PingResult {
  const PingResult({
    required this.ok,
    this.h3,
    this.reason,
    this.speedMps,
    this.countsForPresence,
  });

  final bool ok;
  final String? h3;
  final String? reason;
  final double? speedMps;
  final bool? countsForPresence;

  factory PingResult.fromJson(Map<String, dynamic> j) => PingResult(
    ok: j['ok'] == true,
    h3: j['h3'] as String?,
    reason: j['reason'] as String?,
    speedMps: (j['speed_mps'] as num?)?.toDouble(),
    countsForPresence: j['counts_for_presence'] as bool?,
  );
}

/// Konumu sunucuya yollar. Sunucu doğrular, h3 hesaplar, filtreler.
class PingRepository {
  PingRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PingResult> send(Position p) async {
    final res = await _client.functions.invoke(
      'location-ping',
      body: {
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
        'is_mock': p.isMocked,
        'client_ts': p.timestamp.millisecondsSinceEpoch,
      },
    );
    return PingResult.fromJson(res.data as Map<String, dynamic>);
  }
}
