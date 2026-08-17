// Testy jednostkowe backoff (G.2) — openrouter-proxy.
// Symulacja odpowiedzi OpenRouter 429 z nagłówkiem Retry-After (sekundy | HTTP-date | brak).
//
// Uruchom: deno test --allow-net supabase/functions/openrouter-proxy/backoff_test.ts

import { assertEquals } from "jsr:@std/assert";
import { extractRetryAfter } from "./backoff.ts";

Deno.test("Retry-After jako liczba sekund", () => {
  const res = new Response(null, { headers: { "Retry-After": "30" } });
  assertEquals(extractRetryAfter(res), 30);
});

Deno.test("Retry-After = 0 → natychmiast", () => {
  const res = new Response(null, { headers: { "Retry-After": "0" } });
  assertEquals(extractRetryAfter(res), 0);
});

Deno.test("Retry-After jako HTTP-date (zaokrąglenie w górę)", () => {
  const in5s = new Date(Date.now() + 5000).toUTCString();
  const res = new Response(null, { headers: { "Retry-After": in5s } });
  const got = extractRetryAfter(res);
  assertEquals(got, 5);
});

Deno.test("HTTP-date w przeszłości → 0", () => {
  const past = new Date(Date.now() - 10000).toUTCString();
  const res = new Response(null, { headers: { "Retry-After": past } });
  assertEquals(extractRetryAfter(res), 0);
});

Deno.test("Brak Retry-After → fallback 60", () => {
  const res = new Response(null);
  assertEquals(extractRetryAfter(res), 60);
});

Deno.test("Brak Retry-After → własny fallback", () => {
  const res = new Response(null);
  assertEquals(extractRetryAfter(res, 42), 42);
});

Deno.test("Niepoprawna wartość → fallback 60", () => {
  const res = new Response(null, { headers: { "Retry-After": "abc" } });
  assertEquals(extractRetryAfter(res), 60);
});
