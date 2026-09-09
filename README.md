<p align="center">
  <img src="docs/icon.png" alt="AgentBar icon" width="128" height="128">
</p>

<h1 align="center">AgentBar</h1>

<p align="center">
  What the coding agents on this Mac are doing, and how much of their quota is left:
  in the menu bar, in the Dock, and as a macOS widget.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-111111?logo=apple" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/built%20with-SwiftUI%20%2B%20AppKit-orange" alt="SwiftUI and AppKit">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT license">
</p>

AgentBar reads what Claude Code, Codex and Cursor leave on this Mac (the rate-limit windows and the
sessions that are running right now) and shows it where you glance anyway: a percentage in the
menu bar, a popover with a meter per window and a row per conversation, an optional Dock window,
and a widget for Notification Center and the desktop. It also watches each agent's own status
page, and tells you when a service stops working and when it starts again.

Three kinds of request leave the Mac, and nothing else does: each agent's account is asked how
much of its quota is left, using the sign-in that agent already keeps here; each agent's public
status page is read; and Sparkle checks for an update. Update checks and the status pages each
have a switch of their own, and an agent you turn off is neither read nor asked about. No
credential is stored or logged, and what the agents write on disk never leaves it.

Website: [agentbar.greatpixels.com](https://agentbar.greatpixels.com)

## Project status

Shipping. The menu bar item, the panel, the Dock window and the widget are all in, for Claude
Code, Codex and Cursor. See [CHANGELOG.md](CHANGELOG.md) for what each release brought.

## Install

Download the latest zip from the website, unzip, drag **AgentBar.app** to Applications and open
it. Builds are signed with a Developer ID certificate and notarized; the app updates itself.

Requires macOS 14 or later.

## Development

```bash
make run     # generate the Xcode project, build Debug, relaunch the app
make test    # AgentBarKit package tests (swift test) + app tests (xcodebuild)
make help    # every target
```

Prerequisites: Xcode, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`),
Node.js for the site. The Xcode project is generated from `project.yml` and not committed.
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) has the layout and the conventions;
[docs/RELEASING.md](docs/RELEASING.md) has the release pipeline.

The repository also holds the product website in [`site/`](site/).

## License

[MIT](LICENSE).
