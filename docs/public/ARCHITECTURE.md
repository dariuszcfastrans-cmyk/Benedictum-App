# Architecture (one page)

The app core does **not** name a model vendor. It calls a task.

```
Flutter app
   │  JWT
   ├─► llm-gateway     (intake / analyze / report)
   │       │
   │       ▼
   │   execution engine  →  adapters  →  supplier APIs
   │
   └─► session-proxy   (history, ownership, delete — no LLM)
```

## Replaceable pieces

| Piece | Role today | How it is meant to change |
|---|---|---|
| Task | `intake` / `analyze` / `report` | New task = new contract, not a new app |
| Gateway | Supabase Edge Function `llm-gateway` | Client default; compile-time override exists for dev |
| Engine | Shared `_shared/engine` | Retry, fallback, timeouts — not provider JSON |
| Adapter | `_shared/adapters/gemini.ts`, `openrouter.ts` | New vendor = new adapter + registry entry |
| Prompts | `_shared/prompts` | Product IP; not shipped in the Flutter client |
| Persistence | `session-proxy` | Independent of which model answered |

## What is deliberately unfinished

Interfaces exist for artifacts / extra modalities (voice is already in the **app**, not as a second LLM engine). Extra adapters may appear in a working tree; **uncommitted work is not part of this product claim.**

On `master` HEAD the registered adapters are Gemini and OpenRouter. Adding a vendor is meant to be: adapter file + registry entry — not a new Flutter client.

## Trust boundaries

- JWT verified by the platform before function code.
- User id from `sub`; session rows are owned by that id.
- Report body is parsed against a JSON contract before it is stored.
- A technically successful HTTP 200 that fails the contract is not treated as a good answer.

Longer narrative: `docs/ARC.md` (engineering log, Polish).
