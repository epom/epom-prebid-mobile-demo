# Epom + Prebid Mobile — reference apps

Two small apps, one iOS and one Android, that sell in-app inventory through **Epom Ad Server** using
header bidding. Each opens on a menu of nine formats — a Prebid-rendered banner, in-banner video,
native, a full-screen interstitial (video and image), a playable, a rewarded video, and two banners
handed to Google to render — plus a Settings screen for pointing the app at your own server without
rebuilding it.

They are meant to be read as much as run: the code for each format is one short method, and copying
that method into your own app is the whole integration.

**They ship pointed at a live server.** The defaults are Epom's own Prebid Server (`pbs.eashb.com`)
and a test network, so a fresh clone fills on the first launch with nothing to configure. Point them
at your own once you have seen it work.

## What is actually going on

**There is no Epom SDK in these apps, and there does not need to be.** Epom is reached server side,
as a bidder, by the `epom_as` adapter inside Prebid Server. The app only ever talks to two things:

```
   your app
      │
      ├── Prebid Mobile SDK ──► Prebid Server ──► epom_as adapter ──► your Epom deployment
      │                                        └─► other bidders
      │        returns a bid and targeting keys, not (usually) a creative
      │
      └── Google Mobile Ads SDK  ──► Google Ad Manager / AdMob
               renders whichever wins: the Prebid bid, or Google's own demand
```

Two different integrations live in these apps, and the menu is split between them:

- **Prebid renders** (the first seven screens). The Prebid Mobile *rendering API* fetches the bid
  **and draws the winning creative itself** — banner, video, native, full-screen, rewarded. No
  Google, no line items; these fill the moment the slot ids are right.
- **Google renders** (the last two). The *original API* fetches a bid and writes its price into a
  Google ad request as key-value targeting. Google then decides: if a line item matches those keys
  and beats its own demand, the Prebid creative renders; otherwise Google serves its own. Google is
  not a "fallback" here — it is the ad server, and Prebid is one more source of demand inside it.

## Quick start

```bash
# iOS — needs XcodeGen (brew install xcodegen)
cd ios && xcodegen generate && open EpomPrebidDemo.xcodeproj      # ⌘R

# Android — needs the SDK path in local.properties
echo "sdk.dir=$HOME/Library/Android/sdk" > android/local.properties
cd android && ./gradlew :app:installDebug
```

Open any of the first seven screens and an ad fills. The two green "Google renders" screens stay
empty until you set up line items — that is expected, and the section below says why.

## Everything you have to change

One file per platform, and nothing outside it:

| | |
|---|---|
| iOS | `ios/EpomPrebidDemo/Config.swift` |
| Android | `android/app/src/main/res/values/strings.xml` |

Each holds the same values, and each ships filled in with the live demo server so you can see it work
before changing anything. **You do not have to rebuild to change them:** the Settings screen, reached
from the menu, writes over every value on the device and survives a restart; *Reset* puts the
built-in ones back. The one exception is the Google **application id** — the Mobile Ads SDK reads it
while the app starts, before any of this app's code runs, so it can only be set at build time.

| | What it is |
|---|---|
| **Prebid Server URL + account id** | Where the auction runs. The defaults are `https://pbs.eashb.com/openrtb2/auction` and the `n2494` test network. Include the full path. On an Android emulator the host machine is `10.0.2.2`, not `localhost`. |
| **The `configId`s** — one per slot | **Not** an Epom placement key. See below — this is the part everyone gets wrong. |
| **Google application id + two ad unit ids** | Only for the two Google-rendered screens. |

### The part everyone gets wrong: `configId` is a server-side id

Unlike Prebid.js, **Prebid Mobile does not send bidder parameters from the app.** The SDK puts the
`configId` into `imp.ext.prebid.storedrequest.id` and stops there. Everything else — which bidders to
call and with what parameters — is resolved on the Prebid Server from a *stored request* under that
id.

So the Epom serving host and placement key never appear in the app at all. They live on the server:

```json
{
  "id": "your-stored-request-id-300x250",
  "banner": { "format": [ { "w": 300, "h": 250 } ] },
  "ext": { "prebid": { "bidder": { "epom_as": {
    "host": "ads.example.com",
    "placementKey": "the-placement-key-from-the-invocation-code-tab"
  } } } }
}
```

Put one of those per ad slot in your Prebid Server's stored-imp store, and give the app the `id`.
A full-screen slot carries **no size** — the ad fills the screen, so the SDK supplies the dimensions
and the stored request omits `banner`:

```json
{
  "id": "your-stored-request-id-rewarded",
  "ext": { "prebid": { "bidder": { "epom_as": {
    "host": "ads.example.com",
    "placementKey": "the-full-screen-placement-key"
  } } } }
}
```

Getting the id wrong is quiet: the SDK reports *"Prebid server does not recognize Config Id"* and the
slot simply never bids.

### Rewarded: the creative signals when the reward is earned

A rewarded slot is marked on the server (Epom does this per slot), which puts a `rwdd` block in the
bid that tells the SDK to hold the ad until the reward is earned and then show a close button rather
than closing on its own. A **video** counts as earned when it finishes. A **playable** counts when its
creative says so, by navigating to a fixed URL the SDK matches exactly:

```js
// in the playable's HTML, once the user has done the thing
location.href = 'epom://reward';
```

The demo's rewarded screens grant the app's own reward from `onUserEarnedReward`
(`rewardedAdUserDidEarnReward` on iOS), and say whether the bid described a reward of its own — the bid
*describes* a reward, the app *grants* it.

### One more stored request: the account

