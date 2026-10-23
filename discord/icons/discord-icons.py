#!/usr/bin/env python3
"""
Discord icon atlas exporter, terminal version (for Aero Dark / Aero Light).
No DevTools needed: it downloads Discord's web app code straight from discord.com,
pulls every icon out of it, and draws numbered sheets.

    python3 discord-icons.py            # writes ./discord-icons/
    python3 discord-icons.py OUTDIR

Output: discord-icons-page-01.png … (6×6 numbered sheets, ready for the ChatGPT prompt),
        the same pages as .svg, and discord-icons.json (id → SVG paths, for swapping icons back in).
PNGs need one of: rsvg-convert (librsvg), magick (ImageMagick), inkscape, or python cairosvg.
Without any of them you still get the .svg sheets.
"""
import json, os, re, shutil, subprocess, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor

BASE = "https://discord.com"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
PER_PAGE, COLS, ICON, CELL = 36, 6, 96, 150


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.read().decode("utf-8", "replace")
    except Exception:
        return None


# ── 1. download the app's JavaScript ──────────────────────────────────────────
def download_bundle():
    html = get(BASE + "/app") or get(BASE + "/login")
    if not html:
        sys.exit("Couldn't reach discord.com.")
    entry = sorted(set(re.findall(r'src="(/assets/[^"]+\.js)"', html)))
    print(f"[icons] {len(entry)} entry scripts")
    texts = {}
    with ThreadPoolExecutor(8) as ex:
        for u, t in zip(entry, ex.map(lambda u: get(BASE + u), entry)):
            if t:
                texts[u] = t

    # lazy chunks: the webpack runtime maps chunk ids to hashes; also catch any literal asset names
    cands = set()
    for t in texts.values():
        cands.update("/assets/" + m for m in re.findall(r'["\'/]([\w.-]+\.[0-9a-f]{8,}\.js)["\']', t))
        for idm, hsh in re.findall(r'\b(\d{2,7}):"([0-9a-f]{12,24})"', t):
            cands.add(f"/assets/{idm}.{hsh}.js")
    cands -= set(texts)
    if cands:
        print(f"[icons] fetching up to {len(cands)} lazy chunks (a minute or two)…")
        done = 0
        with ThreadPoolExecutor(16) as ex:
            for u, t in zip(cands, ex.map(lambda u: get(BASE + u), cands)):
                done += 1
                if t and not t.lstrip().startswith("<"):
                    texts[u] = t
                if done % 200 == 0:
                    print(f"[icons]   {done}/{len(cands)}")
    print(f"[icons] {len(texts)} scripts, {sum(map(len, texts.values())) // 1_000_000} MB")
    return texts


# ── 2. pull icons out of the code ─────────────────────────────────────────────
def span(s, i):
    """index just past the bracket that closes the one at s[i] (skips strings)"""
    depth, q, j = 0, None, i
    while j < len(s):
        c = s[j]
        if q:
            if c == "\\":
                j += 2
                continue
            if c == q:
                q = None
        elif c in "\"'`":
            q = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return j


def extract(texts):
    icons, seen = [], set()
    for t in texts.values():
        for m in re.finditer(r'"svg",\{', t):
            # the children follow inside the same props object; take the whole jsx call
            call_end = span(t, t.rfind("(", 0, m.start()))
            block = t[m.start(): min(call_end, m.start() + 20000)]
            vb = re.search(r'viewBox:"([\d. ]+)"', block)
            paths = []
            for pm in re.finditer(r'"(path|circle|rect)",\{', block):
                props = block[pm.end() - 1: span(block, pm.end() - 1)]
                stroke = "stroke" in props and not re.search(r"\bfill:", props)
                sw = re.search(r'strokeWidth:"?([\d.]+)', props)
                rule = re.search(r'fillRule:"(\w+)"', props)
                if pm.group(1) == "path":
                    d = re.search(r'\bd:"([^"]+)"', props)
                    if not d:
                        continue
                    p = {"d": d.group(1)}
                elif pm.group(1) == "circle":
                    g = {k: re.search(rf'\b{k}:"?([\d.]+)', props) for k in ("cx", "cy", "r")}
                    if not all(g.values()):
                        continue
                    cx, cy, r = (float(g[k].group(1)) for k in ("cx", "cy", "r"))
                    p = {"d": f"M{cx - r} {cy}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0"}
                else:
                    g = {k: re.search(rf'\b{k}:"?([\d.]+)', props) for k in ("x", "y", "width", "height")}
                    if not (g["width"] and g["height"]):
                        continue
                    x = float(g["x"].group(1)) if g["x"] else 0
                    y = float(g["y"].group(1)) if g["y"] else 0
                    p = {"d": f"M{x} {y}h{g['width'].group(1)}v{g['height'].group(1)}h-{g['width'].group(1)}z"}
                if rule:
                    p["rule"] = rule.group(1)
                if stroke:
                    p["stroke"] = float(sw.group(1)) if sw else 2
                paths.append(p)
            if not paths or len(paths) > 12:
                continue
            key = "|".join(p["d"] for p in paths)
            if key in seen:
                continue
            seen.add(key)
            icons.append({"viewBox": vb.group(1) if vb else "0 0 24 24", "paths": paths})
    for n, i in enumerate(icons, 1):
        i["id"] = f"{n:04d}"
    return icons


