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

  /// Adım 2.4: yapılar. Pastel tabanda daha doygun vurgular: her seviye bir
  /// öncekinden daha zengin. Ortak: yanan pencere sıcak sarı, cam gök mavisi,
  /// çim/çalı canlı nane.
  static const windowLit = Color(0xFFFFE27A);
  static const glass = Color(0xFF6CC4FA);
  static const lawn = Color(0xFF9BE39A);
  static const bush = Color(0xFF4FC97F);
  static const bushLight = Color(0xFF7DDE9C);
  static const paving = Color(0xFFF4E8D8);
  static const trimWhite = Color(0xFFFFFFFF);
  static const poleMetal = Color(0xFFC9D3DA);

  /// Ev: sıcak beyaz duvar, iki tonlu mercan çatı, ahşap kanat, turkuaz kapı.
  static const houseWall = Color(0xFFFFF8EE);
  static const houseRoof = Color(0xFFFF6F61);
  static const houseRoofLight = Color(0xFFFF9180);
  static const houseWood = Color(0xFFE9A066);
  static const houseDoor = Color(0xFF2BB8AA);
  static const houseChimney = Color(0xFFC07A5E);

  /// Otel: beyaz kule, lavanta-mor ve pembe balkonlar, cam lobi, havuz,
  /// turuncu tente, palmiye.
  static const hotelWall = Color(0xFFFBF8FF);
  static const hotelAccent = Color(0xFF9475F2);
  static const hotelAccent2 = Color(0xFFFF7FAA);
  static const hotelAwning = Color(0xFFFF9F55);
  static const pool = Color(0xFF4FD8EA);
  static const palmTrunk = Color(0xFFB98257);

  /// Gökdelen: aşağıda derin, yukarı doğru açılan cam tonları; beyaz kat
  /// bantları, pahlı köşelerde nane ışık şeritleri, kademe aralarında
  /// lavanta parlayan "gökyüzü lobisi" katları, kırmızımsı ikaz ışığı.
  static const skyGlassDeep = Color(0xFF3A95E8);
  static const skyGlass = Color(0xFF4EAEF5);
  static const skyGlassMid = Color(0xFF6DC0FA);
  static const skyGlassTop = Color(0xFF96D6FF);
  static const skyBand = trimWhite;
  static const skyFin = Color(0xFF3FD3B5);
  static const skyGlow = Color(0xFFC9B6FF);
  static const skyBeacon = Color(0xFFFF5C7C);

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
