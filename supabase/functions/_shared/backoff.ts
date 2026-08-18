// Backoff (G.2) — moduł współdzielony (KROK 2, _shared/).
// Odczyt Retry-After z odpowiedzi providera LLM (sekundy lub HTTP-date).
// Fallback 60s (spójnie z rate-limitem RPC check_rate_limit).
// Rola w architekturze v2.0: narzędzie silnika (engine) — retry/backoff transportu,
// nie część adaptera (adaptery są czystymi tłumaczami). Uwaga: wcześniejszy komentarz
// „nie współdzielony… zgodnie z dyrektywą Krok 3" jest unieważniony decyzją KROKU 2.

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
