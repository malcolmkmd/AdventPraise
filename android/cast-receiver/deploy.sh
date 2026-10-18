#!/usr/bin/env bash
# Assembles the receiver into dist/ and deploys it to Cloudflare Pages.
#
#   ./deploy.sh              assemble dist/ and deploy (production branch)
#   ./deploy.sh --no-upload  assemble dist/ only (the harness uses it)
#
# Nothing in dist/ is committed: the MIDI files and their manifest come from
# the app's own Resources/Midi, the piano from ../shared-audio, the synth and
# the fonts from npm (package.json pins every version).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
midi="$repo/AdventPraise/Resources/Midi"
piano="$here/../shared-audio/piano.sf2"
project="advent-praise-cast"
upload=1
[[ "${1:-}" == "--no-upload" ]] && upload=0

cd "$here"
if [[ ! -d node_modules/spessasynth_lib || ! -d node_modules/esbuild ]]; then
  npm ci --no-audit --no-fund
fi

rm -rf dist
mkdir -p dist/vendor dist/fonts dist/midi dist/licenses

# The page and its one script (the synth's main-thread half bundled in).
cp src/index.html src/receiver.css dist/
npx esbuild src/main.js --bundle --format=esm --target=chrome80 --minify \
  --legal-comments=none --log-level=warning --outfile=dist/receiver.js
# The synth's AudioWorklet half, as published.
cp node_modules/spessasynth_lib/dist/spessasynth_processor.min.js dist/vendor/

# Shared data, never copied into git.
cp "$midi"/*.mid "$midi"/midi-manifest.json dist/midi/
cp "$piano" dist/piano.sf2

# Faces (OFL): New York -> Source Serif 4, SF -> Inter, Avenir Next -> Nunito Sans.
fs=node_modules/@fontsource
cp "$fs/source-serif-4/files/source-serif-4-latin-600-normal.woff2" dist/fonts/serif-600.woff2
cp "$fs/inter/files/inter-latin-700-normal.woff2" dist/fonts/sans-700.woff2
cp "$fs/nunito-sans/files/nunito-sans-latin-700-italic.woff2" dist/fonts/chorus-700-italic.woff2

# Licences of everything served.
cp ../shared-audio/LICENSE-FluidR3.txt dist/licenses/
cp node_modules/spessasynth_lib/LICENSE dist/licenses/spessasynth_lib-LICENSE.txt
cp node_modules/spessasynth_core/LICENSE dist/licenses/spessasynth_core-LICENSE.txt
cp "$fs/source-serif-4/LICENSE" dist/licenses/SourceSerif4-OFL.txt
cp "$fs/inter/LICENSE" dist/licenses/Inter-OFL.txt
cp "$fs/nunito-sans/LICENSE" dist/licenses/NunitoSans-OFL.txt

# Cloudflare Pages: the MIDI files and the piano change only with a deploy.
cat > dist/_headers <<'EOF'
/midi/*
  Cache-Control: public, max-age=3600
/piano.sf2
  Cache-Control: public, max-age=86400
/fonts/*
  Cache-Control: public, max-age=31536000, immutable
EOF

js=$(wc -c < dist/receiver.js | tr -d ' ')
worklet=$(wc -c < dist/vendor/spessasynth_processor.min.js | tr -d ' ')
total=$(du -sk dist | cut -f1)
echo "dist/: receiver.js ${js} B, worklet ${worklet} B, $(ls dist/midi/*.mid | wc -l | tr -d ' ') MIDI files, ${total} KB in all"

if [[ $upload == 1 ]]; then
  npx wrangler pages deploy dist --project-name "$project" --branch main --commit-dirty=true
fi
