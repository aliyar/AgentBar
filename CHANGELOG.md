# Changelog

All notable changes to AgentBar are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

Add entries under **Unreleased** as you work; `scripts/release.sh` moves them under the new
version heading and uses them as the release notes.

## [Unreleased]

## [1.2.1] - 2026-09-09

### Changed

- The app updates itself from the GitHub release rather than from the website: the feed and
  the zip are both release assets now, so an update depends on the repository rather than on
  a domain. A copy installed before this reads the old address and will not see new versions;
  download once from the site and it is on the new feed for good.
- The website counts its readers with Google Analytics, shared with the sibling sites, so
  we know which pages are read and how many people press Download; a download click is
  counted with the version and which button it was. The privacy page says what is
  collected and how to opt out. The app itself still sends nothing.
- A window that has already started over is drawn with a plain dash rather than an em dash,
  and so are a reset with no date anyone writes and a version that cannot be read. The mark
  means the same thing; the character is the one the rest of the project now uses.

## [1.2.0] - 2026-09-04

### Added
- **Whether the service is working, beside how much of it is left.** Each agent's own status
  page is read every five minutes, and every minute while something is wrong, and its
  state is one mark before the agent's name, drawn quietly until something is actually
  wrong. Not a row among the meters, which are a list of one kind of thing this is not; and
  not a word either, since the word would say "working" almost every time you looked.
  Resting on the mark says what the colour cannot. Clicking it opens
  that agent's status as a screen of its own, with the panel's header as the way back
  (Escape too): the page's own sentence, every component it lists, any open incident, and a
  link to the page. AgentBar reads the parts you actually run on rather than the page's
  overall indicator: claude.ai going down while Claude Code keeps working is not your
  outage, and an alarm for it is the one thing this must not do. Which component each agent
  is read from is written down in `docs/DEVELOPMENT.md`, so what the app watches can be
  checked against the page.
- **A notification when a service stops working, and when it starts again.** The second is
  the one this is for: a status page tells you a service is down, and then nothing tells you
  it is back, so you go and try until it is. A change is announced only once two readings
  agree, so a moment's flap says nothing; a page that cannot be reached is never reported as
  an outage, because dropped Wi-Fi looks exactly like a dead service; and an outage that was
  already under way when the app started is not announced at all. Two switches in Settings ›
  Agents turn the two directions on and off, for every agent you show. Which agents is not
  a second question: the list above them has already answered it. macOS is asked for
  permission when a switch is turned on or when there is a first message to show, never at
  launch.
- A small mark on the menu bar item while a watched service is unwell. Monochrome: the bars
  beside it are already coloured by how full a window is, and one signal must not be read as
  the other.

- **What the panel draws, and the order it draws it in, is yours.** Settings › Agents lists
  every block the panel stacks, each agent's group and the conversations running now, with
  a switch and a handle apiece. Drag one to move it; the menu bar's bars and the widget
  follow the agents' order too. The list is stored as names, so a block added by a later
  update joins the end instead of appearing somewhere arbitrary.
- **A `⋯` menu at the end of each agent's line**, in two halves: the usage and status pages
  this panel's own figures are read from, then the agent itself: its site, where its plan
  is paid for, and its documentation. It replaces the link that used to sit on the agent's
  name, which could only ever lead to one of them and gave no sign which.

- **The website says what the app now does.** A "When it goes down" section with the panel
  as it stands and the same panel with an agent's status pushed over it, the two messages
  drawn as macOS shows them, and what the feature will not do. The panel the site draws
  follows the app again: the mark before each agent's name, the plan badge, the menu of the
  agent's pages. Terms and privacy are ordinary pages now, with the same head, ground and
  foot as the rest of the site rather than a window of their own.

### Changed
- **Settings has a Menu Bar pane and a Status pane.** Appearance had grown to cover both how
  the panel is painted and what the menu bar item shows, and Agents to cover both which
  blocks the panel draws and whether the services behind them are up. Each pane now asks one
  question.
