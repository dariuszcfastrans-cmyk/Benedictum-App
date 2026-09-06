# Privacy (public card)

Short reviewer card. Canonical text: [`../privacy-policy.md`](../privacy-policy.md).

**Contact email for data requests: not published yet** (operator TBD). Do not invent one.

Lab funding (not a privacy inbox): [Patronite — DCI Veridictum Lab](https://www.patreon.com/DCI_Veridictum_Lab).

## What the app processes

| Data | Why |
|---|---|
| Email + auth identifiers | Account (Supabase Auth) |
| Session text + reports | Coaching and history |
| Subscription status | RevenueCat / store |
| Device push id | OneSignal, only if notifications are used |
| Voice | Mic for STT. Benedictum does not keep recordings. Cloud STT fallback uses the platform speech service |

## What we do not do

- No sale of data, no marketing sharing.
- No payment card numbers in Benedictum (store handles checkout).
- No AI provider keys in the client.

## Third parties (processing, not sale)

Supabase · OpenRouter and upstream model hosts · RevenueCat · Google Play · OneSignal · (voice fallback) OS speech services.

Free-tier model routing is configured with OpenRouter `data_collection: deny` where that control exists. **Free endpoints are not a guarantee that no provider ever trains.** We do **not** claim EU-only or US-only processing: aggregator routing can involve multiple upstream hosts. See `docs/data_safety.md` for the store-form wording.

## User controls

Settings → **Delete account** removes the account and cascaded session/report rows.

## Children

Not directed at children under 13.
