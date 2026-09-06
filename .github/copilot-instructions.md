# Copilot instructions for Benedictum-App

- Use `/home/runner/work/Benedictum-App/Benedictum-App/AGENTS.md` as the primary working contract for this repository.
- Recover context before editing: read `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `docs/public/README.md`, `docs/public/ARCHITECTURE.md`, `docs/README.md`, `docs/DECISIONS_LOG.md`, and `docs/CHECKPOINTS.md`.
- Follow: **READ → TRACE → VERIFY → DECIDE → IMPLEMENT → VALIDATE → REPORT → STOP**.
- Work in one agreed step at a time; after each step, report results and stop for the next decision unless the task explicitly authorizes continuation.
- Do not guess from the last message, last commit, or one document alone.
- Treat code/config as current truth; if engineering notes disagree with code, **code wins**.
- Separate **FACT**, **INFERENCE**, **HYPOTHESIS**, and **UNKNOWN** in analysis.
- Respect work modes: READ-ONLY = no edits, TEST-ONLY = tests/fixtures only, WRITE = approved scope only.
- If scope drifts, repo state is unexpected, or safe progress would require guessing, stop immediately and surface the risk before any recovery action.
- Do not turn temporary project state or handoff notes into permanent rules.
- Keep public docs truthful to shipped behavior on `master`.
- Main product areas: `lib/` (Flutter app), `supabase/functions/llm-gateway` (LLM host), `supabase/functions/session-proxy` (session persistence), `supabase/functions/_shared` (shared engine/adapters/prompts).
- Validate with real repo commands when relevant: `flutter analyze`, `flutter test`, `cd supabase/functions && deno task test:unit`, `cd supabase/functions && deno task test:gateway`.
- `deno task test:proxy`, Deno e2e, and Flutter integration tests are environment-dependent; do not claim them as passed unless actually run with the required services/credentials/device.
- Do not commit secrets, `.env` files, JWTs, service-role keys, keystores, or `supabase/.temp/`.
- Stop and surface conflicts when docs, git state, and code do not line up.