Prebid Mobile also sends the **account id** as a stored request of its own — `ext.prebid.storedrequest.id`
at the top of every bid request. Your Prebid Server needs a document filed under it, and it is worth
one thing beyond naming the account:

```json
{
  "id": "your-account-id",
  "ext": { "prebid": { "targeting": {
    "includewinners": true,
    "includebidderkeys": true
  } } }
}
```

**Without the `targeting` block nothing renders.** The rendering API marks a bid as the winner only
when it carries `hb_pb` and `hb_bidder`, and Prebid Server writes those only when the request asks for
them. Putting the flags on the account means every request gets them and an unmodified app renders;
the alternative is setting `includeWinners` / `includeBidderKeys` on the SDK in each app.

You also need the `epom_as` bidder enabled in whichever Prebid Server you point at, a **Prebid Cache**
configured (the rendering API caches creatives for display — without it a good bid answers *"no
winning bid in the bid response"*), and, for the two Google screens, a line item keyed on Prebid's
targeting.

### Which screens need which

| Screen | Renders | Needs a Google ad unit | Needs a line item |
|---|---|---|---|
| MREC 300x250 — Prebid renders | Prebid | no | no |
| In-banner video | Prebid | no | no |
| Native | Prebid | no | no |
| Interstitial video | Prebid | no | no |
| Interstitial image | Prebid | no | no |
| Playable | Prebid | no | no |
| Rewarded video | Prebid | no | no |
| MREC 300x250 — Google renders | Google | yes | yes |
| Mobile banner 320x50 | Google | yes | yes |

If the two Google screens stay empty while the others fill, the app is working and the Google line
items are what is missing.

## How the project is laid out

Each platform is one thin app over its SDK. The files worth reading:

| iOS | Android | What it is |
|---|---|---|
| `Format.swift` | `Format.kt` | The nine screens: title, what each asks for, which `configId` carries it |
| `AdViewController.swift` | `AdActivity.kt` | One short method per format — this is the integration |
| `Config.swift` | `res/values/strings.xml` | The one file you edit |
| `Settings.swift` | `Settings.kt` | On-device overrides, so you needn't rebuild to repoint the app |

The iOS project file is generated from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), so the repository holds a
readable manifest instead of a thousand lines of `pbxproj`.

## Things that will bite you

**Start the ad slots only after the Prebid SDK reports it is initialised.** `initializeSdk` is
asynchronous; an ad unit built before it finishes sends its request and never receives the answer, so
the network traffic looks perfect while the screen stays empty. Do not hang the load off that callback
alone either — it fires once per process, so a recreated activity would show nothing. Both paths are
in `AdActivity` / `AppDelegate`.

**A full-screen creative has no size, but the rendering API still wants one it can scale to.** The
stored request omits `banner`; the SDK sends the screen size. On the server side a fixed-size creative
(a 300×250 image on a full-screen slot) must not be size-matched out — it is scaled to fill. Epom's
`epom_as` path handles this for Non-standard placements.

**The sample Google ad unit in most tutorials is dead.** `/6499/example/banner` appears in every older
Google guide and returns nothing but no-fill (`Ad failed to load : 3`). Use
`/21775744923/example/adaptive-banner`.

**iOS uploads are rejected without a privacy manifest.** App Store Connect checks for one before a
human ever sees the build — TestFlight included — so `PrivacyInfo.xcprivacy` ships here. It declares
what this app's own code does and nothing more: the SDKs carry their own, and Xcode merges them into
the privacy report. Its `NSPrivacyTrackingDomains` is deliberately empty, because the server this app
talks to is chosen per install. In an app of your own, fill it carefully — iOS blocks every domain
listed there while tracking is denied, so an ad server named in it stops answering for anyone who
declines the prompt.

**Two things App Store Connect asks for that are already answered here.** `ITSAppUsesNonExemptEncryption`
is set to false — true, and it stops the export-compliance question appearing on every upload — and
`DEVELOPMENT_TEAM` is an empty slot in `project.yml`: put your Apple Developer Team ID in it, or pick
the team once in Xcode under Signing & Capabilities. The bundle id the project builds is
`com.epom.EpomPrebidDemo`; register that identifier before creating the app record, because App Store
Connect will not let you type one it has never seen.

**On the Android emulator the host is `10.0.2.2`, not `localhost`**, and a local HTTP server needs
`android:usesCleartextTraffic="true"` in the manifest — deliberately not committed here.

**Kotlin 2.3.0 or newer.** `play-services-ads` 25.x ships metadata compiled with Kotlin 2.3, and an
older Kotlin plugin fails the build with *"Module was compiled with an incompatible version of
Kotlin"* pointing at Google's jar. It reads like a Prebid problem and is not one.

**`AD_ID` permission on Android.** Without
`<uses-permission android:name="com.google.android.gms.permission.AD_ID" />` Google Play Services
withholds the advertising id, and every server-side frequency cap silently stops applying.

**The ATT prompt on iOS.** It cannot be shown before the first frame, which is why it is requested in
`applicationDidBecomeActive` rather than at launch. Declining is not a failure: iOS returns an
all-zero advertising id, the SDK sends the vendor id (`device.ext.ifv`) in its place, and capping
keeps working on that instead.

**Both SDKs export a `BannerView`.** Swift refuses to choose and fails with *"ambiguous for type
lookup"*. Qualify Google's with the module: `GoogleMobileAds.BannerView`.

**`findPrebidCreativeSize` after a Google-rendered ad loads.** Google renders a Prebid winner in a
frame sized for the *line item*, not for the creative. Skip this call and a 300×250 arrives in a
320×50 hole, cropped. Both apps call it in their Google load callback.

## Licence

[Apache 2.0](LICENSE), same as Prebid Mobile.
