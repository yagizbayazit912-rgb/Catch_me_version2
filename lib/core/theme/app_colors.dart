import 'package:flutter/material.dart';

/// Pastel palet (PROJE_PLANI bölüm 14). Renkler yalnızca buradan okunur.
abstract final class AppColors {
  static const background = Color(0xFFFFFBF5); // Krem beyaz
  static const primary = Color(0xFF7ED9B5); // Nane yeşili
  static const secondary = Color(0xFF8EC9F5); // Gökyüzü mavisi
  static const accentPeach = Color(0xFFFFC9A8); // Şeftali
  static const accentLavender = Color(0xFFC9B8F5); // Lavanta
  static const accentButter = Color(0xFFFFE9A3); // Tereyağı sarısı
  static const warning = Color(0xFFFFABB8); // Pudra pembe (uyarı / kira)
  static const danger = Color(0xFFFF8A8A); // Yumuşak kırmızı (vazgeç/iptal)
  static const text =Color(0xFF2F3E46); // Koyu deniz grisi
  static const textSecondary = Color(0xFF7A8A93); // Yumuşak gri

  static const surface = Color(0xFFFFFFFF);

  /// Oyuncu bölge renkleri için atanabilir pastel havuz.
  static const playerPalette = <Color>[
    primary,
    secondary,
    accentPeach,
    accentLavender,
    accentButter,
    warning,
  ];
}
