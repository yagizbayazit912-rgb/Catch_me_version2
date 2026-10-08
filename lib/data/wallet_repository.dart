import 'package:supabase_flutter/supabase_flutter.dart';

/// Oyuncunun bakiyesi. Değişiklik sadece sunucuda (`apply_transaction`);
/// istemci sadece kendi satırını okur (RLS).
class Wallet {
  const Wallet({required this.coins, required this.gems});

  final int coins;
  final int gems;
}

class WalletRepository {
  WalletRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Wallet> load() async {
    final row = await _client
        .from('users')
        .select('coins, gems')
        .eq('id', _client.auth.currentUser!.id)
        .single();
    return Wallet(
      coins: (row['coins'] as num).toInt(),
      gems: (row['gems'] as num).toInt(),
    );
  }
}

/// Bir yapının kasası (Adım 2.3). Hesap sunucuda (`my_income`).
class IncomeSlot {
  const IncomeSlot({
    required this.h3,
    required this.pending,
    required this.cap,
    required this.isFull,
  });

  final String h3;
  final int pending;
  final int cap;
  final bool isFull;

  factory IncomeSlot.fromJson(Map<String, dynamic> j) => IncomeSlot(
    h3: j['h3_index'] as String,
    pending: (j['pending'] as num).toInt(),
    cap: (j['cap'] as num).toInt(),
    isFull: j['is_full'] == true,
  );
}

/// Toplama sonucu: toplam, yeni bakiye ve hücre başı dağılım (animasyon).
class CollectResult {
  const CollectResult({
    required this.total,
    required this.coins,
    required this.perCell,
  });

  final int total;
  final int coins;
  final Map<String, int> perCell;
}

/// Gelir okuma/toplama. Hesap ve karar sunucuda; istemci sadece ister.
class IncomeRepository {
  IncomeRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<IncomeSlot>> load() async {
    final rows = await _client.rpc('my_income');
    return [
      for (final r in rows as List)
        IncomeSlot.fromJson(r as Map<String, dynamic>),
    ];
  }

  Future<CollectResult> collect() async {
    final res = (await _client.rpc('collect_income')) as Map;
    return CollectResult(
      total: (res['total'] as num).toInt(),
      coins: (res['coins'] as num).toInt(),
      perCell: {
        for (final i in res['items'] as List)
          (i as Map)['h3'] as String: (i['coins'] as num).toInt(),
      },
    );
  }
}
