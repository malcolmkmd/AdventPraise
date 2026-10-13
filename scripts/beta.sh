#!/usr/bin/env bash
# Ship an internal TestFlight build: ./scripts/beta.sh
# Any other lane works too: ./scripts/beta.sh build_only | device [device:<UDID>]
set -euo pipefail

cd "$(dirname "$0")/.."

# fastlane warns (and xcpretty can misbehave) without a UTF-8 locale.
export LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}"

lane="${1:-beta}"
shift || true

if [[ "$lane" == "beta" ]]; then
  for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
    # fastlane/.env (gitignored) is loaded by fastlane itself, so only warn here.
    if [[ -z "${!var:-}" ]] && ! grep -qs "^${var}=" fastlane/.env; then
      echo "error: $var is not set (export it or add it to fastlane/.env)" >&2
      exit 1
    fi
  done
fi

bundle check >/dev/null 2>&1 || bundle install
exec bundle exec fastlane ios "$lane" "$@"
