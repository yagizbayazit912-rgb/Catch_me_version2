-- Sahiplenme süresi 10 dk → 5 dk (kullanıcı kararı, 2026-10-09; DECISIONS.md).
-- Canlıda SQL Editor'den uygulandı; bu dosya kayıt ve yeni kurulum için.
-- Tekrar çalıştırılabilir.
update public.game_config set value = '300' where key = 'claim_seconds';
