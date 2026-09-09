# Releasing AgentBar

One command does the whole release. This page explains what it does and what to check.

## TL;DR

```bash
# 1. CHANGELOG.md has notes under "## [Unreleased]"; everything is committed on main.
# 2. Validate (builds, signs, notarizes into dist/, changes nothing else):
make release-dry VERSION=1.2.3
# 3. Ship:
make release VERSION=1.2.3
```

## What `scripts/release.sh` does

| Step | Action | Files touched |
|------|--------|---------------|
| 1 | Pre-flight: tools, Sparkle key in the Keychain and matching `SUPublicEDKey`, notary profile, clean tree on `main`, tag free, changelog has notes | – |
| 2 | Set `MARKETING_VERSION`, bump `CURRENT_PROJECT_VERSION`, regenerate the project | `project.yml` |
| 3 | Move `## [Unreleased]` entries under `## [X.Y.Z] - date`, update the compare links | `CHANGELOG.md` |
| 4 | Release build with `CODE_SIGNING_ALLOWED=NO`, then `scripts/sign-app.sh` with the Developer ID certificate (Sparkle components individually, hardened runtime, timestamp) | – |
| 5 | Zip app + `install.txt` with `ditto`, notarize with `notarytool`, staple the ticket, re-zip | `dist/` |
| 6 | Name the download: `https://github.com/aliyar/AgentBar/releases/download/vX.Y.Z/AgentBar-X.Y.Z.zip`, uploaded in step 8 | – |
| 7 | `sign_update --account agentbar`, write the appcast into `dist/` (keeps 5 items), write `site/app/release.ts`, build the site | `dist/appcast.xml`, `site/app/release.ts` |
| 8 | `git commit -m "Release X.Y.Z"`, annotated tag `vX.Y.Z`, push, `gh release create` with the zip and the appcast attached | GitHub |

Nothing binary goes into the repository: the zip and the feed are release assets, and Sparkle
reads `https://github.com/aliyar/AgentBar/releases/latest/download/appcast.xml`, which always
resolves to the newest release. Render redeploys the site on the push to `main`; installed
apps see the update on their next daily check or through **Check for Updates…** in Settings.

### Options

| Flag | Effect |
|------|--------|
| `--dry-run` | Steps 1, 4, 5 into `dist/`; the version bump is reverted on exit |
| `--no-publish` | Commit and tag locally, do not push or create the GitHub release |
| `--allow-dirty` | Skip the clean-working-tree check |
| `--notes FILE` | Use `FILE` as release notes instead of the changelog |
| `--adhoc` | Ad-hoc signing, no notarization (macOS will refuse the download on first launch) |

## Requirements on the release machine

- Xcode, xcodegen, Node.js, `gh` (authenticated), `xmllint`.
- The **Developer ID Application** certificate in the login Keychain (shared by the family).
- A notarytool keychain profile, its name in `.notary-profile` (gitignored):
  ```bash
  xcrun notarytool store-credentials <name> --apple-id <apple-id> --team-id RCQFGHVGQJ
  echo <name> > .notary-profile
  ```
- The Sparkle EdDSA private key in the login Keychain under account **`agentbar`**. The
  Keychain also holds the sibling apps' keys, so **always pass `--account agentbar`**:
  ```bash
  SPARKLE_BIN=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
  $SPARKLE_BIN/generate_keys --account agentbar          # once; prints the public key
  $SPARKLE_BIN/generate_keys --account agentbar -p       # public key again, later
  $SPARKLE_BIN/generate_keys --account agentbar -x FILE  # back the private key up, once, off this Mac
  ```
  Paste the public key into `SUPublicEDKey` in `project.yml`. Losing the private key strands
  every installed copy: the app rejects updates signed with any other key.
- Nothing else. The download host is GitHub: `gh` is already required above, and the zip
  and the appcast are attached to the release it creates.

## Version policy

Semantic versions, `X.Y.Z`. `CURRENT_PROJECT_VERSION` is a plain counter Sparkle compares;
the script bumps it by one on every release and it must never go backwards.

## Testing a build locally before shipping

```bash
make release-dry VERSION=1.2.3       # dist/AgentBar-1.2.3.zip, notarized if the profile exists
scripts/install-local.sh --app <unzipped .app>
```

`install-local.sh` keeps a Developer ID signature and its stapled ticket; it only re-signs
ad-hoc builds. To test the update flow, serve `site/out` locally and point the app at it:
`defaults write com.greatpixels.AgentBar UpdateFeedURL http://localhost:8000/appcast.xml`, with
`dist/appcast.xml` served from that directory.

## If something goes wrong

- **Notarization rejected**: `xcrun notarytool log <submission-id> --keychain-profile <name>`.
  The usual causes are a missing timestamp or hardened runtime (sign-app.sh checks both) and a
  `get-task-allow` entitlement from a Debug build.
- **Sparkle refuses the update on an installed copy**: the zip was signed with a different key
  than the one in `SUPublicEDKey`, or the appcast points at a zip that was re-zipped after
  signing. Both are checked by the script; if they slipped through, cut a new patch release.
- **The script died after the version bump**: `git checkout project.yml CHANGELOG.md` and
  `make generate`; nothing else was changed before step 6.
- **Render did not redeploy**: the build filter only fires for `site/**` and `render.yaml`;
  the release commit touches `site/`, so check the Render dashboard for a failed build.

## Checking a published build

```bash
curl -sL https://github.com/aliyar/AgentBar/releases/latest/download/appcast.xml | head -20
spctl -a -vv /Applications/AgentBar.app     # "accepted, source=Notarized Developer ID"
```
