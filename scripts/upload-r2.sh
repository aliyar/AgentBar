#!/bin/bash
#
# Upload a release zip to the family-wide download host (Cloudflare R2, free tier).
#
#   scripts/upload-r2.sh dist/AgentBar-1.2.3.zip
#
# Objects land at <bucket>/agentbar/<file>, served at https://dl.greatpixels.com/agentbar/<file>.
# One bucket serves all three apps once they move. Needs `wrangler` logged in
# (`npx wrangler login`) and R2_BUCKET set (or the default below).
#
set -euo pipefail
ZIP="${1:-}"
[ -f "$ZIP" ] || { echo "Usage: $0 <zip>" >&2; exit 1; }
R2_BUCKET="${R2_BUCKET:-greatpixels-downloads}"
R2_PREFIX="${R2_PREFIX:-agentbar}"
KEY="$R2_PREFIX/$(basename "$ZIP")"
npx --yes wrangler r2 object put "$R2_BUCKET/$KEY" --file "$ZIP" --content-type application/zip --remote
echo "https://dl.greatpixels.com/$KEY"
