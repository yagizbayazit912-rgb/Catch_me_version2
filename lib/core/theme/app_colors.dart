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
  static const text = Color(0xFF2F3E46); // Koyu deniz grisi
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

  /// Adım 1.4: haritada kendi bölgem.
  static const ownHex = primary;

  /// Adım 2.2: çadır. Kumaş krem + şeftali çizgi, kapı içi sıcak kakao
  /// (gölgeli açıklık hissi), kanatlar açık şeftali, direk ahşap.
  static const tentCanvas = Color(0xFFFFF4E6);
  static const tentStripe = Color(0xFFFFB38A);
  static const tentDoor = Color(0xFFB9785F);
  static const tentFlap = Color(0xFFFFD9C2);
  static const tentPole = Color(0xFFA07856);
  static const tentKnob = accentButter;

  /// Adım 2.3: uçan sikke (tereyağı yüz, sıcak bal kenar).
  static const coinFace = accentButter;
  static const coinRim = Color(0xFFF5C26B);

  /// Başka oyuncuların bölgeleri (kendi rengimle karışmasın diye primary yok).
  static const otherPlayerPalette = <Color>[
    secondary,
    accentPeach,
    accentLavender,
    accentButter,
    warning,
  ];
}
