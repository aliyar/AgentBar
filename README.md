<p align="center">
  <img src="docs/icon.png" alt="AgentBar icon" width="128" height="128">
</p>

<h1 align="center">AgentBar</h1>

<p align="center">
  What the coding agents on this Mac are doing, and how much of their quota is left —
  in the menu bar, in the Dock, and as a macOS widget.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-111111?logo=apple" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/built%20with-SwiftUI%20%2B%20AppKit-orange" alt="SwiftUI and AppKit">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT license">
</p>

AgentBar reads what Claude Code and Codex leave on this Mac — the rate-limit windows, the
sessions that are running right now — and shows it where you glance anyway: a percentage in the
menu bar, a popover with a meter per window and a row per conversation, an optional Dock window,
and a widget for Notification Center and the desktop. No account is contacted, no credential is
ever seen, and nothing leaves the machine.

Website: [agentbar.greatpixels.com](https://agentbar.greatpixels.com)

## Status

Early. The skeleton builds and shows a menu bar item; the readers, the popover, the widget and
the Dock window follow, in that order. See [CHANGELOG.md](CHANGELOG.md).

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
