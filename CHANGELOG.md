# Changelog

Product-facing history. Engineering logs live in `docs/ARC.md` and
`docs/CHECKPOINTS.md` and are **not** claims for reviewers.

Dates are commit dates on `master`.

## 2026-08-30

- Data Safety: free-tier model routing with `data_collection: deny` (OpenRouter).
- Android `applicationId` set to `com.dci.benedictum`.

## 2026-08-20

- Voice: hybrid on-device STT with explicit cloud fallback; on-device TTS.
- LLM foundation in production path: `llm-gateway` + shared engine/adapters.
- Legacy `gemini-proxy` / `openrouter-proxy` Edge Functions removed from tree.

## 2026-08-18

- Account deletion (in-app, cascading).
- Voice input/output in the chat bar (mic confirm-before-lock).
- Release signing via gitignored `android/key.properties`.

## 2026-08-16

- Session history: list, open report, cascade delete.
- Session persistence via `session-proxy` (JWT ownership, 90-day read retention).
- End-of-session report (`strengths` / `gaps` / `action_items` / rating 1–5).

## 2026-08-08

- Live Supabase path (auth, rate limit, first LLM proxy).
- Client-side RevenueCat paywall (MVP).

## 2026-08-04

- Project start: virtual board (Critic, Optimist, Coach), not a single chatbot.
