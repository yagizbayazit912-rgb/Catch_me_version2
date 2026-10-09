-- Sahiplenme süresi 5 dk → 3 dk (kullanıcı kararı, 2026-10-09; DECISIONS.md).
-- SQL Editor'den uygulanır. Tekrar çalıştırılabilir.
update public.game_config set value = '180' where key = 'claim_seconds';
