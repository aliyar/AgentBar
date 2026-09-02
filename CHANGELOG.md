# Changelog

All notable changes to AgentBar are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

Add entries under **Unreleased** as you work; `scripts/release.sh` moves them under the new
version heading and uses them as the release notes.

## [Unreleased]

### Added
- The app: a menu bar item, a popover, and a Settings window with the update controls.
- **The popover shows what the coding agents on this Mac are doing.** For Claude Code and
  Codex: every rate-limit window as a meter that fills as you spend, the percentage, and
  how long until it starts over; and the conversations running right now, named by what
  was last said in them, with a pulsing dot while one is working and how full its context
  is. Clicking a conversation brings its terminal or editor forward.
- The menu bar can show the fullest window as a percentage ("78%") instead of the symbol,
  refreshed every minute. Off by default; in Settings › General.
- Settings, laid out like System Settings with a sidebar: General (launch at login,
  appearance, the menu bar percentage, updates), Agents (which agents to show), Changelog
  (these notes, inside the app), Support and About. Back and forward buttons walk the
  panes you visited.
- **Appearance**: System, Light or Dark for the popover and the Settings window. The menu
  bar item always follows the menu bar.
- **Launch at login**, through the system's Login Items.
- Nothing is shown that cannot be stood behind: a window that has already started over
  shows "—", a figure written hours ago says how old it is, and a context whose limit is
  not written anywhere reports its tokens instead of a made-up percentage.

[Unreleased]: https://github.com/aliyar/AgentBar/compare/main...HEAD
