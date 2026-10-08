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
