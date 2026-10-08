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

  /// Yapı seviyesi: 0 = yok, 1 = çadır (2.4'te ev/otel/gökdelen).
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
    'already_built' => 'Burada zaten bir yapı var',
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

  /// Kendi hücreme çadır kurar (`build_structure` RPC). Karar ve ödeme
  /// sunucuda; dönen yeni altın bakiyesi.
  Future<int> buildTent(String h3) async {
    try {
      final res = await _client.rpc('build_structure', params: {'p_h3': h3});
      return ((res as Map)['coins'] as num).toInt();
    } on PostgrestException catch (e) {
      const known = {'insufficient_funds', 'already_built', 'not_owner'};
      throw BuildException(known.contains(e.message) ? e.message : 'unknown');
    }
  }
}
