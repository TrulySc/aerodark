# Aero Dark for AeroThemePlasma — VistaVG Black look

A dark mode for [AeroThemePlasma](https://github.com/aeroshell-desktop/aerothemeplasma), styled after the
Black variant of Vishal Gupta's VistaVG Ultimate theme: neutral black glass, a silver gloss line on
buttons, Vista-blue glow for hover and selection, and amber for "new" items. Only the surfaces that used
to be white or light grey turn black/graphite; the green progress bar and yellow folders stay.

No artwork from VistaVG is included — the look was matched by hand.

## What's included

| Part | What it changes | Where it goes |
|---|---|---|
| `color-schemes/AeroDark.colors` | App backgrounds, text, selection, links | `~/.local/share/color-schemes/` |
| `kvantum/Windows7AeroDark/` | Buttons, fields, scrollbars, menus, tabs, checkboxes (a recolor of AeroThemePlasma's Windows7Aero Kvantum theme) | `~/.config/Kvantum/` |
| `startmenu/` | The Start menu's white left pane, search box and hover highlight | a private copy of the Start menu in `~/.local/share/plasma/plasmoids/` |

The window borders, taskbar and the right side of the Start menu are glass, and their tint comes from
AeroThemePlasma's own window color setting, so the installer doesn't change them. For the VistaVG Black
look, set that color yourself after installing (see below).

## Install

```bash
tar xf AeroDark.tar.gz
cd AeroDark
./install.sh
```

Everything is installed for your user only. Nothing under `/usr` changes, and you don't need `sudo`.
The Plasma shell restarts once so the Start menu picks up its new colors. Apps that are already open need to be restarted before they turn dark.

To keep the stock Start menu and only darken apps:

```bash
./install.sh --no-startmenu
```

## Make the glass black (one manual step)

VistaVG Black's title bars and taskbar are smoky black rather than blue. In AeroThemePlasma, open the
Aero glass **accent color** page (System Settings → the Aero Glass Blur effect's settings → accent color),
then pick a custom color of about **R 20, G 21, B 23** with the intensity slider near the top and
transparency left on. The taskbar and the Start menu's right side follow the same color.

## Uninstall

```bash
./uninstall.sh
```

This puts back the color scheme and Kvantum theme you had before and removes the private Start menu copy.

## Notes

- **After updating AeroThemePlasma**, run `./install.sh` again. The dark Start menu is a copy of the installed one, so it needs refreshing whenever the real one changes.
- If the installer warns that some Start menu colors weren't found, your AeroThemePlasma version has moved some code around. Everything else still applies.
- You can switch any part on or off by hand: the color scheme is in **System Settings → Colors**, and the widget style is in **Kvantum Manager → Change/Delete Theme**.

Credits: the Kvantum theme and Start menu artwork are recolored from AeroThemePlasma (DrGordBord, WackyIdeas, Gamer95875 and contributors), under that project's license.
