#!/usr/bin/env python3
"""
Cut ChatGPT's redrawn sheets into an icon theme (AeroDiscord) that aerodark-discord-icons uses
for the Discord icons your Plasma icon theme doesn't have.

    python3 import-redrawn-icons.py aero-icons-page-01.png aero-icons-page-02.png …
    aerodark-discord-icons          # then regenerate the Discord icon theme

Name each result after the sheet you gave ChatGPT (redraw-page-03.png → aero-icons-page-03.png),
so the script knows which icons are on it. Needs Pillow (sudo pacman -S python-pillow).
Re-importing a page replaces its icons, so you can redo any page you're not happy with.
"""
import json, os, re, sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Needs Pillow: sudo pacman -S python-pillow")

HERE = os.path.dirname(os.path.realpath(__file__))
DATA = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
THEME = os.path.join(DATA, "icons", "AeroDiscord")
SIZES = (16, 24, 32, 48)
COLS = 6


def load_pages():
    for p in (os.path.join(HERE, "redraw", "redraw-pages.json"), os.path.join(HERE, "redraw-pages.json"),
              os.path.join(DATA, "aerodark/discord/redraw-pages.json")):
        if os.path.isfile(p):
            return json.load(open(p))
    sys.exit("redraw-pages.json not found (keep it in the redraw folder next to this script).")


def clear_background(im):
    """make the white sheet background transparent, keeping white highlights inside icons"""
    im = im.convert("RGBA")
    w, h = im.size
    seeds = [(x, 0) for x in range(0, w, 6)] + [(x, h - 1) for x in range(0, w, 6)] + \
            [(0, y) for y in range(0, h, 6)] + [(w - 1, y) for y in range(0, h, 6)]
    px = im.load()
    for s in seeds:
        r, g, b, a = px[s]
        if a and min(r, g, b) > 225:
            ImageDraw.floodfill(im, s, (255, 255, 255, 0), thresh=40)
    # soften the leftover light fringe the anti-aliasing leaves against the old white
    px = im.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and min(r, g, b) > 238:
                near = any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 0
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    px[x, y] = (r, g, b, 90)
    return im


def cut(sheet, count):
    rows = -(-count // COLS)
    W, H = sheet.size
    cw, ch = W / COLS, H / rows
    for n in range(count):
        x0, y0 = (n % COLS) * cw, (n // COLS) * ch
        # icon area: inside the cell borders, above the #number label
        box = (int(x0 + cw * 0.05), int(y0 + ch * 0.03), int(x0 + cw * 0.95), int(y0 + ch * 0.80))
        icon = clear_background(sheet.crop(box))
        bb = icon.getbbox()
        if not bb:
            yield None
            continue
        icon = icon.crop(bb)
        side = max(icon.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.paste(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        yield sq


def write_index():
    os.makedirs(THEME, exist_ok=True)
    dirs = ",".join(f"{s}x{s}/apps" for s in SIZES)
    with open(os.path.join(THEME, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=AeroDiscord\nComment=Windows 7-style icons for Discord's own symbols "
                "(made for Aero Dark)\nHidden=true\nInherits=hicolor\n"
                f"Directories={dirs}\n\n")
        for s in SIZES:
            f.write(f"[{s}x{s}/apps]\nSize={s}\nContext=Applications\nType=Fixed\n\n")


def main():
    files = sys.argv[1:]
    if not files:
        sys.exit(__doc__)
    pages = load_pages()
    write_index()
    total = 0
    for path in files:
        m = re.search(r"(\d+)\D*$", os.path.basename(path))
        if not m or not 1 <= int(m.group(1)) <= len(pages):
            print(f"skipping {path}: name it aero-icons-page-NN.png with the sheet's page number")
            continue
        slugs = pages[int(m.group(1)) - 1]
        sheet = Image.open(path).convert("RGB")
        done = 0
        for slug, icon in zip(slugs, cut(sheet, len(slugs))):
            if icon is None:
                continue
            for s in SIZES:
                d = os.path.join(THEME, f"{s}x{s}", "apps")
                os.makedirs(d, exist_ok=True)
                icon.resize((s, s), Image.LANCZOS).save(os.path.join(d, slug + ".png"))
            done += 1
        print(f"{os.path.basename(path)}: {done} of {len(slugs)} icons")
        total += done
    print(f"Imported {total} icons into {THEME}. Now run: aerodark-discord-icons")


if __name__ == "__main__":
    main()
