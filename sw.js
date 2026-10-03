// Service worker do fichário: app e dados em "rede primeiro, cache se offline"; imagens de cartas em "cache primeiro".
const CACHE = "fichario-v1";
self.addEventListener("install", e => { self.skipWaiting(); });
self.addEventListener("activate", e => { e.waitUntil(self.clients.claim()); });
self.addEventListener("fetch", e => {
  const req = e.request; if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname === "api.github.com") return;                 // sincronização nunca passa pelo cache
  const isImg = /\.(webp|png|jpg|jpeg|svg)$/i.test(url.pathname) || url.hostname !== location.hostname;
  if (isImg) {                                                    // imagens: cache primeiro
    e.respondWith(caches.open(CACHE).then(async c => { const hit = await c.match(req); if (hit) return hit;
      try { const r = await fetch(req); if (r && (r.ok || r.type === "opaque")) c.put(req, r.clone()); return r; } catch { return hit || Response.error(); } }));
    return;
  }
  e.respondWith((async () => {                                    // app e dados: rede primeiro, cache se offline
    const c = await caches.open(CACHE);
    try { const r = await fetch(req, { cache: "no-store" }); if (r && r.ok) c.put(req, r.clone()); return r; }
    catch { const hit = await c.match(req, { ignoreSearch: true }); return hit || new Response("Sem conexão e sem cópia guardada.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } }); }
  })());
});