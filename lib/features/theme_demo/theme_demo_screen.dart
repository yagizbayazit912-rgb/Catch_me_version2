import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Tema örnek ekranı: palet, yazı tipi, buton ve kart stillerini gösterir.
class ThemeDemoScreen extends StatelessWidget {
  const ThemeDemoScreen({super.key});

  static const _swatches = <(String, Color)>[
    ('Arka plan', AppColors.background),
    ('Birincil', AppColors.primary),
    ('İkincil', AppColors.secondary),
    ('Şeftali', AppColors.accentPeach),
    ('Lavanta', AppColors.accentLavender),
    ('Tereyağı', AppColors.accentButter),
    ('Uyarı / kira', AppColors.warning),
    ('Metin', AppColors.text),
    ('İkincil metin', AppColors.textSecondary),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Catch Me · Tema')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Merhaba, kaşif!',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Nunito ile tatlı ve ferah bir başlangıç.',
              style: text.bodyLarge?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          const _SectionTitle('Renkler'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final s in _swatches) _Swatch(name: s.$1, color: s.$2),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Butonlar'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                  style: AppTheme.goldButton,
                  onPressed: () {},
                  child: const Text('Altın Topla')),
              ElevatedButton(
                  style: AppTheme.confirmButton,
                  onPressed: () {},
                  child: const Text('Sahiplen')),
              ElevatedButton(
                  style: AppTheme.cancelButton,
                  onPressed: () {},
                  child: const Text('Vazgeç')),
              OutlinedButton(onPressed: () {}, child: const Text('Detay')),
              const ElevatedButton(onPressed: null, child: Text('Pasif')),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Kartlar'),
          _DemoCard(
            color: AppColors.surface,
            title: 'Bölge #1',
            subtitle: 'Sahibi: sen · Kira: 12 altın/sa',
            icon: Icons.hexagon_rounded,
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _DemoCard(
            color: AppColors.accentButter,
            title: 'Günlük görev',
            subtitle: '3 bölge sahiplen',
            icon: Icons.star_rounded,
            iconColor: AppColors.accentPeach,
          ),
          const SizedBox(height: 12),
          _DemoCard(
            color: AppColors.warning.withValues(alpha: 0.6),
            title: 'Kira vakti!',
            subtitle: 'Bir bölgenin kirası yaklaşıyor',
            icon: Icons.notifications_rounded,
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Etiket ve giriş'),
          const Wrap(spacing: 8, children: [
            Chip(label: Text('Seviye 3')),
            Chip(label: Text('120 altın')),
          ]),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(hintText: 'Takma adın')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.input),
              border: Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.2)),
              boxShadow: AppTheme.softShadow,
            ),
          ),
          const SizedBox(height: 6),
          Text(name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });
  final Color color;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: text.bodyMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
