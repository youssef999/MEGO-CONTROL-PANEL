# Customer App — Supabase `x-app-secret` (RLS Policy Sync)

This guide is for the **Customer (passenger/food user) app**.  
After enabling the Supabase RLS policy `only_app_with_secret`, every client that talks to Supabase with the **anon key** must send the same custom header. The Partner/Driver app already does this; the Customer app must match it or **all** PostgREST calls will fail with permission / RLS errors.

---

## What the Supabase policy expects

On each `public` table, RLS is enabled with a policy that allows access only when:

```text
request header  x-app-secret  ==  the secret stored in the SQL policy
```

Equivalent check used in SQL:

```sql
(current_setting('request.headers', true)::json ->> 'x-app-secret') = '<SAME_SECRET>'
```

So the Customer app must:

1. Store the **exact same** secret as Partner (`SUPABASE_APP_SECRET` in Partner `.env`).
2. Pass it on **every** Supabase client request via header `x-app-secret`.

Do **not** invent a different secret per app. One shared secret for all mobile clients that use the anon key.

---

## Prerequisites

- Same Supabase project as Partner (`SUPABASE_URL` + `SUPABASE_ANON_KEY`).
- Package: `supabase_flutter` (same pattern as Partner).
- Prefer `flutter_dotenv` + a local `.env` file (do not hardcode the secret in Dart source committed to git).

---

## Step 1 — Add secret to `.env`

In the Customer app root `.env`:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_APP_SECRET=PASTE_EXACT_VALUE_FROM_PARTNER_APP_ENV
```

Copy `SUPABASE_APP_SECRET` from the Partner app `.env` **character-for-character** (no extra spaces/newlines).

Also update `.env.example` (safe placeholder only):

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_APP_SECRET=your-app-secret
```

---

## Step 2 — Keep secrets out of git

In Customer `.gitignore`:

```gitignore
.env
.env.*
!.env.example
```

Never commit real secrets. Never put the secret under `assets/` as a plain text file.

If using `flutter_dotenv`, register `.env` under `flutter: assets:` in `pubspec.yaml` (same as Partner):

```yaml
flutter:
  assets:
    - .env
```

---

## Step 3 — Load env and pass header on `Supabase.initialize`

Mirror Partner `lib/main.dart`: load dotenv first, then initialize Supabase **once** with the header. One place is enough — do not add the header on every feature call.

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
  final supabaseAppSecret = dotenv.env['SUPABASE_APP_SECRET']?.trim();

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  }
  if (supabaseAppSecret == null || supabaseAppSecret.isEmpty) {
    throw Exception('Missing SUPABASE_APP_SECRET in .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    headers: {
      'x-app-secret': supabaseAppSecret,
    },
  );

  runApp(const MyApp());
}
```

Critical details:

| Item | Value |
|------|--------|
| Header name | `x-app-secret` (lowercase, exact) |
| Header value | Same string as SQL policy and Partner `.env` |
| Where to set | Only in `Supabase.initialize(... headers: ...)` |
| Client usage | Keep using `Supabase.instance.client` everywhere |

If the Customer app creates a **second** `SupabaseClient` manually (e.g. `SupabaseClient(url, key)`), that instance must also get the same headers, or those calls will be rejected after RLS is on.

---

## Step 4 — Do not bypass the shared client

After this change:

- All `.from(...)`, `.rpc(...)`, Storage, and Auth calls that go through `Supabase.instance.client` inherit the header.
- Raw `http` / `dio` calls to `https://<project>.supabase.co/rest/v1/...` will **not** inherit it. Either stop using raw REST, or add:

```http
x-app-secret: <SAME_SECRET>
apikey: <ANON_KEY>
Authorization: Bearer <ANON_KEY_OR_USER_JWT>
```

---

## Step 5 — Verify before / after RLS

### Before running the SQL policy (optional)

App behavior should be unchanged; the header is ignored if RLS policies are not active yet. Safe to ship the header first.

### After running the SQL policy

Smoke-test in Customer app:

1. App starts (no crash on missing `SUPABASE_APP_SECRET`).
2. Login / session restore.
3. Read data (e.g. profile, restaurants, cart).
4. Write data (e.g. create order / ride request).
5. Realtime (if used): listen for order/ride updates.

If anything returns empty data or `42501` / RLS / permission errors:

- Secret mismatch (Customer ≠ Partner ≠ SQL).
- Typo in header name (`X-App-Secret` vs `x-app-secret` is usually fine for HTTP, but keep `x-app-secret`).
- A code path that does not use `Supabase.instance.client`.
- `.env` not loaded / not listed in `pubspec.yaml` assets.

---

## Partner reference (already done)

Partner app wires it like this in `lib/main.dart`:

```dart
await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
  headers: {
    'x-app-secret': supabaseAppSecret, // from dotenv SUPABASE_APP_SECRET
  },
);
```

Env key name: `SUPABASE_APP_SECRET`  
Header name: `x-app-secret`

---

## Security note (honest)

This header secret stops casual public anon access (browser / Postman without the header). It is **not** strong security: the value ships inside the app binary and can be extracted. Long-term: real Supabase Auth + table policies per user/role. Short-term: shared `x-app-secret` is enough to align Customer with Partner after the policy script.

---

## Checklist for Customer app PR

- [ ] `SUPABASE_APP_SECRET` added to local `.env` (same value as Partner)
- [ ] `.env.example` updated with placeholder key
- [ ] `.gitignore` ignores `.env`
- [ ] `dotenv.load` runs before `Supabase.initialize`
- [ ] `headers: {'x-app-secret': ...}` set on initialize
- [ ] No second Supabase client without headers
- [ ] Smoke tests pass after RLS SQL is applied on Supabase
