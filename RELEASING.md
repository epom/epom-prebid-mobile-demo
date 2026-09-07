# Handing the apps to testers

These are reference apps, not products: they exist so a publisher can see the integration work and
copy a method out of it. That decides how they are distributed — **TestFlight on iOS and a Play
testing track on Android**, not the public stores.

It is worth knowing why, because it saves an argument later. Apple's Guideline 4.2 refuses apps
whose only function is to demonstrate something; a menu of nine "show me an ad" buttons is exactly
what that rule was written for. Beta App Review does not apply it the same way, and Google's testing
tracks do not apply it at all. So the route below is the one that ends in testers' hands rather than
in a rejection.

Both platforms need a paid account first: Apple Developer Program, $99 a year, and Google Play, $25
once. Nothing below works until those exist.

---

## Android — Play internal testing

**1. Build a signed bundle.** Play refuses an unsigned one even on an internal track.

```bash
keytool -genkey -v -keystore epom-demo-upload.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias upload
cp android/keystore.properties.example android/keystore.properties   # then fill it in
cd android && ./gradlew bundleRelease
```

The bundle lands in `android/app/build/outputs/bundle/release/app-release.aab`. Keep the `.jks` and
its passwords somewhere you will still have them in two years — Play ties the app to that key.

**2. Create the app** in Play Console → Create app. Name it, pick App / Free, accept the
declarations. The package name comes from the bundle you upload: `com.epom.prebiddemo`.

**3. Fill in App content.** Play will not release to any track until this is done, and it is the
part that takes the time rather than the build:

* Privacy policy — <https://epom.com/privacy-policy>
* Ads — yes, the app shows ads
* Data safety — the app declares `com.google.android.gms.permission.AD_ID`, so declare that an
  advertising ID is collected, and say it is used for advertising and analytics
* Content rating questionnaire, target audience (18+ keeps it simple), news, government apps

**4. Upload.** Testing → Internal testing → Create new release → drop the `.aab` in. No review, it
is available in minutes.

**5. Add testers.** Internal testing takes up to 100 email addresses, either typed in or as a Google
Group. Copy the join link from the Testers tab and send it. A tester opens the link, accepts, and
installs from Play like any other app.

Later releases only need step 1 and step 4 — and `versionCode` must go up every time.

---

## iOS — TestFlight

**1. Register the bundle id.** developer.apple.com → Certificates, Identifiers & Profiles →
Identifiers → **+** → App IDs → App. Use `com.epom.EpomPrebidDemo`, the id the project builds. App
Store Connect will not let you type an identifier it has never seen.

**2. Create the app record.** appstoreconnect.apple.com → Apps → **+** → New App. iOS, a name, a
primary language, that bundle id, and an SKU of your choosing (any string; it is never shown).

**3. Point the project at your team.** Either put your Team ID in `DEVELOPMENT_TEAM` in
`ios/project.yml` and regenerate with `xcodegen generate`, or open the project and pick the team once
under Signing & Capabilities.

**4. Archive and upload.** In Xcode: Product → Archive → Distribute App → App Store Connect →
Upload. The build takes a few minutes to process; you get an email when it is ready.

Two things are already answered in the repository so the upload is not bounced:
`PrivacyInfo.xcprivacy` (App Store Connect rejects a build without one, TestFlight included) and
`ITSAppUsesNonExemptEncryption`, which otherwise asks about export compliance on every upload.

**5. Hand it out.** In App Store Connect → TestFlight:

* *Internal testers* — up to 100 people on your team, no review, available as soon as the build
  finishes processing.
* *External testers* — up to 10,000, and a public link you can put anywhere. This goes through Beta
  App Review, usually a day. Guideline 4.2 is not applied here the way it is for the store.

Later releases need a new `CFBundleVersion` every time: Apple refuses a build number it has already
seen.

---

## What testers will see

The eight Prebid-rendered screens fill immediately against the demo network the apps ship pointed
at. The two Google-rendered ones are hidden until an ad unit is named in Settings — see the README.
Nothing in Settings needs touching for the app to work; it is there so a publisher can point the
same build at their own server without a rebuild.
