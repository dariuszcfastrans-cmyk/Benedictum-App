# Known limitations (MVP)

Honest list. Nothing here is hidden in the README.

## Product

- **One scenario:** investor pitch. No negotiation / career packs in this tree.
- **One board:** Critic, Optimist, Coach. Personas are UI metadata; system prompts live on the server.
- **Languages:** UI in PL / EN / FR / ES. Conversation language for voice is a separate user setting.

## Billing & access

- RevenueCat paywall is **client-side** in this MVP. A determined client can call authenticated APIs without a Pro entitlement. Server-side entitlement is planned, not shipped.
- Web builds do not initialize RevenueCat / OneSignal (native SDKs). On web the client treats Pro as unlocked. That is a **known MVP demo choice**, not a store product.

## Backend

- Clone ≠ running cloud. Edge Functions, secrets, and migrations must exist in *your* Supabase project.
- LLM keys never ship in the app. Missing server secrets → explicit failure, not a fake success.
- Rate limit is per authenticated user (RPC), not a full abuse platform.
- Session read-retention (90 days) is enforced on read; physical purge is not this MVP.

## Voice

- STT tries **on-device** first, then an explicit **platform cloud** recognizer if the result is empty or shorter than four words.
- Audio is not stored by Benedictum. Cloud fallback still sends audio to the OS speech service.
- Voice quality depends on the device. It is a capability, not a guaranteed dictation product.

## Store / shipping

- Android release signing uses local `android/key.properties` (gitignored). Absence → you cannot produce the store artifact from a clean clone.
- Privacy policy contact email is **not filled in** yet.
- Play / Galaxy Data Safety forms are worksheets (`docs/data_safety.md`), not submitted proof.

## Working tree vs HEAD

The committed product path is `llm-gateway` with Gemini and OpenRouter adapters.

A local working tree may contain extra adapter experiments. **They are not part of the public product until they are on `master`.**

## Documentation drift

Engineering notes (`docs/ARC.md`, checkpoints) record historical test counts and lab paths. They are not a live scoreboard. Do not quote them as current CI status.
