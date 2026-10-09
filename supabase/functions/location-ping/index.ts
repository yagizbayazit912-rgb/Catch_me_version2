// Adım 1.1: POST /location-ping
// İstemci konumunu yollar; sunucu doğrular, h3 hesaplar, son ping'i saklar.
// Adım 1.5: eşikler game_config'ten (ping_guard RPC); şüpheli ihlaller
// record_violation ile kaydedilir, tekrar ederse kullanıcı geçici askıya alınır.
// Tek dosya (dashboard'dan yapıştırılabilsin diye). İstemci sadece ister,
// karar burada. Başka oyunculara kesin koordinat dönmez; bu cevap yalnızca
// çağıranın kendi konumuna aittir.
import { createClient } from "npm:@supabase/supabase-js@2";
import { cellToBoundary, latLngToCell } from "npm:h3-js@4";

// H3_RESOLUTION, istemcideki GameConfig.h3Resolution ile aynı olmalı.
// Diğer tüm eşikler game_config tablosunda (migration 20261001040000).
const H3_RESOLUTION = 9;
const CFG_KEYS = [
  "ping_max_accuracy_m",
  "ping_soft_max_accuracy_m",
  "ping_min_accuracy_m",
  "ping_max_speed_mps",
  "ping_max_age_s",
  "ping_teleport_max_gap_s",
  "presence_max_speed_kmh",
  "anticheat_strike_speed_mps",
] as const;
type Cfg = Record<(typeof CFG_KEYS)[number], number>;

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

// Noktanın kendi altıgeninin kenarına en kısa mesafesi (m). Yerel düzlem
// izdüşümü; altıgen ölçeğinde (~200 m) hata ihmal edilebilir.
function distToCellEdgeM(lat: number, lng: number, cell: string) {
  const R = 6371000;
  const rad = Math.PI / 180;
  const kx = Math.cos(lat * rad) * R * rad;
  const pts = cellToBoundary(cell).map(([la, ln]) => [
    (ln - lng) * kx,
    (la - lat) * R * rad,
  ]);
  let best = Infinity;
  for (let i = 0; i < pts.length; i++) {
    const [ax, ay] = pts[i];
    const [bx, by] = pts[(i + 1) % pts.length];
    const dx = bx - ax, dy = by - ay;
    const t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy)));
    best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
  }
  return best;
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

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Eşikler + aktif askı tek çağrıda. Eşik eksikse kapalı başarısız ol.
  const { data: guard, error: guardErr } = await admin.rpc("ping_guard", {
    p_user: userId,
  });
  if (guardErr || !guard?.cfg) return json({ error: "server_error" }, 500);
  const cfg = {} as Cfg;
  for (const k of CFG_KEYS) {
    if (!isNum(guard.cfg[k])) return json({ error: "server_error" }, 500);
    cfg[k] = guard.cfg[k];
  }

  // Reddedilen ping son durumu GÜNCELLEMEZ (kötü veri hız hesabını bozmasın)
  // ve presence biriktirmez (accrue_presence'a hiç ulaşmaz).
  const reject = (reason: string, suspendedUntil?: string | null) =>
    json({ ok: false, reason, suspended_until: suspendedUntil ?? undefined });

  // Şüpheli ihlal: kaydet, eşik aşılırsa askı başlar. Koordinat yazılmaz.
  const violation = async (reason: string, speed: number | null) => {
    const { data, error } = await admin.rpc("record_violation", {
      p_user: userId,
      p_reason: reason,
      p_h3: latLngToCell(lat, lng, H3_RESOLUTION),
      p_speed: speed,
      p_accuracy: accuracy,
    });
    if (error) return json({ error: "server_error" }, 500);
    return reject(reason, data?.suspended_until);
  };

  if (guard.suspended_until) return reject("suspended", guard.suspended_until);

  // İstemci bildirimi tek başına güvenilir değil (değiştirilmiş istemci
  // yalan söyleyebilir); sunucu ayrıca doğruluk ve hızdan şüphe çıkarır.
  if (is_mock === true) return violation("mock_location", null);
  // Gerçek GPS ~0 m doğruluk bildirmez; sahte konum uygulamalarının izi.
  if (accuracy < cfg.ping_min_accuracy_m) {
    return violation("implausible_accuracy", null);
  }
  // Orta doğruluk (ör. 50–100 m) altıgen kesinse kabul: doğruluk dairesi
  // tamamen tek altıgenin içindeyse oyuncunun hangi altıgende olduğu belli.
  if (
    accuracy > cfg.ping_max_accuracy_m &&
    (accuracy > cfg.ping_soft_max_accuracy_m ||
      distToCellEdgeM(lat, lng, latLngToCell(lat, lng, H3_RESOLUTION)) <
        accuracy)
  ) {
    return reject("poor_accuracy");
  }
  if (isNum(client_ts)) {
    const ageS = (Date.now() - client_ts) / 1000;
    if (ageS > cfg.ping_max_age_s) return reject("stale");
  }
  const { data: prev, error: prevErr } = await admin
    .from("ping_state")
    .select("lat,lng,accuracy_m,h3_index,pinged_at")
    .eq("user_id", userId)
    .maybeSingle();
  if (prevErr) return json({ error: "server_error" }, 500);

  const now = new Date();
  let speedMps = 0;
  const gapS = prev
    ? (now.getTime() - new Date(prev.pinged_at).getTime()) / 1000
    : Infinity;
  // Çok uzun aradan sonra (uçak, kapalı telefon) hız kontrolü yapılmaz;
  // yoksa yeni şehirde her ping "teleport" reddine kilitlenirdi.
  if (prev && gapS <= cfg.ping_teleport_max_gap_s) {
    const dtS = Math.max(1, gapS);
    // GPS gürültüsü yanlış "ışınlanma" üretmesin: iki ölçümün doğruluğu
    // kadar mesafeyi sayma.
    const dist = Math.max(
      0,
      haversineM(prev.lat, prev.lng, lat, lng) - prev.accuracy_m - accuracy,
    );
    speedMps = dist / dtS;
    if (speedMps > cfg.ping_max_speed_mps) {
      // Hızlı tren vb. sadece reddedilir; yerde imkânsız hız ihlal sayılır.
      return speedMps > cfg.anticheat_strike_speed_mps
        ? violation("teleport", speedMps)
        : reject("teleport");
    }
  }

  const h3Index = latLngToCell(lat, lng, H3_RESOLUTION);
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
  const countsForPresence = speedMps * 3.6 <= cfg.presence_max_speed_kmh;
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
