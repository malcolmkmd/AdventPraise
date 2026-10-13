# Fastlane status

Branch `fastlane`, merged into `main`. Not pushed.

## Done

- `Gemfile` pins fastlane 2.241.0 (`Gemfile.lock` committed). Gems install to `vendor/bundle` (gitignored).
- `fastlane/Appfile`: `com.mDev.Advent-Praise`, team `B534EWRJTS`.
- `fastlane/Fastfile` lanes (details in the README's Fastlane section):
  - `beta`: clean git tree, then `latest_testflight_build_number + 1`, a Release archive with automatic signing and `-allowProvisioningUpdates`, and an upload to TestFlight with `distribute_external: false`, `skip_waiting_for_build_processing: true`, and "What to Test" filled from the last 15 non-merge commit subjects.
  - `build_only`: same archive and App Store export, no upload. Output goes to `build/fastlane/`.
  - `device`: Debug build for a connected iPhone, then `devicectl` install and launch.
- `scripts/beta.sh` forces a UTF-8 locale, checks the ASC env vars for `beta`, runs `bundle install` if needed, then runs the lane.
- `.gitignore` now covers `*.p8`, `fastlane/.env*`, `.bundle/`, `vendor/bundle/` and the generated `fastlane/README.md`.

## Verified

- `bundle exec fastlane ios build_only` worked on 2026-10-13 (about 3.5 min): Release archive, signed App Store `.ipa`, and dSYM zip in `build/fastlane/`.
- `build_only build_number:42` also worked. `CURRENT_PROJECT_VERSION=42` was passed to the archive. I couldn't unzip the `.ipa` in the sandbox, so its `CFBundleVersion` hasn't been checked.
- Signing for `build_only` used the Apple account signed in to Xcode. No API key was involved.
- Not run: `beta` (no upload, by design) and `device` (no iPhone attached in this session).

## Needed before the first `./scripts/beta.sh`

1. **App Store Connect API key.** The sandbox blocked reads outside the repo, so I couldn't check whether `~/.appstoreconnect/private_keys/` or another repo's fastlane folder (for example Klippa) already has a key. Run
   `ls ~/.appstoreconnect/private_keys/ ~/Development/*/fastlane/.env 2>/dev/null`.
   A team key from another app works if its role is App Manager or higher. If there isn't one, create it under App Store Connect > Users and Access > Integrations.
2. **Point the env vars at it** in `fastlane/.env` (gitignored) or your shell: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`. Keep the `.p8` outside the repo.
3. **App record.** The app `com.mDev.Advent-Praise` must exist in App Store Connect. If TestFlight has no builds for version 7.0 yet, the lane starts from build 1.
4. **Internal testing group** with automatic distribution, so internal testers get each build once processing finishes. The lane never sends builds to external groups.
5. **Export compliance** is already handled: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` is set, so builds won't wait on the encryption question.
6. **Clean tree.** `beta` refuses to run with uncommitted changes.

## Notes

- The build number is set at archive time. The project keeps `CURRENT_PROJECT_VERSION = 1` and `MARKETING_VERSION = 7.0`, so a release leaves nothing to commit.
- fastlane suggests `xcbeautify` instead of `xcpretty`. `brew install xcbeautify` makes it pick that up. Optional.
