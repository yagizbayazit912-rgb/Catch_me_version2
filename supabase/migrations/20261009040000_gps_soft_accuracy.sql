-- GPS iyileştirme (2026-10-09): ping_max_accuracy_m (50) ile bu değer
-- arasındaki doğruluk, doğruluk dairesi tamamen tek altıgenin içindeyse
-- kabul edilir (location-ping). Üstü her zaman ret. Tekrar çalıştırılabilir.
insert into public.game_config (key, value) values
  ('ping_soft_max_accuracy_m', '100')
on conflict (key) do update set value = excluded.value;
