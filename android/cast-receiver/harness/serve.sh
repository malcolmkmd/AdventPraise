#!/usr/bin/env bash
# Assembles dist/ and serves the worktree root, so the harness can read the
# app's hymnals next to the receiver. Open the printed URL in Chrome.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
port="${PORT:-8787}"
"$here/deploy.sh" --no-upload
echo "Harness: http://127.0.0.1:$port/android/cast-receiver/harness/index.html"
exec python3 -m http.server "$port" --bind 127.0.0.1 --directory "$here/../.."
