# Appearance

The **Appearance** tab controls everything about how the dancer display looks — transitions, colors, background image, and fonts.

---

## Transition

![Appearance — transitions and colors](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/appearance-transition-v190.png)

| Setting | Description |
|---|---|
| **Style** | How the display transitions between tracks. Options include *Fade Through Black*, *Cross-Fade*, and *Cut*. |
| **Duration** | Length of the transition in seconds (drag the slider). |

---

## Colors

Set the color of each element on the dancer display:

| Element | What it colors |
|---|---|
| **Background** | The solid background fill (used when no background image is set, or behind a semi-transparent image) |
| **Artist** | The large artist/orchestra name text |
| **Title** | The track title text |
| **Genre/label** | The smaller genre or record label line |
| **Year** | The recording year (e.g. 1952) — only shown when **Show Year** is enabled |
| **Track counter** | The "Track X of X" text in the corner |
| **Singer** | The vocalist/singer line — always configurable here; the Singer line only appears on the display when **Include singer** is enabled (set in Fonts) |

Click any color swatch to open the macOS color picker.

---

## Album Artwork

![Appearance — album artwork](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/appearance-artwork-v190.png)

| Control | Description |
|---|---|
| **Display album artwork where available** | Toggle artwork display on/off |
| **Opacity** | 0 % = invisible, 100 % = fully opaque |
| **Scale** | 1× = natural size; increase to fill more of the screen |
| **Horizontal offset** | Move the artwork left (negative) or right (positive) |
| **Vertical offset** | Move the artwork up (negative) or down (positive) |

Artwork is fetched automatically from the playing track for all three player sources — Music.app, Swinsian, and Embrace. It fades in and out in sync with track transitions using the same transition style and duration configured above. When no artwork is available the display falls back gracefully (nothing is shown in that layer).

---

## Background Image

![Appearance — background image](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/appearance-background-v2-190.png)

| Control | Description |
|---|---|
| **Pick Image… / Change Image…** | Opens a file picker to select any image file (label changes to *Change Image…* once an image is loaded) |
| **Clear** | Removes the background image |
| **Opacity** | 0 % = fully transparent (solid background color shows), 100 % = fully opaque |
| **Scale** | Zoom the image in or out (1× = original size, higher = zoomed in) |
| **Horizontal** | Pan the image left or right |
| **Vertical** | Pan the image up or down |

Use Scale + Horizontal + Vertical to frame exactly the part of the image you want behind the text.

---

## Fonts

![Appearance — fonts and singer](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/appearance-singer-v201.png)

Configure the typeface, size, and style for each text element:

| Column | What you set |
|---|---|
| Font name | Choose from installed system fonts |
| Size | Point size of the text |
| Up/Down arrows | Fine-tune the point size |
| **B** | Bold |
| *I* | Italic |

The rows are **Artist**, **Title**, **Genre**, **Year**, and **Singer**. Year only appears when **Show Year** is enabled — toggle it on with the **Show Year** switch above the Year row.

### Singer Source

Enable the singer line with the **Include singer** toggle. When on, a **Source** picker lets you choose where the singer name comes from:

| Source | Description |
|---|---|
| **Comments** | Reads the track's Comment metadata field. Useful when you've tagged vocalist names into comments in your library. This is the default and matches the behaviour of earlier versions. |
| **Album Artist** | Reads the Album Artist metadata field. Useful when Album Artist holds the vocalist name (common in some tango library workflows). |

A **Singer** font row appears below the source picker so you can set the typeface, size, and style independently of the other text elements.

When the singer line is on, a second toggle — **Show singer during cortina** — controls whether the vocalist name also appears in the cortina "Coming Up" preview.

---

## Text Order

![Appearance — text order](https://raw.githubusercontent.com/richardsladetdj-creator/TangoDisplay/main/docs/screenshots/appearance-textorder-v220.png)

Control the vertical order in which text items appear on the dancer display. There are two independent orderings — one for dance tracks and one for the cortina "Coming Up" preview.

| Section | What it controls |
|---|---|
| **Dance Tracks** | Order of items on the main display while a tanda is playing |
| **Cortinas — Coming Up** | Order of items in the next-tanda preview shown during cortinas |

Each section lists the available items. Use the **↑** and **↓** chevron buttons on the right of each row to move items up or down. Changes take effect on the dancer display immediately.

**Dance Tracks** items: Genre, Artist, Year, Title, Singer (default order matches the original layout)

**Cortinas — Coming Up** items: Genre, Artist, Year, Singer — plus **Title** is available here too if you want to show the next track's title in the cortina preview (off by default)

---

## Saving your settings

- **Save** — updates the currently active profile with the new settings
- **Save as New Profile…** — creates a new named profile (see [Profiles](Profiles))

Changes take effect on the dancer display immediately.
