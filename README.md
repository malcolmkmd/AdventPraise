# AdventPraise

iOS hymnal app. Bundle ID `com.mDev.Advent-Praise`, team `B534EWRJTS`.

The Android app is its own repo, [malcolmkmd/AdventPraise-Android](https://github.com/malcolmkmd/AdventPraise-Android).
It reads the hymnals, MIDI, sheet music and `legal/` from this repo, so check the two out side by side:

```
AdventPraise-build/
  AdventPraise/            this repo (iOS, and the source of truth for the data)
  AdventPraise-Android/    the Android app
```

## Fastlane (internal TestFlight builds)

One-time setup:

```sh
bundle config set --local path vendor/bundle   # keep gems inside the repo (gitignored)
bundle install
```

### App Store Connect API key

The `beta` lane signs in to App Store Connect with an API key from three env vars.
Keys are **never** committed (`*.p8` and `fastlane/.env*` are gitignored).

| Variable        | Value                                                        |
| --------------- | ------------------------------------------------------------ |
| `ASC_KEY_ID`    | Key ID, e.g. `ABC123DEFG`                                    |
| `ASC_ISSUER_ID` | Issuer ID (UUID at the top of the Integrations > Keys page)  |
| `ASC_KEY_PATH`  | Path to the `.p8`, e.g. `~/.appstoreconnect/private_keys/AuthKey_ABC123DEFG.p8` |

Either export them in your shell or put them in `fastlane/.env`, which fastlane loads automatically:

```sh
ASC_KEY_ID=ABC123DEFG
ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_ABC123DEFG.p8
```

Create a key at App Store Connect > Users and Access > Integrations > App Store Connect API
(role **App Manager** or higher). A team key used by another app on this account works too.

### Lanes

| Command                                  | What it does |
| ---------------------------------------- | ------------ |
| `./scripts/beta.sh`                      | `beta`: requires a clean git tree, sets the build number to the latest TestFlight build + 1, archives Release with automatic signing, and uploads to TestFlight for **internal testers only**. "What to Test" is filled from recent commit subjects. Returns as soon as the build appears in App Store Connect, without waiting for processing to finish. |
| `./scripts/beta.sh build_only`           | `build_only`: same Release archive and App Store `.ipa` export, with no upload. Output goes to `build/fastlane/`. Pass `build_number:42` to stamp a number. |
| `./scripts/beta.sh device`               | `device`: builds Debug for the first paired, connected iPhone, then installs and launches it with `devicectl`. Pass `device:<UDID or name>` or `configuration:Release` to override. |

The build number is passed as `CURRENT_PROJECT_VERSION` at archive time, so the
project file stays unchanged and nothing needs committing after a release. The marketing version
(`MARKETING_VERSION`, currently 7.0) is still set in Xcode.
