# BullkySMS — Code Review

**Reviewed:** 27 August 2026 · **Version:** 3.0.1+2 · **Package:** `au.com.bullkysms`
**Scope:** all 24 Dart files in `lib/`, the Android manifest and Gradle config, and the two plugins the send path depends on.

Every finding below was verified against source, including reading the GetX and `flutter_foreground_task` package internals in the pub cache. Where my first reading was wrong, I've said so.

---

## 1. What the app is

BullkySMS turns a company handset into an SMS gateway. The server queues campaign messages, the phone collects them and sends them over its own SIM, then reports back what went out. Inbound SMS and missed calls travel the other way, so the server can see replies.

That framing matters more than it sounds. This isn't a consumer app that a person opens — it's unattended infrastructure that happens to be written in Flutter. It has to keep working when nobody is looking at the screen, after the phone reboots, and across days at a time. Most of the serious problems below are cases where the code implicitly assumes a human is present with the app in the foreground.

## 2. How it's built

The stack is Flutter with GetX for state and navigation, and a `part` / `part of` file layout: each feature has a `*_bin.dart` library root that the controller (`*_con.dart`) and screen (`*_scr.dart`) attach to. There are three screens — splash, login, homepage — and essentially all real logic lives in one place, `lib/presentation/homepage/homepage_con.dart`, at roughly 1,050 lines.

The API convention is consistent and easy to follow: every call is a flat JSON POST to `serverUrl + page`, discriminated by a `DocType` field (`SignIn`, `GetSMS`, `UpdateSMS`, `ReceivedSMS`), with `UserName` / `Password` / `Mobile` / `Token` / `ClientMobID` repeated on every request. Errors come back as `DocType: "Error"`. There's no session token — the password is re-sent each time.

### The outbound pipeline

Something triggers `HomepageCon.resolveAndStartPipeline()` — an FCM push, a 5-second connectivity poll, or the manual refresh button. That method first tries to flush any sends from a previous run that were never acknowledged by the server, and deliberately refuses to fetch new work until that succeeds. Then it loops: `smsGet` fetches a batch, each message goes out through `sms_sender_background` on SIM slot 0 with about 1.2 seconds of spacing, and `sms_update` acknowledges the batch. After each individual send, the running list of sent messages is written to `SharedPreferences` so a crash mid-batch doesn't lose the record.

There are two variants of this loop — an instance version that updates the reactive UI counters, and a static "headless" version used when no controller exists. They're near-duplicates of each other.

### The inbound pipeline

`ReceivedEventQueue` collects incoming SMS (via `another_telephony`, with a background receiver) and missed calls (via `phone_state`), deduplicates them against a capped list of processed IDs, persists them to disk, and batches them to `sms_received`.

### What's genuinely good here

The failover design around acknowledgement is the strongest part of the codebase, and it's the right instinct: sends are persisted to disk *before* the server is told, the pipeline blocks on unresolved acknowledgements rather than charging ahead, and retries use exponential backoff. That's the correct shape for at-least-once delivery. Several of the bugs below are cases where that good design is undermined by a detail elsewhere, which is a much better position to be in than not having the design at all.

The concurrency guards (`_isFlushing`, `_isCheckingInternet`, `isServerSmsSending`) are applied consistently. The SIM-data fetch retries rather than assuming readiness. The internet check verifies an actual HTTP response instead of trusting the connectivity interface, which is the distinction most apps get wrong. And the code is genuinely readable — the section banners and comments explaining *why* ("per your policy", the note about `state.number` being unreliable at `CALL_ENDED`) are more than most projects have.

## 3. Critical — the gateway is silently not doing its job

These three are the reason a healthy-looking install can send far less than expected. All three fail invisibly: no crash, no error, nothing in the UI.

### 3.1 The FCM background isolate has no credentials

`Constants` is a class of plain `static` fields, populated during login. An FCM background handler runs in a **separate Dart isolate with its own memory** — it does not see the main isolate's statics. So inside `firebaseMessagingBackgroundHandler`, `Constants.email`, `.password`, `.mobile`, `.appToken` and `.clientMobID` are all empty strings.

The chain is: push arrives → `resolveAndStartPipeline()` → controller isn't registered in this isolate → `_headlessPipeline()` → `smsGet()` POSTs blank credentials → server returns `DocType: "Error"` → `null` → loop breaks immediately.

**The entire app-killed send path is dead.** Every background push does nothing. Notably, `SQLite.getValue` and `updateValue` already exist in `lib/utils/db.dart` and are never called from anywhere — they're exactly the rehydration mechanism this needs.

