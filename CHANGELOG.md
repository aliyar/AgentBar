# Changelog

All notable changes to AgentBar are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

Add entries under **Unreleased** as you work; `scripts/release.sh` moves them under the new
version heading and uses them as the release notes.

## [Unreleased]

### Changed
- The website's link preview and its search metadata: the Open Graph card now states the
  image's size, type and alt text, so Slack, iMessage, X and LinkedIn draw the large card on
  the first fetch; the privacy and terms pages carry their own title, description and URL
  instead of the home page's; and the home page carries `SoftwareApplication`, `WebSite`,
  `Organization` and `FAQPage` structured data, a theme colour and a crawler directive that
  lets Google show the card image full size.

## [1.0.1] - 2026-09-03

### Changed
- The defaults a first launch lands on: the menu bar gauge (bars and the time left) on,
  the app in the menu bar and the Dock both, and launch at login registered on the first
  run. Each can be turned off in Settings.

## [1.0.0] - 2026-09-03

### Added
- The app: a menu bar item, a popover, and a Settings window with the update controls.
- **The icon**: a dark terminal squircle holding the app's own panel, a `>` prompt and a
  green block cursor. The menu bar shows the same mark; so does the panel's header.
- **The limits come from the agents' accounts**, so what was spent on another Mac or while
  the agent was not running counts too: Claude through Claude Code's sign-in, Codex through
  its ChatGPT sign-in, Cursor through the editor's. One read-only request every five
  minutes, and on the panel's refresh button; nothing is stored. What the agents write on
  disk stays the fallback.
- **Cursor** joins Claude Code and Codex: its plan's monthly usage, and its agent chats
  among the active conversations.
- **Where the app lives is a choice**: Settings › General › "Show AgentBar in" the menu
  bar (default), the Dock, or both. In the Dock, clicking the icon opens the panel above
  the Dock, as the menu bar icon does, or a window if you prefer (the choice is in the Dock
  icon's right-click menu too); Window › AgentBar (⌘0) and the widget open the window,
  whose header stands in for its title bar.
- **A widget** for Notification Center and the desktop, in three sizes: each agent's
  fullest window with its meter and time left; every window as a row; the rows and the
  running conversations. Right-click › Edit "AgentBar" picks the windows to show (any
  set; none means all), a theme (system, dark or light) and, for the large size, whether
  the running conversations are listed. A size left with a single window shows it as a
  card: the figure large, a wide meter, the time left. When there are more windows than
  a size has rows, it shows each agent's fullest rather than dropping the last agents.
  It shows what the app last read and says "as of" when that is old; tapping a
  conversation brings its terminal or editor forward.
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
- **Style**: how the panel is drawn, apart from the theme. Glass (the design) or Terminal
  (a terminal readout: monospaced, green on black, `▌` meters, a blinking prompt); each
  has a light and a dark variant and the theme picks which, Dark by default. A background
  opacity slider (0–100%) sets how sheer either panel is.
- **Launch at login**, through the system's Login Items.
- Hover an agent's name in the panel and a small arrow (Terminal: `:usage`) appears; it
  opens that agent's own usage page in the browser.
- The Active group stays when nothing is running and says so, so the panel keeps its
  shape; a context at "100%" no longer wraps; while a refresh runs, the clock in the
  header walks "..." (the Terminal panel's `:r` flashes when clicked, too).
- Nothing is shown that cannot be stood behind: a window that has already started over
  shows "—", a figure written hours ago says how old it is, and a context whose limit is
  not written anywhere reports its tokens instead of a made-up percentage.

[Unreleased]: https://github.com/aliyar/AgentBar/compare/v1.0.1...HEAD
[1.0.0]: https://github.com/aliyar/AgentBar/releases/tag/v1.0.0
[1.0.1]: https://github.com/aliyar/AgentBar/releases/tag/v1.0.1
