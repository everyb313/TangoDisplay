# Supported Players

TangoDisplay supports five player sources. Select your player in **Settings › Player**.

---

## Feature matrix

| Player | Detection | Tanda position | Tanda total | Coming-up preview | Artwork | Singer | Year |
|---|---|---|---|---|---|---|---|
| **Music.app** | Notifications + AppleScript | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Swinsian** | Push notifications | ✓ | — | ✓ | ✓ | ✓ | ✓ |
| **Embrace** | Notifications + AppleScript | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **JRiver Media Center** | MCWS HTTP API (2 s poll) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Built-in Player** | Native (fully integrated) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Tanda position** — shows "Track 2" (position within the current tanda, derived from track history or playlist).  
**Tanda total** — shows "of 4" (total tracks in the tanda, requires backward playlist context). Swinsian's queue starts at the current track, so this is unavailable.  
**Coming-up preview** — the "Coming Up" genre and artist shown during a cortina, derived from the playlist.  
**Singer** — vocalist name from Comments or Album Artist field (configured in Appearance › Singer Source).

---

## Player notes

### Music.app

Polls Music.app every 2 seconds via AppleScript, with an additional real-time trigger from the `com.apple.Music.playerInfo` system notification. Playlist look-ahead is read from the full Now Playing playlist via AppleScript, providing accurate tanda totals and the coming-up preview. Artwork is fetched via AppleScript.

**Requirements:** Music.app must be running and playing from a named playlist. Grant Automation › Music permission on first launch.

---

### Swinsian

Listens for Swinsian push notifications in real time. The coming-up cortina preview is supported when playing from a queue or playlist. Tanda position is tracked via track history; the total ("of N") is unavailable because Swinsian's queue starts at the current track so backward context is unavailable.

**Requirements:** Swinsian must be installed and running.

---

### Embrace

Listens for Embrace push notifications in real time, with AppleScript polling as a fallback. Full playlist enumeration provides accurate tanda totals ("Track 2 of 4") and the coming-up cortina preview, on par with Music.app.

**Requirements:** Embrace must be installed and running. Grant Automation › Music permission on first launch.

---

### JRiver Media Center

Polls JRiver's MCWS HTTP API at `127.0.0.1:52199` every 2 seconds. Full playlist look-ahead (window of 15 tracks around the current position) provides accurate tanda totals and the coming-up cortina preview. Album artwork is fetched via the MCWS thumbnail endpoint. Year, singer/comment, and album artist are retrieved from JRiver's per-file metadata.

**Requirements:** JRiver Media Center must be running with **Media Network** enabled (Tools → Options → Media Network → Enable Media Network). No additional configuration is needed — TangoDisplay connects to localhost on the default MCWS port.

**Multiple zones:** If you run more than one JRiver zone (e.g. Player + Prelistening), go to **Settings › Player › Zone** and pick the zone TangoDisplay should monitor. Click **Refresh** to populate the list from JRiver, then select your main output zone. The pre-listening zone will be ignored. Defaults to *Active (follows current)*, which preserves the previous single-zone behaviour.

---

### Built-in Player

TangoDisplay plays audio directly — no external player required. Build a setlist by dragging tracks from Finder, Music.app, or Swinsian. All display automation (cortina detection, tanda counting, coming-up preview, artwork) is fully integrated. Additional features: 5-band EQ, audio output routing, Fade & Stop / Fade & Continue cortina transitions, and accidental-stop protection.

See the [Built-In Player](Built-In-Player) guide for full details.

**Requirements:** None.