### 3.2 Inbound reporting can never succeed

`ReceivedEventQueue._sendEventsBatch` builds its payload with `'SMSDate': events.map((e) => e.receivedAt).toList()` — a `List<DateTime>`. `Functions.sendJson` then calls `json.encode` with no `toEncodable`, and Dart's `DateTime` has no `toJson()`. Every attempt throws `JsonUnsupportedObjectError`.

The throw is swallowed twice: once by the bare `catch` in `sendJson` (which returns a *String*), then again when `_sendEventsBatch` indexes that String as a Map. Three retries, then a quiet `return false`.

So **no received SMS or missed call has ever reached the server**. The frustrating part is that `ReceivedEvent.toJson()` already does this correctly with `toIso8601String()` — it's just only used for disk persistence, never for the API call.

There's a compounding effect. Because the flush never succeeds, `_persistMemoryQueue` accumulates events forever — and unlike the processed-ID list, which is capped at 500, this queue has no cap. Every incoming SMS re-serializes the entire history and re-attempts the whole batch with three retries. On a long-lived install that degrades into a multi-second, multi-megabyte disk write per message received.

### 3.3 Nothing runs after a reboot or swipe-away

`foreground_services.dart` is 170 lines of entirely commented-out code, and the `BullkySmsService.init()` / `start()` calls in `main.dart` and `homepage_con.dart` are commented out too. `WithForegroundTask` still wraps the Scaffold, but its own source shows it's a no-op unless a service is actually running.

Boot recovery is dead for the same reason: the plugin's `RebootReceiver` gates on an `autoRunOnBoot` flag that only `FlutterForegroundTask.init()` ever writes, so it defaults to false and returns immediately.

**And uncommenting the Dart would not be enough.** The manifest declares `com.pravera.flutter_foreground_task.service.ForegroundTaskService` — a class that does not exist in `flutter_foreground_task` 9.2.2. The real class is `...service.ForegroundService`, and the plugin's README explicitly warns not to rename it. As written, starting the service would fail to resolve the component.

What actually runs today:

| Scenario | Reality |
|---|---|
| Foreground | Everything works |
| Backgrounded, process alive | Timers run until Android freezes the process |
| **Swiped away** | Inbound SMS receiver fires but fails per 3.2; FCM fires but fails per 3.1. **No outbound SMS at all.** |
| **Rebooted** | Nothing. Dead until someone taps the icon. |

## 4. High — data loss and wrong behaviour

**Logout doesn't log out.** The logout button blanks the SQLite row and navigates away, but never resets `Constants.isLogin` or the in-memory credentials. `main.dart` still sees `isLogin == true`, so every subsequent push runs the full pipeline and dispatches **real SMS on a logged-out account**.

**Manual refresh destroys unacknowledged sends.** The refresh button calls `startServerSmsPipeline()` directly, bypassing the `resolveAndStartPipeline()` guard that exists precisely to protect pending acknowledgements. Since `_savePendingUpdates` uses `setStringList` — a full overwrite — a batch that was sent but never acknowledged is silently erased. Those messages get sent to the recipient a second time later. This one is especially unfortunate because the guard was designed correctly and is simply routed around.

**Answered calls are reported as missed.** The call listener reports on `CALL_ENDED` for any incoming call, with no check of whether it was ever answered or how long it lasted. A completed ten-minute conversation is reported to the server as `'Missed Call'`.

**A quote in a password silently breaks auto-login forever.** Credentials are written with string-interpolated `rawQuery` rather than `?` placeholders. Password and mobile are only length-checked, so a `'` character produces a malformed statement; the resulting exception is caught and discarded, the credentials never persist, and auto-login then fails silently on every launch with nothing shown to the user. (`Functions.validatePassword` exists and is never called.)

**Server error messages never reach the user.** `Functions.sendJson` returns a `String` on all four of its error paths and `null` when offline, but every call site indexes the result as a Map. Each resulting `TypeError` is swallowed, so users always see the generic "Check Internet Connection & Try again" no matter what the server actually said.

**Login can hard-fail on a valid success response.** `response["UserID"]`, `["ClientID"]`, `["SimSlotNo"]` and friends are assigned straight into `static String` fields. If the API ever returns any of them as a JSON number, the `TypeError` fires *inside the `finally` block*, so the navigation to home never runs — the user is stranded on the login screen with the spinner already cleared and no error dialog.

