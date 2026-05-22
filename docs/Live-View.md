# Live View

The control window is the central hub for TangoDisplay. It uses a sidebar for navigation with three sections:

**Live**
- **Live** — Status, preview, and quick-action buttons (this page)
- **Setlist** — Built-in player queue and playback controls ([Built-In Player](Built-In-Player))

**Settings**
- **Cortina Rules** — Automatic cortina detection ([Cortina Rules](Cortina-Rules))
- **Appearance** — Colors, fonts, and transitions ([Appearance](Appearance))
- **Display** — Monitor and label settings ([Display Settings](Display-Settings))
- **Player** — Player source selection and built-in player settings ([Built-In Player](Built-In-Player))

**Profiles**
- **Profiles** — Saved appearance profiles ([Profiles](Profiles))

> The **Setlist** item is only active when Built-in Player is selected as the player source. Selecting it while using another source shows a prompt to switch.

---

The **Live** page shows what is currently playing, a live preview of the dancer display, and quick-action buttons.

![Live view](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/live-view.png)

---

## Status indicators

At the bottom of the preview area:

| Indicator | Meaning |
|---|---|
| **Playing** (green) | A track is currently playing |
| **Polling OK** (green) | TangoDisplay successfully read track data on the last poll |
| **Paused** | The display is manually paused (dancer screen is frozen) |

> When using the Built-in Player, status reflects local playback state rather than Music.app polling. The "Polling OK" indicator is not shown in this mode.

---

## Action buttons

| Button | Shortcut | What it does |
|---|---|---|
| **Force Poll** | `⌘⇧R` | Immediately triggers a Music.app re-read, bypassing the normal notification/fallback-poll cycle |
| **Override…** | `⌘⇧O` | Opens a dialog to manually set what text appears on the display |
| **Pause Display** | `⌘⇧P` | Freezes the dancer screen; pressing again resumes live updates |
| **Last Tanda** | | Activates the Last Tanda label on the dancer display — label appears in the cortina coming-up section and throughout every dance track in the tanda. Toggle again to clear. Disabled if no Last Tanda label text is configured in Appearance Settings. |

All three keyboard shortcuts work globally — you don't need to switch to TangoDisplay first. The Last Tanda toggle has no shortcut.

---

## Last Tanda

The **Last Tanda** toggle activates the Last Tanda label on the dancer display. When toggled on:
- During a cortina: the label appears in the coming-up section alongside the next tanda preview.
- During dance tracks: the label appears as an orderable field in the Dance Tracks display.

The toggle is enabled only when a Last Tanda label text is configured and the **Show in display** option is on in **Appearance › Last Tanda**.

**Works with any player source.** For Built-in Player users, cortinas can also be pre-scheduled — see [Last Tanda](Built-In-Player#last-tanda) in the Built-in Player docs.

Turning the toggle off immediately clears the label from the display.

---

## Focus Mode

Focus Mode combines the live preview and setlist into a single split-pane window — useful when you want everything on one screen during a performance.

**Open / close:** Click the Focus Mode button in the toolbar (⌘⇧F).

### Layout

- **Top pane** — 16:9 live preview of the dancer display. An optional controls panel (200 px wide) sits to the right of the preview.
- **Divider** — drag the divider strip to resize the top and bottom panes. The split position is remembered between sessions.
- **Bottom pane** — the full Setlist view, including player controls and track list. Requires Built-in Player to be active; if another player source is selected, a prompt offers to switch.

### Controls panel

The controls panel (toggle with the rectangle toolbar button, or hide it to maximise preview space) contains:

| Button | What it does |
|---|---|
| **Force Poll** | Immediately triggers a re-read from the current player source |
| **Override…** | Opens the manual display override dialog |
| **Pause Display / Unpause Display** | Freezes or resumes live updates on the dancer screen |
| **Last Tanda** | Activates/deactivates the Last Tanda label |

> Focus Mode requires the Built-in Player to be active for the setlist panel. The preview and controls panel work with any player source.

---

## Track info panel

Below the buttons, TangoDisplay shows the currently detected values:

- **Title** — track name (may include vocalist in parentheses)
- **Artist** — orchestra / artist name
- **Genre** — the genre tag from Music.app
- **Tanda** — position within the current tanda, e.g. "Track 1 of 4"

---

## Debug log

The **Debug Log** disclosure item at the bottom expands to show recent polling events, AppleScript results, and cortina detection decisions. Useful for troubleshooting unexpected behaviour.
