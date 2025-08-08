NowPlayingPlus – Animation Choreography Specification

This document defines precise animation choreography for the NowPlayingPlus tvOS application, enabling Cursor LLM to generate accurate SwiftUI motion code. It outlines the behavior of:

Background gradient transitions

Foreground hero elements

Drifting tiles (albums, videos, playlists)

Overlay fact and editorial note lanes

Parallax layering and timing

1. Parallax Layer Structure

┌──────────────────────────────────────────────┐
│ Layer 0 – Background gradient (slow drift)   │ ← scroll speed: 0.2x
│ Layer 1 – Large tiles (videos, playlists)    │ ← scroll speed: 0.4x
│ Layer 2 – Small album tiles                  │ ← scroll speed: 0.6x
│ Layer 3 – Hero element (current album art)   │ ← pinned center, 1.0x
│ Layer 4 – Overlay text lanes (facts/notes)   │ ← entrance/exit animation only
└──────────────────────────────────────────────┘

2. Background Gradient Drift

Duration: 45–60s for full hue rotation (looping)

Easing: easeInOutCubic

Palette Source: from artist or album art via k-means clustering

Implementation:

Animate LinearGradient center point

Animate gradient stops to blend into complementary tones

3. Drifting Tile Behavior

General Properties

Spawn rate: 1 tile every 4 seconds per layer

Paths: Bezier curves randomized per layer

Scale: 90%–110%

Opacity: 8%–14%

Speed: 20s–35s travel duration depending on layer

Bezier Path Examples

Start: offscreen left-bottom
End: offscreen top-right
Curve: (start) → [center-bottom + 200pt] → (end)

Sample Tile Path Generator (SwiftUI Pseudo-code)

Path { path in
    path.move(to: CGPoint(x: -100, y: UIScreen.main.bounds.height + 100))
    path.addCurve(to: CGPoint(x: UIScreen.main.bounds.width + 100, y: -100),
                  control1: CGPoint(x: centerX - 150, y: centerY + 200),
                  control2: CGPoint(x: centerX + 150, y: centerY - 200))
}

4. Hero Tile (Current Track)

Pinned center

Scale bounce on track change:

From scale = 0.8 → 1.2 → 1.0

Duration: 0.6s

Easing: spring(response: 0.4, dampingFraction: 0.5)

Shadow: soft white glow, blur radius 30, opacity 0.3

Dynamic palette overlay: 30% opacity radial burst from center

5. Overlay Lanes – Text Animations

Lanes

Top Left        – `fact_lane_1`
Bottom Right    – `fact_lane_2`
Top Right       – `note_lane_1`
Bottom Center   – `note_lane_2`

Entry/Exit Timing

Entry: fade + slide in from lane edge

Duration: 0.8s

Offset: +60pt from resting position

Easing: easeOutBack

Dwell: 10–14 seconds (randomized)

Exit: fade + slide out (same direction)

Duration: 0.6s

Offset: +60pt

Easing: easeIn

Content Rules

Alternate between facts and editorial notes

No repeated lanes for two consecutive texts

Never overlap lanes with active content

If no fact/note available, idle animation fills the lane (e.g., gentle floaty placeholder)

6. Typography Details

Facts

Font: .title2.weight(.medium)

Background: rounded rectangle with blur (.ultraThinMaterial)

Max width: 520pt

Corner radius: 18pt

Padding: 16pt all sides

Text color: contrast-based from background layer

Editorial Notes

Font: .body.weight(.light)

Background: translucent capsule

Dwell: slightly longer (12–18s)

7. Music Sync Option (Future Enhancement)

We can allow motion speed (tile drift, gradient drift) to subtly sync with BPM:

Fetch BPM from MusicKit metadata or analysis

Scale drift speed (e.g., ±10%)

Example:

let baseSpeed = 1.0
let adjustedSpeed = baseSpeed * (trackBPM / 120.0)

8. Testing & Debug

Dev mode includes overlay of tile path lines

FPS monitor toggle via Apple remote press

Lane occupancy debug log

Performance: >55 fps under continuous drift load, with 6+ active overlays