- The Settings sidebar shows the menu bar mark rather than the Dock icon. At 18 points the
  full icon is a smudge of what the mark says plainly, and the mark is how the app is met.
- Cursor's usage page is opened at `cursor.com/dashboard/usage`. Cursor moved its dashboard
  tabs from a query to a path; the address we shipped still redirects, but a redirect is a
  round trip that will one day stop being made.
- The README no longer says no account is contacted and nothing leaves the machine. That
  stopped being true on 3 September, when the agents' accounts began to be asked, and the
  status pages are a third kind of request. It now names all three and what turns each off.

- No em dash is written anywhere in this project any more: not in the app's own words, its
  code comments, these notes, or the site. A colon, a semicolon, brackets or two sentences
  say the same thing without it.

### Fixed
- **The panel on the website's desktop came back.** It closed when the desktop scrolled out
  of view and never returned, so scrolling back left the hero with a hole in it. It now
  remembers whether it was put away by the scroll or by the reader, and only the first
  comes back.
- **The Dock figure on the website drew a panel with no meters.** The panel is halved to fit
  its window, but its own `max-width` clamped it to that window first, so the halving left
  it at a quarter width in the left half of the box with no room for a bar. It is drawn at
  its true width and then halved.
- **The laptop and the widgets drawn inside it, in Safari.** They were scaled with `zoom`,
  which Safari lays out differently from Chrome: the widgets landed on top of each other
  on iPhone and in a narrow Safari window alike, while Chrome drew them correctly. The
  laptop now scales with a single transform, so its proportions hold at every width, and
  the wrapper states the box the transform leaves behind. The panel preview in "Where it
  lives" was scaled the same way and is fixed with it. No `zoom` is left in the stylesheet.

## [1.1.1] - 2026-09-03

### Changed
- **The panel's tooltips are a heading and a line, on a solid card.** A tip named its row
  in a sentence that ran the width of the panel; it now names what the pointer is on and
  says one line about it — "Weekly", then "2% used of 7d · starts over in 3d 10h". The card
  is dark in both appearances rather than translucent: a see-through card over a
  see-through panel is two half-legible layers, and a tooltip is a note held over the page,
  not part of it. It waits 620 ms rather than 320: long enough that crossing the panel
  raises nothing and a rest is deliberate.
- Settings no longer carries a Changelog pane. What changed in a release is read where the
  release is — the update it arrives with, and the website — and the changelog is no longer
  copied into the app bundle.

### Fixed
- A tooltip's text could run outside its card. The card wrapped its words at 254 pt while
  the layer around it sized the card to one line, so anything longer spilled past the
  corner. A short tip was also drawn as wide as a long one: `frame(maxWidth:)` takes every
  point it is offered, so the card now measures what its words want and takes the smaller
  of that and its maximum.

## [1.1.0] - 2026-09-03

### Added
- **What is left once a plan runs out.** Claude's extra usage and its prepaid credits
  become a row of their own, and Codex's balance is said beside the agent's name — both
  only when the account actually holds them, so a panel without credits is unchanged.
  Codex writes its balance into every session it runs, so it is read without asking the
  account at all.
- Codex's model-specific limits (`additional_rate_limits`) are shown among the plan's own
  windows, named for what tells them apart: GPT-5.3-Codex-Spark reads "5h · Spark" and
  "Weekly · Spark". Resting on the row gives the model's whole name.
- **The account beside the agent's name**: the plan as a small badge — "Max 20x", "Pro
  Lite", "Free" — and, on resting there, who is signed in. Quiet enough to be read second;
  it answers "whose numbers are these?" without taking a row. Every part of it is already
  on this Mac, beside the sign-ins the agents keep, so none of it costs a request. Cursor's
  monthly row is now just "Monthly", since the plan it used to carry is said above it.
