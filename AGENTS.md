# Benedictum-App Agent Instructions

## Purpose
- This repository contains **Benedictum**, a Flutter + Supabase MVP for practicing an investor pitch with three roles: **Critic, Optimist, Coach**.
- Treat the **app** as the product surface. Do not mix product review with lab/internal process history.

## Repo map
- `/home/runner/work/Benedictum-App/Benedictum-App/lib` — Flutter app
- `/home/runner/work/Benedictum-App/Benedictum-App/supabase/functions` — Edge Functions (`llm-gateway`, `session-proxy`, `_shared`)
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/public` — reviewer-facing docs; start here for shipped product claims
- `/home/runner/work/Benedictum-App/Benedictum-App/docs` — engineering notes in Polish; useful for context, not product truth
- `/home/runner/work/Benedictum-App/Benedictum-App/test` — Flutter/widget tests
- `/home/runner/work/Benedictum-App/Benedictum-App/integration_test` — device/cloud integration flows
- `/home/runner/work/Benedictum-App/Benedictum-App/vendor/speech_to_text` — vendored STT plugin override

## Working method
Use this sequence:

**READ → TRACE → VERIFY → DECIDE → IMPLEMENT → VALIDATE → REPORT → STOP**

Do not reconstruct project reality from only:
- the last message,
- the last task,
- the last commit,
- one document,
- session memory.

Before changing anything, establish:
- current git state,
- relevant docs,
- prior decisions,
- current project state,
- validation requirements.

## Source hierarchy
1. **Repository code and checked-in config** — current technical truth
2. **Repo docs** — context and expected behavior
3. **Engineering notes** — decision/history context, unless contradicted by code

If code, docs, and git disagree, **stop and surface the conflict** instead of guessing.

## Evidence labels
When reporting findings, distinguish:
- **FACT** — confirmed from code/config/docs
- **INFERENCE** — conclusion from confirmed facts
- **HYPOTHESIS** — plausible but unverified
- **UNKNOWN** — insufficient evidence

Never present a hypothesis as a fact.

## Decision and state recovery
Read these before major changes:
- `/home/runner/work/Benedictum-App/Benedictum-App/README.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/CONTRIBUTING.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/SECURITY.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/public/README.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/public/ARCHITECTURE.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/README.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/DECISIONS_LOG.md`
- `/home/runner/work/Benedictum-App/Benedictum-App/docs/CHECKPOINTS.md`

Interpret them carefully:
- `docs/public/*` = public/shipped claims
- `docs/DECISIONS_LOG.md` = decision history
- `docs/CHECKPOINTS.md` and `docs/T1_CLOSURE.md` = state/handoff evidence, not permanent rules
- if an engineering note conflicts with code, **code wins**

Do not turn temporary project state into a permanent rule.

## Repository-specific operating rules
- Public docs must match **code on `master`**, not wishful plans.
- User-facing copy is **English-first**; engineering notes outside `docs/public/` may remain Polish.
- Prompts and model-vendor logic belong on the server side, not in the Flutter client.
- The LLM host is `supabase/functions/llm-gateway`; session persistence is `supabase/functions/session-proxy`.
- A clean clone does **not** include cloud secrets, store listings, or private operator materials.
- Do not invent a privacy contact email; repo docs explicitly say it is not published yet.

## Safe change rules
- Check git status before edits.
- Protect existing work; do not delete, reset, or overwrite unclear changes.
- Do not assume the latest commit captures all project decisions.
- Do not claim success without evidence from code, tests, or command output.
- Keep docs and code aligned when behavior changes.

## Validation
Use only commands supported by the repository. Mark anything not run as unverified.

### Primary repo validation commands
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `cd /home/runner/work/Benedictum-App/Benedictum-App/supabase/functions && deno task test:unit`
- `cd /home/runner/work/Benedictum-App/Benedictum-App/supabase/functions && deno task test:gateway`

### Conditional / environment-dependent commands
- `cd /home/runner/work/Benedictum-App/Benedictum-App/supabase/functions && deno task test:proxy`
  - requires local Supabase plus `TEST_ANON_KEY` and `TEST_SERVICE_KEY`
- `cd /home/runner/work/Benedictum-App/Benedictum-App/supabase/functions && deno task test:e2e`
  - requires real cloud credentials
- `flutter test integration_test/e2e_voice_test.dart ...`
- `flutter test integration_test/e2e_voice_real_test.dart ...`
  - require real credentials and/or physical device setup

### Important validation nuance
- Harnesses with top-level `Deno.exit(...)` must run with **`deno run`**, not `deno test`. This is documented in repo tests and checkpoints.

## Security and secrets
- Never commit API keys, JWTs, `.env` files, Supabase service-role keys, RevenueCat/OneSignal secrets, keystores, or `supabase/.temp/`.
- For vulnerabilities, use GitHub Security Advisories; do not open public issues with exploit details or secrets.

## Stop conditions
Stop and ask for clarification if:
- required files or referenced source materials are unavailable,
- repository state is contradictory,
- a decision appears already made but cannot be confidently reconstructed,
- validation depends on missing credentials, services, or hardware,
- the task would require guessing hidden architecture, policy, or product intent.
