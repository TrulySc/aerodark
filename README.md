# Aero Dark for AeroThemePlasma — VistaVG Black look

A dark mode for [AeroThemePlasma](https://github.com/aeroshell-desktop/aerothemeplasma), styled after the
Black variant of Vishal Gupta's VistaVG Ultimate theme: neutral black glass, a silver gloss line on
buttons, Vista-blue glow for hover and selection, and amber for "new" items. Only the surfaces that used
to be white or light grey turn black/graphite; the green progress bar and yellow folders stay.

No artwork from VistaVG is included — the look was matched by hand.

## Switching between light and dark

After installing, **System Settings → Global Theme** lists **Aero Dark (VistaVG Black)** next to
AeroThemePlasma's own **Windows 7 style**. Pick either one to switch everything at once:

| | Windows 7 style (light) | Aero Dark (dark) |
|---|---|---|
| Colors | Aero | Aero Dark (VistaVG Black) |
| Application Style | kvantum | kvantum-dark |
| Start menu | light | dark (switches by itself) |
| Taskbar, title bars | your glass colour | black glass (switched by the helper) |

Everything else (icons, cursors, window decoration, Plasma style, splash screen) stays AeroThemePlasma's.

How it works:

- **Kvantum** has two application styles: `kvantum` uses your Kvantum theme (Windows7Aero), and
  `kvantum-dark` automatically uses that theme's dark variant, `Windows7AeroDark`, which this package
  provides. You can also flip just this in **Colors & Themes → Application Style**.
- The **Start menu** checks whether the active color scheme is dark and picks its light or dark colors
  on the fly, so it follows whatever you choose — including picking just a color scheme under
  **Colors & Themes → Colors**.

## What's included

| Part | Where it goes |
|---|---|
| `global-theme/` — the "Aero Dark" Global Theme (built from ATP's own at install time) | `~/.local/share/plasma/look-and-feel/aerodark/` |
| `color-schemes/AeroDark.colors` | `~/.local/share/color-schemes/` |
| `kvantum/Windows7AeroDark/` — dark recolor of ATP's Windows7Aero Kvantum theme | `~/.config/Kvantum/` |
| `startmenu/` — dark artwork and light/dark switching for the Start menu | a private copy of the Start menu in `~/.local/share/plasma/plasmoids/` |
| `helper/aerodark-sync` — switches the glass colour with the theme | `~/.local/bin/`, started from `~/.config/autostart/` |

## Install

```bash
./install.sh
```

Per-user only: nothing under `/usr` changes and no `sudo` is needed. It installs everything, switches
to Aero Dark, and restarts the Plasma shell once. Apps that are already open need a restart to change.

- `./install.sh --no-apply` — install only, and switch later in System Settings
- `./install.sh --no-startmenu` — leave the Start menu alone
- `./install.sh --no-accent` — don't switch the glass colour

**After updating AeroThemePlasma, run `./install.sh` again**, since the Global Theme and Start menu
are built from the installed copies of ATP's.

## The black glass (taskbar, title bars, Start menu)

The glass colour comes from AeroThemePlasma's window-colour setting, which a Global Theme can't
change by itself, so a small helper (`aerodark-sync`) does it. It starts with your session, and when
you switch to Aero Dark it remembers your glass colour and applies VistaVG black (hue 0, saturation 0,
brightness 8, intensity 200); when you switch back it restores your colour.

- Tweaks you make on the window-colour page **while in Aero Dark** are remembered as your dark glass;
  tweaks made in the light theme are remembered as your normal colour.
- AeroThemePlasma only saves a glass colour once you've clicked **Save Changes** on that page. If the
  installer warns about this, do that once with your normal colour.
- Don't want it? `./install.sh --no-accent`.

## Uninstall

```bash
./uninstall.sh
```

Switches back to AeroThemePlasma's Global Theme if Aero Dark is active, restores your glass colour,
then removes everything.

Credits: the Kvantum theme, Start menu artwork and Global Theme are based on AeroThemePlasma
(wackyideas, DrGordBord, Gamer95875 and contributors) and stay under its license (AGPL-3.0, see LICENSE).
