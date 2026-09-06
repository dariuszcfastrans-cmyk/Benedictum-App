# Security

## Reporting a vulnerability

Please **do not** open a public issue for secrets, tokens, or exploitable bugs.

Report privately via **GitHub Security Advisories** on this repository (or a
direct message to the owner). Include:

- affected surface (app / Edge Function / docs)
- a minimal reproduction
- impact

Do not attach `.env` files, API keys, JWTs, or production logs.

The lab [Patreon / “Patronite”](https://www.patreon.com/DCI_Veridictum_Lab) page is **not** a vulnerability inbox. No security contact email is published yet.

## What this project does not put in git

- Provider API keys (Gemini, OpenRouter, …)
- Supabase service-role key
- RevenueCat / OneSignal secrets
- Android `key.properties` / keystores
- Local Supabase CLI state (`supabase/.temp/`)

Public dart-defines expected by the app are **project URL** and **anon/publishable
key** only — still do not paste live values into issues.

## Known MVP limitation

Subscription entitlement is enforced **on the client** in this MVP. Server-side
entitlement checks are planned. Treat the Edge Functions as authenticated APIs,
not as a complete billing firewall.