- Cursor reads the figures every plan reports, not only an individual's: a team member's
  personal cap and the pool a team spends from each fill the monthly bar that was empty
  before, and an unlimited plan says so instead of drawing a percentage of no ceiling.

### Changed
- **One name per window, one order for every row.** A window is named for the period it
  runs — "5h", "Weekly", "Monthly" — and what it is scoped to follows it: "Weekly · all",
  "Weekly · Fable", "5h · Spark". Rows are ordered by how long their window runs, shortest
  first, and within one window the plan's own row comes before the models that meter their
  own; what is spent once the plan is full sorts last, having no window at all. Codex
  previously called its short window "Session (5h)" while a model's read "5h · Spark", and
  listed every plan window before every model one, so the same length appeared twice in a
  list that looked sorted.
- **The panel draws its own tooltips.** `help(_:)` waits out the system's delay — over a
  second, not ours to set — and draws in the system's yellow; inside a panel that answers
  a glance, that is the whole visit. Tips now appear in a third of the time, in the
  panel's own materials, placed against the row they belong to and kept inside the
  panel's edges.
- The agent's name in the panel is the link to its usage page. The small arrow that
  appeared beside it on hover is gone: it was a second thing to find for what the name was
  already pointing at.
 and its search metadata: the Open Graph card now states the
  image's size, type and alt text, so Slack, iMessage, X and LinkedIn draw the large card on
  the first fetch; the privacy and terms pages carry their own title, description and URL
  instead of the home page's; and the home page carries `SoftwareApplication`, `WebSite`,
  `Organization` and `FAQPage` structured data, a theme colour and a crawler directive that
  lets Google show the card image full size.

### Fixed
- **The website on a phone.** The page could be scrolled sideways: the callouts beside the
  drawn panel reached past the viewport, and the laptop kept its negative margins. The
  widgets inside the laptop drew at full size on iOS, where nested `zoom` dropped the inner
  scale — the inner layers use a transform now, which is scaled once and reliably. Section
  headings and the questions were still at their desktop size on a 390 pt screen. The
  callouts are left out below 420 pt, where a marker over a row covers the very figure it
  points at; the notes below keep their numbers and read in the same order.
- **A panel on the website closes when you press away from it**, or on Escape, as a menu on
  the Mac does. The Dock's panel could only be closed from the Dock icon that opened it.
- The website drew windows the app no longer names that way ("Daily" for Codex, "Pro ·
  monthly" for Cursor), and said Codex reports a daily window. It reports a 5-hour one.
- `next build` wrote `AGENTS.md` and `CLAUDE.md` into `site/` on every run; this project
  keeps its instructions in the notes repo (`agentRules: false`).
- Codex's 5-hour window was labelled "Daily" — a window named after a period four times
  its own. It reads "5h".
- Claude's session and weekly windows are read from the account's own named fields again.
  A `limits` array carrying only a model-scoped week used to replace them, which would
  have dropped the session row entirely. Scoped weeks still come from that array, and a
  scope naming every model no longer draws the weekly window a second time.
- The terminal style wrote "—" against a limit that starts over on no date anyone writes.
  The dash means a window has rolled over; the column is now blank for limits that have
  no reset at all.
- Codex's windows are ordered shortest first, as Claude's are. Its `primary` window is not
  always the shorter one — on some plans it is the week.

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

[Unreleased]: https://github.com/aliyar/AgentBar/compare/v1.2.1...HEAD
[1.0.0]: https://github.com/aliyar/AgentBar/releases/tag/v1.0.0
[1.0.1]: https://github.com/aliyar/AgentBar/releases/tag/v1.0.1
[1.1.0]: https://github.com/aliyar/AgentBar/releases/tag/v1.1.0
[1.1.1]: https://github.com/aliyar/AgentBar/releases/tag/v1.1.1
[1.2.0]: https://github.com/aliyar/AgentBar/releases/tag/v1.2.0
[1.2.1]: https://github.com/aliyar/AgentBar/releases/tag/v1.2.1
