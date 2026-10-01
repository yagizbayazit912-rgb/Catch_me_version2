// Adım 1.1: POST /location-ping
// İstemci konumunu yollar; sunucu doğrular, h3 hesaplar, son ping'i saklar.
// Tek dosya (dashboard'dan yapıştırılabilsin diye). İstemci sadece ister,
// karar burada. Başka oyunculara kesin koordinat dönmez; bu cevap yalnızca
// çağıranın kendi konumuna aittir.
import { createClient } from "npm:@supabase/supabase-js@2";
import { latLngToCell } from "npm:h3-js@4";

// --- Config (koda gömülü sayı yok; ileride config tablosuna taşınacak) ---
// H3_RESOLUTION, istemcideki GameConfig.h3Resolution ile aynı olmalı.
const CONFIG = {
  H3_RESOLUTION: 9,
  MAX_ACCURACY_M: 50, // bunun üstündeki doğruluk (kötü) reddedilir (plan 5.4)
  MAX_SPEED_MPS: 30, // üstü = ışınlanma, reddedilir (plan 5.4)
  PRESENCE_MAX_SPEED_KMH: 25, // üstünde varlık puanı birikmez (plan 5.4)
  MAX_PING_AGE_S: 120, // istemci zamanı bundan eskiyse reddedilir
};

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function haversineM(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371000;
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

const isNum = (v: unknown): v is number =>
  typeof v === "number" && Number.isFinite(v);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Kimlik: JWT'den kullanıcı (gövdedeki user id'ye güvenilmez).
  const url = Deno.env.get("SUPABASE_URL")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: u, error: authErr } = await asUser.auth.getUser();
  if (authErr || !u.user) return json({ error: "unauthorized" }, 401);
  const userId = u.user.id;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const { lat, lng, accuracy, is_mock, client_ts } = body;
  if (
    !isNum(lat) || !isNum(lng) || !isNum(accuracy) ||
    lat < -90 || lat > 90 || lng < -180 || lng > 180 || accuracy < 0
  ) {
    return json({ ok: false, reason: "invalid_input" }, 400);
  }

  // Reddedilen ping son durumu GÜNCELLEMEZ (kötü veri hız hesabını bozmasın).
  const reject = (reason: string) => json({ ok: false, reason });

  // İstemci bildirimi tek başına güvenilir değil (1.5'te sunucu tarafı
  // risk skoru gelecek) ama bildirilen sahte konum doğrudan reddedilir.
  if (is_mock === true) return reject("mock_location");
  if (accuracy > CONFIG.MAX_ACCURACY_M) return reject("poor_accuracy");
  if (isNum(client_ts)) {
    const ageS = (Date.now() - client_ts) / 1000;
    if (ageS > CONFIG.MAX_PING_AGE_S) return reject("stale");
  }

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: prev, error: prevErr } = await admin
    .from("ping_state")
    .select("lat,lng,accuracy_m,h3_index,pinged_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (prevErr) return json({ error: "server_error" }, 500);

  const now = new Date();
  let speedMps = 0;
  if (prev) {
    const dtS = Math.max(
      1,
      (now.getTime() - new Date(prev.pinged_at).getTime()) / 1000,
    );
    // GPS gürültüsü yanlış "ışınlanma" üretmesin: iki ölçümün doğruluğu
    // kadar mesafeyi sayma.
    const dist = Math.max(
      0,
      haversineM(prev.lat, prev.lng, lat, lng) - prev.accuracy_m - accuracy,
    );
    speedMps = dist / dtS;
    if (speedMps > CONFIG.MAX_SPEED_MPS) return reject("teleport");
  }

  const h3Index = latLngToCell(lat, lng, CONFIG.H3_RESOLUTION);
  const { error: upErr } = await admin.from("ping_state").upsert({
    user_id: userId,
    lat,
    lng,
    accuracy_m: accuracy,
    h3_index: h3Index,
    pinged_at: now.toISOString(),
  });
  if (upErr) return json({ error: "server_error" }, 500);

  // Adım 1.2: varlık birikimi. Hızlıysa (araç) ping kabul edilir ama süre
  // sayılmaz. Süre sadece AYNI altıgende kalınan ardışık ping aralığıdır
  // (ilk ping veya altıgen değişimi 0 sn). Tavan ve eşikler DB config'inde.
  const countsForPresence = speedMps * 3.6 <= CONFIG.PRESENCE_MAX_SPEED_KMH;
  let presence: unknown = null;
  if (countsForPresence) {
    const seconds = prev && prev.h3_index === h3Index
      ? Math.floor((now.getTime() - new Date(prev.pinged_at).getTime()) / 1000)
      : 0;
    const { data, error: rpcErr } = await admin.rpc("accrue_presence", {
      p_user: userId,
      p_h3: h3Index,
      p_seconds: seconds,
    });
    if (rpcErr) return json({ error: "server_error" }, 500);
    presence = data;
  }

  return json({
    ok: true,
    h3: h3Index,
    speed_mps: Math.round(speedMps * 10) / 10,
    counts_for_presence: countsForPresence,
    presence,
  });
});
