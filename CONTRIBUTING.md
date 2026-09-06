# Contributing

Benedictum is a living product. Public docs must match **code on `master`**, not a wish list.

## What belongs here

- App (`lib/`), Edge Functions (`supabase/functions/`), public docs (`docs/public/`).
- Honest limitations. If it is not on `master`, it is not shipped.

## What does not belong here

- Secrets, `.env`, JWTs, `service_role`, keystores, `supabase/.temp/`.
- Operator cockpit, handoffs, idea ledgers, private prompts dumps.
- Uncommitted experiments mixed into a “docs” commit.
- Test-count badges copied from old engineering notes.

## How to run

Offline UI: `flutter pub get && flutter run` (mocks if no dart-defines).

Online: your own Supabase project — see [README.md](README.md). Never commit keys.

## Issues

- Public issues: product bugs, docs drift, missing limitations.
- Security: GitHub Security Advisories only — [SECURITY.md](SECURITY.md).
- Do not paste live URLs with query tokens, logs with emails, or API keys.

## Code shape (so the core stays replaceable)

The Flutter app asks the **gateway** for a task. Vendors are **adapters**.

A new model provider should not require rewriting the client.

## Language

User-facing product copy in this repo is **English-first** (Shipaton / GitHub).

Engineering notes under `docs/*.md` (not `docs/public/`) may stay Polish.
