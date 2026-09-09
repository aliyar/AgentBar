/** The page's words, in the app's own register: short, exact, nothing it cannot stand behind. */

export const agents = [
  {
    name: "Claude Code",
    windows: "The session window, the weekly window, and the weekly window per model, each with the time until it starts over.",
    conversations:
      "Every conversation running right now, named by what was last said in it, with a breathing dot while it works and how full its context is.",
  },
  {
    name: "Codex",
    windows: "Its 5-hour and weekly windows, from the rollout it writes while it runs and from the ChatGPT sign-in.",
    conversations:
      "Sessions found through their running process; their context is a real percentage, since Codex writes its window size.",
  },
  {
    name: "Cursor",
    windows: "The plan's monthly usage, from the editor's own sign-in; Cursor writes no usage on disk.",
    conversations: "Agent chats, from the editor's transcripts.",
  },
] as const;

export const places = [
  {
    name: "The menu bar",
    text: "The symbol, or a bar per window with the time left on one of them, coloured green, amber, then red as it fills. A click opens the panel.",
  },
  {
    name: "The Dock",
    text: "An icon in the Dock and ⌘-Tab if you want one. A click opens the same panel above the icon, or a window if you prefer; ⌘0 opens the window from anywhere.",
  },
  {
    name: "The widget",
    text: "Three sizes for the desktop and Notification Center. Right-click › Edit picks the theme, the windows to show, and whether the running conversations are listed.",
  },
] as const;

/** The two messages the status feature exists to send, drawn as macOS shows them. */
export const alerts = [
  {
    title: "Codex is down",
    body: "Codex API: partial outage.",
    when: "16:04",
    tone: "down" as const,
  },
  {
    title: "Codex is back",
    body: "You can carry on.",
    when: "16:31",
    tone: "back" as const,
  },
] as const;

export const honesty = [
  {
    lead: "Read from the agents’ own files.",
    text: "Claude Code and Codex write their windows and sessions under your home folder; AgentBar reads them there. Conversations never leave the Mac.",
  },
  {
    lead: "Live limits from the agents’ own sign-in.",
    text: "For the figures that only the account knows (what was spent on another Mac, or while the agent was not running), it asks each agent’s account with the sign-in that agent already keeps on this Mac. One read-only request every five minutes, and on the panel’s refresh. Nothing is stored or logged.",
  },
  {
    lead: "Each service's own status page.",
    text: "AgentBar reads the page each agent publishes (status.claude.com, status.openai.com, status.cursor.com) every five minutes, and every minute while something is wrong. These pages are public: no account is involved and nothing about you is sent.",
  },
  {
    lead: "Nothing invented.",
    text: "A window that has already started over shows a dash. A figure written hours ago says how old it is. A context whose limit is not written anywhere shows its tokens rather than a made-up percentage.",
  },
] as const;

export const status = [
  {
    lead: "It watches the parts you actually run on.",
    text: "A status page covers a whole company. Claude's covers claude.ai, the Console, Cowork and Claude Code as separate parts; AgentBar reads Claude Code and the API, and nothing else. claude.ai going down while Claude Code keeps working is not your outage, and you are not woken for it.",
  },
  {
    lead: "It tells you when it is back.",
    text: "A status page tells you a service is down. Then nothing tells you it is working again, so you go back and try until it does. That is the message this is for, and it comes whether or not you asked to hear about the outage.",
  },
  {
    lead: "It does not cry wolf.",
    text: "A change is announced only once two readings agree, so a moment's flap says nothing. A page that cannot be reached is never reported as an outage: dropped Wi-Fi looks exactly like a dead service. And an outage already under way when you open your Mac is not announced at all; you are already living through it.",
  },
] as const;

export const install = [
  { step: "Download the disk image and open it.", note: "Signed with a Developer ID and notarized by Apple; macOS opens it without a fuss." },
  { step: "Drag AgentBar onto Applications, then open it from there.", note: "It appears in the menu bar. Nothing else happens until you click it." },
  { step: "Settings › General, if you like.", note: "Launch at login, where it lives, what a Dock click opens. Updates arrive on their own." },
] as const;

export const faq = [
  {
    q: "Why does it ask my accounts, and what does it send?",
    a: "Claude Code, Codex and Cursor each keep a sign-in on this Mac. AgentBar uses it, read-only, to ask the account how much of each window is used, which is the same page you would open in the browser. One request every five minutes, one when you open the panel (at most once a minute), one when you press refresh. Nothing is stored, nothing is logged, and no token is ever shown or sent anywhere else.",
  },
  {
    q: "Does it read my conversations?",
    a: "It reads the tail of each running conversation’s transcript, on this Mac, to name it by what was last said and to read its context figure. That is all it looks for, and it stays on the Mac.",
  },
  {
    q: "Why does a window show a dash, or say “as of 14:05”?",
    a: "A dash means the window has already started over and the agent has not written a fresh figure yet; AgentBar will not guess. “as of” means the figure it shows is old enough that you should know how old.",
  },
  {
    q: "Why does a conversation show tokens instead of a percentage?",
    a: "Claude Code does not write a session’s context limit anywhere. When the limit is known (a 1M-context session, or a context already past 200K), you get a percentage; otherwise you get the tokens, which is the honest figure.",
  },
  {
    q: "Cursor shows only the monthly plan. Codex shows nothing.",
    a: "Cursor writes no usage on disk, so its figures come from the account only. Codex writes its windows while it runs on this Mac; before its first session here, or on a Mac where it never ran, there is nothing on disk, and the account is asked for the rest.",
  },
  {
    q: "Launch at login asked me to approve something.",
    a: "AgentBar registers through the system’s Login Items, which macOS may ask you to confirm once in System Settings. It reads the agents’ files only while it runs, and the widget shows what it last read; starting at login keeps both current.",
  },
  {
    q: "The widget says “Open AgentBar once”.",
    a: "The widget cannot read the agents’ folders itself (app extensions are sandboxed); it shows what the app last wrote. Open the app once and it fills in.",
  },
  {
    q: "How do updates work?",
    a: "The app reads the feed attached to the newest release on GitHub once a day and installs updates itself; you can turn that off in Settings › General. Builds are signed with a Developer ID, notarized by Apple, and every zip is signed with a key only this app accepts, so an update that is not ours is refused.",
  },
  {
    q: "How does it know a service is down?",
    a: "It reads the status page each agent publishes, every five minutes and every minute while something is wrong, which is the same page you would open in the browser. It reads the parts you run on rather than the page's overall state: Claude Code and the Claude API, Codex API, Cursor's CLI and IDE. Which part each agent is read from is written down, and the whole page is one click away in the panel.",
  },
  {
    q: "Will it wake me for nothing?",
    a: "A change is announced only after two readings agree, so a moment's flap says nothing. A page it could not reach is never reported as an outage: your Wi-Fi dropping looks exactly like a dead service, and one of those is not news. An outage already under way when AgentBar starts is not announced either. Both messages can be turned off in Settings › Status.",
  },
  {
    q: "Is it really free, and can I read the source?",
    a: "Free, and open source under the MIT licence: the app, its tests and this website are one repository on GitHub. Read what it sends before you trust it with an account, or build it yourself. Issues and pull requests are welcome there.",
  },
  {
    q: "Which agents next?",
    a: "The three here are the ones on this Mac. Others follow as they get used; usage is the first thing AgentBar shows, not the last.",
  },
] as const;