## 5. Security

The plaintext password is written to logcat on every inbound batch attempt, via a `developer.log` call that — unlike the ones in `homepage_con.dart` and `login_con.dart` — has no `kDebugMode` guard. It's also stored unencrypted in SQLite and re-sent on every API call. Any bug report or ADB dump harvests the account credentials.

Release builds use `signingConfig = signingConfigs.getByName("debug")`, with no minify and no resource shrinking. The APK currently on disk is actually signed with a personal self-signed certificate (`CN=Muhammad Zunair Shahzad`), meaning someone replaced their local `debug.keystore` — so the signing identity is an untracked file on one laptop. Build on any other machine or in CI and you get an APK signed with the **publicly known AOSP debug key**, which anyone can forge updates against. Play Console rejects debug-key uploads outright.

Separately, `android/build.gradle.kts` contains a `doFirst` hook that calls `writeText` on plugin manifests inside `~/.pub-cache`. That permanently rewrites shared package sources, corrupting the cache for every other Flutter project on the machine and breaking silently after any `flutter pub cache repair`.

## 6. Performance and waste

The 5-second `Timer.periodic` fires a real HTTP GET to `gstatic.com` on every tick — 17,280 requests a day, plus the radio wake-ups that implies. It's also nearly redundant: the pipeline only fires on the offline→online edge, which `onConnectivityChanged` already detects.

`_savePendingUpdates` is called inside the per-message loop with the cumulatively growing list, in both the instance and headless pipelines. A 500-message batch means 500 full-file commits and roughly 125,000 `jsonEncode` calls.

The 10-second dedupe bucket keys on message *content*, so two identical texts from the same number within ten seconds are silently discarded — plausible for OTP or "STOP" replies. And `_markProcessed` runs *before* the send, so a process death in between loses the event permanently.

Dead weight: `workmanager` is referenced only in a fully commented-out file yet still injects seven receivers and three services into the merged manifest, including its own `BOOT_COMPLETED` receiver. `flutter_sms_inbox` is referenced nowhere. `connectivity_wrapper` duplicates `connectivity_plus`, and awkwardly it's the former that gates every single API call. `lib/utils/test.dart` is 230 lines of commented-out scratch code.

## 7. Smaller items

`loadSampleData()` seeds three hardcoded real-looking Pakistani mobile numbers into the send list on every startup — that's test data living in the production path. `Constants.websiteUrl` still points at `primemedic.com.au`, left over from another project. The `live` server URL has no `api-v3/` path segment while `test` does, which looks like an oversight worth confirming. `HomepageBin` and `LoginBin` are dead code — all three routes bind `SplashBin`, and each screen calls `Get.put()` inside `build()` instead. `splash_con.dart` force-unwraps `getToken()!`, which throws whenever FCM returns null. `versionCode 2` for version 3.0.1 looks wrong. And SIM slot 0 is hardcoded throughout despite `Constants.simSlotNo` being fetched from the server at login and never used.

## 8. One correction to an earlier assumption

I initially flagged `Get.put(HomepageCon())` inside `build()` as duplicating timers and stream listeners on rebuild. Reading the GetX 4.7.3 source disproves that: `_insert` is a no-op when an instance is already registered and not dirty, and `isDirty` is only ever set on route disposal — never on a widget rebuild. So the existing instance is returned and `onInit` does not re-run. The real cost is just a throwaway controller allocated per rebuild. Still worth cleaning up, but it is not a leak, and it is not causing duplicate work.

## 9. Suggested order of work

The first three items restore function that is currently absent, and none of them are large:

1. **Rehydrate credentials from SQLite at the top of every background entry point.** Fixes 3.1 and unblocks the entire background send path. The helpers already exist.
2. **Change `'SMSDate'` to `toIso8601String()`** — or better, give `sendJson` a `toEncodable`, since this class of bug will recur. Fixes 3.2.
3. **Correct the manifest service name and re-enable the foreground service** with `autoRunOnBoot`. Fixes 3.3 and reboot recovery.

Then the correctness fixes in section 4 — logout state, the refresh bypass, and the answered-vs-missed call logic. Then parameterise the SQL and gate the credential logging. Then set up real release signing before the next Play upload.

After that it's worth talking about direction rather than defects: the 5-second poll wants to become push-driven or at least much less frequent, the two pipeline implementations want to be one, and `Constants` wants to become persisted state rather than in-memory statics — which is the root cause of both 3.1 and the logout bug, so fixing it properly closes two issues at once.
