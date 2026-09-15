"use client";

import { useState } from "react";
import { video } from "../site";

/**
 * The explainer, drawn as its poster until it is asked for. Nothing is fetched from YouTube
 * before the click: the player then loads from youtube-nocookie.com in the same frame, so
 * the page does not move. The poster is a plain link to the video, so it still works with
 * scripts off, and a click with a modifier opens YouTube as a link would.
 */
export function ExplainerVideo() {
  const [playing, setPlaying] = useState(false);

  if (playing) {
    return (
      <div className="film-frame">
        <iframe
          // YouTube's control bar stays, so the video can be scrubbed and made full screen.
          // Otherwise as little of YouTube as the player allows: no captions, no cards, related
          // videos only from this channel. Its title and avatar are YouTube's to draw; no
          // parameter removes them.
          src={`https://www.youtube-nocookie.com/embed/${video.id}?autoplay=1&rel=0&iv_load_policy=3&cc_load_policy=0&playsinline=1`}
          title={video.title}
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          referrerPolicy="strict-origin-when-cross-origin"
          allowFullScreen
        />
      </div>
    );
  }

  return (
    <a
      className="film-frame film-poster"
      href={video.watchUrl}
      aria-label={`Play the ${video.title} video (${video.length})`}
      onClick={(event) => {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return;
        event.preventDefault();
        const w = window as unknown as { gtag?: (...args: unknown[]) => void };
        w.gtag?.("event", "video_play", { app: "agentbar", video: video.id });
        setPlaying(true);
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={video.poster} alt="" width={1920} height={1080} loading="lazy" decoding="async" />
      <span className="film-play" aria-hidden="true">
        <svg viewBox="0 0 24 24"><path d="M8 5.6v12.8a1 1 0 0 0 1.5.86l10.4-6.4a1 1 0 0 0 0-1.72L9.5 4.74A1 1 0 0 0 8 5.6Z" /></svg>
      </span>
      <span className="film-length" aria-hidden="true">{video.length}</span>
    </a>
  );
}
