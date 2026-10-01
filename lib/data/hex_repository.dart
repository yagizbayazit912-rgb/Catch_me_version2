import 'package:supabase_flutter/supabase_flutter.dart';

/// Sahipli bir altıgen. Sahibin kimliği/koordinatı gelmez; sadece benim mi
/// ve renk seçmek için bir tohum.
class OwnedHex {
  const OwnedHex({
    required this.h3,
    required this.isMine,
    required this.colorSeed,
  });

  final String h3;
  final bool isMine;
  final int colorSeed;

  factory OwnedHex.fromJson(Map<String, dynamic> j) => OwnedHex(
    h3: j['h3_index'] as String,
    isMine: j['is_mine'] == true,
    colorSeed: (j['color_seed'] as num?)?.toInt() ?? 0,
  );
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
}
