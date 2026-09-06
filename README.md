# Benedictum

**A virtual advisory board — Critic, Optimist, Coach — for practicing an investor pitch.**

Not a chatbot with three skins. Three roles, one session, a structured report.

> PL: Benedictum to wirtualna rada doradcza (Krytyk, Optymista, Coach). Ćwiczysz pitch do inwestora, dostajesz tarczę argumentów i raport. To MVP: jeden scenariusz, uczciwe ograniczenia.

Built as a product (Flutter + Supabase), not as a notebook dump.

Made by **Dariusz Cedro / DCI Veridictum Lab** with a multi-model Hive Mind under human `KROK → DOWÓD → STOP` decisions. Review the **app**, not the laboratory.

[Demo (90s)](docs/public/DEMO.md) · [Limitations](docs/public/LIMITATIONS.md) · [Architecture](docs/public/ARCHITECTURE.md) · [Roadmap](docs/public/ROADMAP.md) · [Privacy](docs/public/PRIVACY.md) · [Security](SECURITY.md) · [Changelog](CHANGELOG.md)

---

## Who it is for

People who must defend an idea out loud — founders first. The shipped MVP is one room: **an investor pitch**.

The longer idea (salary talks, clients, adaptive difficulty) is on the [roadmap](docs/public/ROADMAP.md). It is **not** in this build.

## Why it exists

Founders rehearse pitches in their head. Feedback arrives too late, from one voice, or not at all.

Benedictum puts a small board in the room:

| Seat | Job |
|---|---|
| **Critic** | Stress-test the story |
| **Optimist** | Find what already works |
| **Coach** | Drive the interview, then the next action |

**MVP scenario:** *Pitch to an Investor* only.

## What you can do today

1. Sign in.
2. Intake with the Coach (type or speak).
3. Board analysis (three voices).
4. Report: strengths, gaps, action items, rating 1–5.
5. History: reopen or delete a session.
6. Settings: language, delete account.

Voice: on-device speech-to-text first, explicit cloud fallback; speech synthesis on device.

## How it is built

```
App (Flutter) ──► llm-gateway ──► engine ──► adapters ──► model APIs
              └──► session-proxy   (save / load / delete; no LLM)
```

The client asks for a **task**. Vendors are adapters. Prompts stay on the server.

Stack: Flutter (PL/EN/FR/ES) · Supabase Auth + Postgres + Edge Functions · OpenRouter / Gemini via adapters · RevenueCat (Pro) · OneSignal (optional push).

## Status — MVP, not a store fairy tale

| Shipped | Not shipped / known limit |
|---|---|
| Board session + report | Extra scenarios |
| History + account delete | Server-side Pro entitlement |
| Voice (hybrid STT) | Guaranteed dictation quality |
| Replaceable LLM gateway | “Any model, any region” as a product switch |
| Client paywall | Production billing firewall |

No test-count badges. Counts in old engineering notes are historical.

This repo is the living product surface (including Shipaton 2026). A clean clone does **not** include our cloud secrets or a store listing. Public docs are updated when the product changes — they are not a one-off hackathon flyer.

## Run locally (honest)

**UI only (mock):**

```bash
flutter pub get
flutter run
```

No `SUPABASE_URL` / `SUPABASE_ANON_KEY` → offline mocks. No live board.

**Online** — your own Supabase project, deployed `llm-gateway` + `session-proxy`, secrets on the server, then:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Optional: `ONESIGNAL_APP_ID`, `REVENUECAT_KEY` (ignored on web).

Never commit keys. Anon key is still a credential for *your* project.

## Repo map

```
lib/                    Flutter app
supabase/functions/     llm-gateway, session-proxy, _shared (engine, adapters, prompts)
docs/public/            Reviewer pack  ← start here
docs/                   Engineering notes (Polish) — not the landing
vendor/speech_to_text/  Vendored STT plugin (voice path)
```

## Lab & support

Benedictum is a product of **DCI Veridictum Lab** (Dariusz Cedro).

The lab’s research engine lives separately: [DCI-Librarian-Core](https://github.com/dariuszcfastrans-cmyk/DCI-Librarian-Core) — not a runtime dependency of this app.

### ☕ Support the Lab / Wesprzyj projekt

If you believe in the vision of DCI Veridictum Lab, you can support the work here:

[Patronite — DCI Veridictum Lab](https://www.patreon.com/DCI_Veridictum_Lab)

Support does **not** buy a store listing, private keys, or a security SLA. Vulnerabilities: [SECURITY.md](SECURITY.md).

Privacy contact email is **not published yet** (operator TBD). Do not invent one.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Public docs live in [`docs/public/`](docs/public/README.md) and must stay true to `master`.

## License

MIT — see [LICENSE](LICENSE).

© 2026 Dariusz Cedro / DCI Veridictum Lab
