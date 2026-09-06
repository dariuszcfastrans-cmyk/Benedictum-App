# Roadmap (intent, not a promise)

Benedictum does not end with a hackathon. This page is the **public** place to see what is shipped versus what is only designed.

If a line is not in the **Shipped** table, do not demo it as done.

## Shipped (this tree, `master` HEAD)

- Virtual board: Critic / Optimist / Coach
- One scenario: investor pitch
- Intake → analyze → report
- Session history + account delete
- `llm-gateway` + replaceable adapters (Gemini, OpenRouter on HEAD)
- Hybrid voice (on-device STT first)
- Client-side Pro paywall

## Next product (designed, not this build)

From the product ledger — **not implemented as the main loop yet**:

- User brings *their* situation; Coach diagnoses instead of a fixed script
- More rooms: salary, client, counterpart — not just renamed prompts
- Difficulty as believable counterpart behaviour, not “always attack”
- Train through consequences (action → reaction → adapt)

## Contest / store (intent)

Shipaton 2026 is a milestone, not the product’s end date. If a contest category is filed, **Career Coaching** is the intended fit (founder pitch practice). That filing is **not** claimed as done here.

Still needed for a store/contest pack (not in this tree as submitted artifacts): listing URL, 1024 icon, device screenshots, ≤2 min demo from a physical device, privacy contact, Data Safety form.

## Next engineering

- Server-side entitlement (paywall is client-side today)
- Extra LLM adapters without touching the Flutter core
- Physical purge of expired sessions
- Store listing, privacy contact, Data Safety forms

## How this page stays honest

Update it at checkpoints: move a row only when code on `master` matches.

Uncommitted experiments in a working tree are **not** shipped.
