# Changelog

All notable changes to AgentBar are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

Add entries under **Unreleased** as you work; `scripts/release.sh` moves them under the new
version heading and uses them as the release notes.

## [Unreleased]

### Added
- The app: a menu bar item, a popover, and a Settings window with the update controls.
- **The limits come from the agents' accounts**, so what was spent on another Mac or while
  the agent was not running counts too: Claude through Claude Code's sign-in, Codex through
  its ChatGPT sign-in, Cursor through the editor's. One read-only request every five
  minutes, and on the panel's refresh button; nothing is stored. What the agents write on
  disk stays the fallback.
- **Cursor** joins Claude Code and Codex: its plan's monthly usage, and its agent chats
  among the active conversations.
- **The panel shows what the coding agents on this Mac are doing.** For Claude Code and
  Codex: every rate-limit window as a meter that fills as you spend, the percentage, and
  how long until it starts over; and the conversations running right now, named by what
  was last said in them, with a pulsing dot while one is working and how full its context
  is. Clicking a conversation opens its details; clicking again brings its terminal or
  editor forward. Codex sessions are found through their running process and its rollout;
  their context is a real percentage, since Codex writes its window size.
- **The panel is glass**, in a dark and a light variant: a header with the agent and
  window count and when the files were last read; each agent's windows as rows in a
  rounded group (label, meter, percent, time left; click a time to see the clock
  time it starts over instead, or pick the default in Settings › Appearance); the running conversations with the
  agent's mark, a breathing dot while one works, its context and a chevron for the
  details; and a footer with Settings and Quit.
- The menu bar can show a gauge instead of the symbol: a small bar per window and the
  time left on one of them, in its colour. Settings › Appearance › Menu Bar chooses the
  windows shown as bars and whose time left is written (the fullest, a given window, or
  none). Off by default.
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
