// Backoff (G.2) — gemini-proxy.
// Odczyt Retry-After z odpowiedzi Gemini API (sekundy lub HTTP-date).
// Fallback 60s (spójnie z rate-limitem RPC check_rate_limit).
//
// Izolacja providera: oddzielny moduł per provider (granica adaptera),
// nie współdzielony z openrouter-proxy — zgodnie z dyrektywą Krok 3.

export function extractRetryAfter(res: Response, fallback = 60): number {
  const raw = res.headers.get("Retry-After");
  if (!raw) return fallback;
  const seconds = Number(raw);
  if (Number.isFinite(seconds) && seconds >= 0) return Math.ceil(seconds);
  const t = Date.parse(raw);
  if (Number.isFinite(t)) {
    return Math.max(0, Math.ceil((t - Date.now()) / 1000));
  }
  return fallback;
}
