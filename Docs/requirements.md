
MusicShowCase — Full tvOS Build Specification

Apple Music + Zune-style Visualizer + Artist Showcase + LLM Fun Facts + Editorial Notes

⸻

1. Introduction & Vision

MusicShowCase is a tvOS 17+ application that blends the immersive, cinematic visuals of the Microsoft Zune desktop player with the deep music catalog and metadata from Apple Music. The app’s goal is to transform Apple TV into a living, breathing music experience — not just album art in a corner, but a full-screen, color-rich, fact-filled visual showcase.

Key goals:
	1.	Full Apple Music Navigation — replicate the core navigation of the Music app: Listen Now, Library, Browse, Search, Now Playing, Settings.
	2.	Immersive Now Playing Visualizer — multiple Zune-inspired modes that mix:
	•	Album art (current + notable)
	•	Artist images and videos
	•	Editorial notes
	•	LLM-generated fun facts about both the artist and album
	3.	Artist Showcase Mode — a rich visual blend of artist artwork, hero albums, videos, and playlists — animated with Zune-like drift and parallax.
	4.	Real-time LLM Facts — retrieved from Vertex AI via Firebase Cloud Functions, in JSON structure, with automatic “top-up” during playback.
	5.	Cinematic Animations — smooth, layered, color-coordinated motion that feels alive and in sync with the music.
	6.	Color Palettes — extracted from the current artwork to drive the theme dynamically.
	7.	User Customization — control animation intensity, fact frequency, editorial note display, and visualization style.

This is not just “music playback” — it’s music as an ambient art installation for the living room.

⸻

2. Top-Level App Flow

[Launch Screen]
    ↓
[Listen Now] — [Library] — [Browse] — [Search] — [Now Playing] — [Settings]

Listen Now:
  - Recently Played
  - Heavy Rotation
  - Recommendations

Library:
  - Playlists
  - Albums
  - Artists
  - Songs
  - Recently Added
  - Favorites

Browse:
  - Genres
  - Charts
  - Curated Playlists

Search:
  - Full Apple Music catalog search
  - Quick-play from results

Now Playing:
  - Visualizer Modes (Wall / Aurora / Typography / Artist Zune Wall)
  - LLM fun facts & editorial notes
  - Artist showcase

Settings:
  - Visualization mode
  - Fact density
  - Artist emphasis
  - Editorial notes toggle
  - Reduce motion
  - Color intensity
  - Source visibility


⸻

3. Platform & Tech Stack
	•	tvOS 17+
	•	Swift 5.10+
	•	SwiftUI for declarative UI
	•	MusicKit for Apple Music navigation & playback
	•	AVFoundation/AVAudioEngine for optional audio-reactive visuals
	•	CoreImage / Accelerate for dynamic color palette extraction
	•	Firebase:
	•	Auth (Apple ID / Anonymous)
	•	Functions (to call Vertex AI)
	•	Analytics
	•	Vertex AI (Gemini 2.x) for fact generation
	•	LLM Request Format: JSON schema for fun facts, alternating between artist and album topics

⸻

4. Navigation & Data Sources

MusicKit will be wrapped in an AppleMusicService to provide:
	•	Listen Now data
	•	Library data (playlists, albums, artists, songs, favorites)
	•	Browse by genre
	•	Artist view (albums, videos, playlists, editorial notes)
	•	Search results
	•	Playback state for Now Playing visualizer

⸻

5. Fun Facts System

Fact Retrieval Flow:
	1.	At track start:
	•	Request 10 fun facts from LLM (≥3 must be returned before display begins)
	•	Facts must be a mix of artist and album topics
	2.	Top-up when ≤3 facts remain:
	•	Request 8 more
	3.	Facts:
	•	Max 220 characters
	•	Written in conversational, engaging tone
	•	No repeats in session
	4.	Facts displayed every 18–35 seconds in Now Playing mode
	5.	Facts alternate with editorial notes (never within 6 seconds of each other)

LLM Prompt (simplified):

You are generating fun, engaging facts for music playback.
Input: {artist_name}, {album_name}, {release_year}
Output: JSON array with up to 10 facts, alternating album and artist subjects.


⸻

6. Editorial Notes
	•	Pulled from Apple Music’s editorialNotes field
	•	Trimmed to ≤220 characters
	•	Appear every 45–70 seconds
	•	Styled as small “info chips” that animate onto the screen

⸻

7. Artist Showcase

Data model combines:
	•	Artist artwork (from MusicKit)
	•	Hero album (current or most iconic)
	•	Notable albums
	•	Featured videos
	•	Curated playlists
	•	Editorial notes
	•	LLM fun facts

Display behavior:
	•	Background: gradient from palette colors
	•	Foreground: drifting tiles of albums, videos, playlists
	•	Overlay: rotating facts and notes

⸻

8. Animation & Motion Guidelines

General
	•	Target 60fps
	•	Use cubic in/out easing for drift
	•	Use spring easing for hero transitions
	•	Parallax layering — deeper layers move slower

Zune-Style Wall
	•	Background gradient hue drift over 40–60s
	•	Depth tiles drift along bezier paths, opacity 8–12%, scale jitter ±1.5%
	•	Hero tile in center with bloom/shadow
	•	Overlay cards (facts, notes) slide/fade in and out from alternating lanes

Overlay Lanes
	•	Top-left, bottom-right, center-bottom, top-right
	•	Never reuse same lane twice in a row
	•	Min 6s separation between fact and note

⸻

9. Color Palette Extraction
	•	Extract from current artist artwork (fallback: album art)
	•	k-means clustering for dominant tones
	•	Ensure WCAG contrast compliance for text

⸻

10. Performance Requirements
	•	Cold start → first frame < 1.5s
	•	Warm start < 0.7s
	•	Artwork placeholder in ≤100ms
	•	Preload next track’s artwork and facts

⸻

11. Settings
	•	Visualization mode: Wall / Aurora / Typography / Artist Wall / Auto
	•	Artist emphasis: Low / Medium / High
	•	Fact density: Off / Light / Standard / Frequent
	•	Editorial notes: On/Off
	•	Reduce motion: On/Off
	•	Color intensity: Subtle / Standard / Bold
	•	Show sources: On/Off

⸻

12. Analytics

Track:
	•	fact_shown (id, type, lane)
	•	editorial_shown
	•	Visualization mode used
	•	Session length
	•	FPS dips
	•	Lane usage

⸻

13. Testing
	•	Unit tests for fact alternation & cooldown logic
	•	Snapshot tests for all visualization modes
	•	Performance soak test: 2 hours continuous playback at 60fps

⸻

14. Remote Config

Firebase Remote Config controls:

{
  "initialBatch": 10,
  "topUpBatch": 8,
  "prefetchThreshold": 3,
  "factMinIntervalSec": 18,
  "factMaxIntervalSec": 35,
  "chipMinIntervalSec": 45,
  "chipMaxIntervalSec": 70,
  "chipDwellSec": 10,
  "enableEditorial": true,
  "colorIntensity": "standard",
  "defaultMode": "wall"
}


⸻