# ── 3. draw sheets ────────────────────────────────────────────────────────────
def esc(s):
    return s.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")


def sheet(icons):
    rows = -(-len(icons) // COLS)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{COLS * CELL}" height="{rows * CELL}">',
           '<rect width="100%" height="100%" fill="#fff"/>']
    for n, i in enumerate(icons):
        x, y = (n % COLS) * CELL, (n // COLS) * CELL
        out.append(f'<rect x="{x + .5}" y="{y + .5}" width="{CELL - 1}" height="{CELL - 1}" fill="none" stroke="#e2e2e2"/>')
        out.append(f'<svg x="{x + (CELL - ICON) / 2}" y="{y + 14}" width="{ICON}" height="{ICON}" viewBox="{i["viewBox"]}">')
        for p in i["paths"]:
            if "stroke" in p:
                out.append(f'<path fill="none" stroke="#1b1b1b" stroke-width="{p["stroke"]}" stroke-linecap="round" '
                           f'stroke-linejoin="round" d="{esc(p["d"])}"/>')
            else:
                out.append(f'<path fill="#1b1b1b"{" fill-rule=%s" % chr(34) + p["rule"] + chr(34) if "rule" in p else ""} '
                           f'd="{esc(p["d"])}"/>')
        out.append("</svg>")
        out.append(f'<text x="{x + CELL / 2}" y="{y + CELL - 14}" text-anchor="middle" font-family="Segoe UI, Noto Sans, sans-serif" '
                   f'font-weight="600" font-size="15" fill="#555">#{i["id"]}</text>')
    out.append("</svg>")
    return "\n".join(out)


def to_png(svg, png):
    if shutil.which("rsvg-convert"):
        return subprocess.run(["rsvg-convert", "-o", png, svg]).returncode == 0
    if shutil.which("magick"):
        return subprocess.run(["magick", "-background", "white", svg, png]).returncode == 0
    if shutil.which("inkscape"):
        return subprocess.run(["inkscape", svg, "-o", png], capture_output=True).returncode == 0
    try:
        import cairosvg
        cairosvg.svg2png(url=svg, write_to=png)
        return True
    except ImportError:
        return False


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "discord-icons")
    os.makedirs(out, exist_ok=True)
    icons = extract(download_bundle())
    if not icons:
        sys.exit("No icons found — Discord may have changed how it ships its code. Tell Claude.")
    print(f"[icons] found {len(icons)} icons")
    pngs = True
    pages = -(-len(icons) // PER_PAGE)
    for p in range(pages):
        name = os.path.join(out, f"discord-icons-page-{p + 1:02d}")
        with open(name + ".svg", "w") as f:
            f.write(sheet(icons[p * PER_PAGE:(p + 1) * PER_PAGE]))
        pngs = pngs and to_png(name + ".svg", name + ".png")
    with open(os.path.join(out, "discord-icons.json"), "w") as f:
        json.dump(icons, f, indent=1)
    print(f"[icons] {pages} sheets written to {out}")
    if not pngs:
        print("[icons] no SVG→PNG converter found, so the sheets are .svg only. "
              "Install librsvg (rsvg-convert) and re-run for PNGs.")


if __name__ == "__main__":
    main()
