import { Desktop } from "./demo/Desktop";
import { SiteEnd } from "./ui/SiteEnd";
import { AppIcon } from "./demo/AppIcon";
import { AnatomyScene, HonestyScene, LaptopScene, PlacesScene, StatusScene, StylesScene } from "./demo/Scenes";
import { Mark } from "./demo/AppIcon";
import { alerts, faq, honesty, install, status } from "./content";
import { release } from "./release";
import { homeSchema, jsonLd } from "./schema";
import { site } from "./site";

export default function Home() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={jsonLd(homeSchema)} />
      <Desktop />
      <main className="sheet" id="main">
        <section className="band" id="shows">
          <div className="band-head">
            <h2>What it shows</h2>
            <p className="lede">Every rate-limit window with the time until it starts over, and every conversation running right now with how full its context is.</p>
          </div>
          <AnatomyScene />
        </section>

        <section className="band" id="lives">
          <div className="band-head">
            <h2>Where it lives</h2>
            <p className="lede">One panel, wherever you look.</p>
          </div>
          <PlacesScene />
        </section>

        <section className="band" id="styles">
          <div className="band-head">
            <h2>Two styles</h2>
            <p className="lede">Glass, or a terminal readout. Each in light and dark, with a slider for how sheer the panel is.</p>
          </div>
          <StylesScene />
        </section>

        <section className="band" id="status">
          <div className="band-head">
            <h2>When it goes down</h2>
            <p className="lede">Every agent&rsquo;s own status page, beside its quota, and a word when a service stops working and when it starts again.</p>
          </div>
          <StatusScene />
          <div className="alerts" aria-hidden="true">
            {alerts.map((a) => (
              <div key={a.title} className={`alert alert--${a.tone}`}>
                <span className="alert-mark"><Mark size={18} /></span>
                <div className="alert-text">
                  <b>{a.title}</b>
                  <span>{a.body}</span>
                </div>
                <span className="alert-when">{a.when}</span>
              </div>
            ))}
          </div>
          <div className="notes">
            {status.map((n) => (
              <div key={n.lead} className="note">
                <b>{n.lead}</b>
                <p>{n.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="band" id="widget">
          <div className="band-head">
            <h2>The widget</h2>
            <p className="lede">Three sizes for the desktop and Notification Center. Right-click › Edit picks the theme, the windows to show, and whether the running conversations are listed.</p>
          </div>
          <div className="laptop-wrap"><LaptopScene /></div>
          <p className="prose">
            A size left with a single window shows it as a card; the small one shows Cursor’s plan. When there are more windows than a size has rows, it shows each agent’s fullest rather than dropping the last agents.
          </p>
        </section>

        <section className="band" id="knows">
          <div className="band-head">
            <h2>How it knows</h2>
            <p className="lede">{honesty[0].text} {honesty[1].text}</p>
          </div>
          <HonestyScene />
        </section>

        <section className="band" id="install">
          <div className="band-head">
            <h2>Install {site.name}</h2>
            <p className="lede">Free, for macOS {release.minMacOS} or later. Signed with a Developer ID, notarized by Apple, and it updates itself.</p>
          </div>
          <div className="install">
            <div className="dmg" aria-hidden="true">
              <AppIcon size={64} />
              <span className="dmg-arrow">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 12h15M13 6l6 6-6 6" /></svg>
              </span>
              <span className="dmg-folder">
                <svg viewBox="0 0 64 64" fill="none"><path d="M6 18a4 4 0 0 1 4-4h14l5 5h25a4 4 0 0 1 4 4v27a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#6fb2f2" /><path d="M6 26h52v24a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4Z" fill="#8ec5fb" /></svg>
                Applications
              </span>
            </div>
            <ol className="steps">
              {install.map((s) => (
                <li key={s.step}>
                  <div>
                    <b>{s.step}</b>
                    <span>{s.note}</span>
                  </div>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section className="band" id="faq">
          <div className="band-head">
            <h2>Questions</h2>
          </div>
          <div className="faq">
            {faq.map((f) => (
              <details key={f.q}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>

        <SiteEnd />
      </main>
    </>
  );
}
