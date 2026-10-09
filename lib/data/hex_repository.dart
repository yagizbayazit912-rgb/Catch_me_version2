import 'package:supabase_flutter/supabase_flutter.dart';

/// Sahipli bir altıgen. Sahibin kimliği/koordinatı gelmez; sadece benim mi
/// ve renk seçmek için bir tohum.
class OwnedHex {
  const OwnedHex({
    required this.h3,
    required this.isMine,
    required this.colorSeed,
    this.level = 0,
  });

  final String h3;
  final bool isMine;
  final int colorSeed;

  /// Yapı seviyesi: 0 = yok, 1 çadır, 2 ev, 3 otel, 4 gökdelen.
  final int level;

  OwnedHex withLevel(int l) =>
      OwnedHex(h3: h3, isMine: isMine, colorSeed: colorSeed, level: l);

  factory OwnedHex.fromJson(Map<String, dynamic> j) => OwnedHex(
    h3: j['h3_index'] as String,
    isMine: j['is_mine'] == true,
    colorSeed: (j['color_seed'] as num?)?.toInt() ?? 0,
    level: (j['level'] as num?)?.toInt() ?? 0,
  );
}

/// İnşa reddi; [code] sunucunun hata kodu.
class BuildException implements Exception {
  const BuildException(this.code);
  final String code;

  String get message => switch (code) {
    'insufficient_funds' => 'Yeterli altının yok',
    'already_built' || 'max_level' => 'Bu yapı en üst seviyede',
    'not_owner' => 'Bu bölge senin değil',
    _ => 'İnşa edilemedi, tekrar dene',
  };
}

/// Sahiplik okuma (`owned_hexes_in` RPC). Karar sunucuda; burada sadece okunur.
class HexRepository {
  HexRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Verilen hücrelerden sahipli olanları döner.
  Future<List<OwnedHex>> ownedIn(List<String> cells) async {
    if (cells.isEmpty) return const [];
    final rows = await _client.rpc(
      'owned_hexes_in',
      params: {'p_cells': cells},
    );
    return [
      for (final r in rows as List)
        OwnedHex.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Kendi hücremde bir sonraki seviyeyi kurar (0→çadır, 1→ev, ...)
  /// (`build_structure` RPC). Karar, ödeme ve eski kasanın toplanması
  /// sunucuda.
  Future<BuildResult> build(String h3) async {
    try {
      final res = await _client.rpc('build_structure', params: {'p_h3': h3});
      final m = res as Map;
      return BuildResult(
        level: (m['level'] as num).toInt(),
        coins: (m['coins'] as num).toInt(),
        cost: (m['cost'] as num).toInt(),
        collected: (m['collected'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (e) {
      const known = {
        'insufficient_funds',
        'already_built',
        'max_level',
        'not_owner',
      };
      throw BuildException(known.contains(e.message) ? e.message : 'unknown');
    }
  }
}

/// İnşa/yükseltme sonucu: yeni seviye, bakiye, ödenen ve yükseltmede
/// otomatik toplanan eski kasa.
class BuildResult {
  const BuildResult({
    required this.level,
    required this.coins,
    required this.cost,
    required this.collected,
  });

  final int level;
  final int coins;
  final int cost;
  final int collected;
}
