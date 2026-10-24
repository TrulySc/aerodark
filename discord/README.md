# Aero Light / Aero Dark for Discord (Vesktop / Vencord)

Two Discord themes that match AeroThemePlasma's Explorer: flat panes split by hairlines, the
command-bar gloss on 31 px headers, the Windows 7 nav-pane selection, Windows 7 push buttons,
text boxes, menus and tooltips, and Segoe UI 9 pt.

| Theme | Use with Discord appearance | Preview |
|---|---|---|
| `AeroLight.theme.css` | Light | `preview-light.png` |
| `AeroDark.theme.css` | Dark | `preview-dark.png` |

Built on [Midnight](https://github.com/refact0r/midnight-discord) (MIT), which keeps up with
Discord's class-name changes.

## Install

```sh
mkdir -p ~/.config/vesktop/themes
cp AeroLight.theme.css AeroDark.theme.css ~/.config/vesktop/themes/
```

Then go to **Settings → Vencord → Themes**, enable one of them, and set **Settings → Appearance**
to the matching Light or Dark.

## Tweaks

Edit the `body { … }` block at the top of the palette:

- `--aero-ui-size` sets the interface text size (default 9pt).
- `--aero-chat-size` sets the message text size (default 10pt; use 9pt to match the desktop exactly).
- `--aero-header-height` sets the header height (default 31px, the height of Explorer's command bar).

The source is in `src/`: `base.css` holds the shared layout, and `palette-light.css` and
`palette-dark.css` hold the colours. Run `./build.sh` to regenerate both themes.

## Icons: your Plasma icon theme in Discord

`aerodark-discord-icons` (installed by `install.sh` into `~/.local/bin`) looks up Discord's icons in
your current Plasma icon theme — the same lookup KDE apps use, inheritance included — and writes them
into a third Vencord theme, `AeroIcons.theme.css`. Enable it alongside Aero Light or Aero Dark.
Change icon packs and it follows: the `aerodark-sync` helper re-runs it when the icon theme changes
(or run `aerodark-discord-icons` yourself).

- `icons/icon-map.json` maps about 150 Discord icons to standard icon names (`configure`,
  `notifications`, `audio-input-microphone`, `edit-delete`, `mail-attachment`, …).
- Icons no theme has (Discord-only things like Nitro, boosts, threads, stage channels) can be
  redrawn: the 14 sheets in `icons/redraw/` hold only those. Give them to ChatGPT with
  `icons/chatgpt-prompt.md`, then import the results with `import-redrawn-icons.py`; they go into a
  small add-on icon set, `~/.local/share/icons/AeroDiscord`, which the generator uses next.
- Pick icons by hand: save any image as `<number>.png` (or `.svg`, `.ico`, `.webp`) in
  `~/.local/share/aerodark/discord/custom/` and re-run `aerodark-discord-icons`; your picks beat
  everything else. `aerodark-discord-icons --catalog` opens a page listing every icon, its number,
  what replaces it now and the file name to use (buttons like the mic use names: `mic.png`, …).
- Icon packs to pick from: `aerodark-discord-icons --add-pack pack.zip` copies a pack (PNG, ICO,
  GIF…) into `~/.local/share/aerodark/discord/packs/` and opens the catalog; click a Discord icon,
  click a picture from the pack, then **Save picks** and run
  `aerodark-discord-icons --apply-picks ~/Downloads/aerodark-picks.json`.
- Emoticons: `python3 ~/.local/share/aerodark/discord/import-emoticons.py msn-messenger-icons.zip`
  swaps matching emoji for MSN Messenger emoticons in AeroEmoji (others keep the system emoji font).
- Packs and emoticons stay in your home folder; they're not part of this repo.
- Brand logos and Discord's tiny interface glyphs (chevrons, checkmarks, close crosses) are left
  alone on purpose.

To re-export Discord's icons after a big Discord update: `python3 icons/discord-icons.py`
(terminal) or `icons/export-discord-icons.js` (DevTools console).
