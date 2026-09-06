# Demo card (60–120 seconds)

**Product:** Benedictum — virtual advisory board for an investor pitch.

**Scenario in the build:** *Pitch to an Investor* (`pitch_investor`). Only this scenario ships in the MVP.

## Happy path

1. Launch the app → sign in (or use the offline mock UI if no Supabase dart-defines).
2. Home → **Pitch to an Investor**.
3. **Intake:** Coach interviews you (one persona). Speak or type. Confirm you are ready.
4. **Analyze:** Critic, Optimist, and Coach respond as a board.
5. **Report:** strengths, gaps, action items, overall rating 1–5.
6. Optional: History (open / delete a session). Settings → delete account.

## What to look at

| Surface | Why it matters |
|---|---|
| Three distinct voices | Not a single chatbot with three labels |
| Report JSON rendered as text | Untrusted model output is not executed |
| Voice (Android) | Hybrid STT; TTS on-device |
| Paywall | Freemium / RevenueCat (client-enforced in MVP) |

## What this demo is not

- Not a store listing walkthrough.
- Not a multi-scenario coach.
- Not a proof that every LLM provider is wired — the live path is `llm-gateway` with replaceable adapters.

## Offline vs online

Without `SUPABASE_URL` + `SUPABASE_ANON_KEY`, the app starts in **mock** mode (UI only).

A full AI board requires a configured Supabase project and deployed `llm-gateway` / `session-proxy`.
