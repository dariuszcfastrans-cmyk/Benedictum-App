// Backoff (G.2) — czysty moduł, bez zależności od supabase-js (testowalny jednostkowo).
// Odczyt Retry-After z odpowiedzi OpenRouter (sekundy lub HTTP-date).
// Fallback 60s (spójnie z rate-limitem RPC check_rate_limit).

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
