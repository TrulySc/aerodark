#!/usr/bin/env python3
"""
Use a pack of MSN Messenger emoticons for Discord's emoji (in the AeroEmoji theme).

    python3 import-emoticons.py msn-messenger-icons.zip      (or the unzipped folder)
    aerodark-discord-icons                                   # then regenerate

The emoticons are copied to ~/.local/share/aerodark/discord/emoticons/, named by the emoji they
stand for (1f60a.png = 😊). Emoji without an MSN emoticon keep your system emoji font. You can add
or replace any emoticon yourself: save an image there named by the emoji's code point(s), e.g.
1f355.png for 🍕 or 2764.png for ❤️ (https://emojipedia.org shows the code points).
"""
import os, re, shutil, sys, tempfile, zipfile

DATA = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
OUT = os.path.join(DATA, "aerodark", "discord", "emoticons")

# the pack's high-quality redraws (preferred) …
HQ = {
    "regular_smile": "🙂 ☺️ 😊", "teeth_smile": "😃 😀 😄 😁", "wink_smile": "😉",
    "omg_smile": "😮 😯 😲", "tongue_smile": "😛 😜 😝", "shades_smile": "😎",
    "angry_smile": "😠 😡", "red_smile": "😳", "confused_smile": "😕 😖", "sad_smile": "🙁 ☹️ 😞",
    "cry_smile": "😢 😭", "what_face": "😐 😑", "devil_smile": "😈 👿", "angel_smile": "😇",
    "kiss": "😘 😗", "47": "🤐", "48": "😬", "49": "🤓", "50": "😏", "51": "🤫", "52": "🤢 🤮",
    "72": "🤔", "74": "🥳", "77": "🙄",
}
# … and the classic set for everything else (MSN's own numbering)
CLASSIC = {
    "015": "❤️ ♥️", "016": "💔", "018": "🐱 🐈", "019": "🐶 🐕", "020": "🌙 🌜 🌛", "021": "⭐ 🌟",
    "022": "🎞️ 🎬", "023": "🎵 🎶", "024": "✉️ 📧", "025": "🌹", "026": "🥀", "027": "🕐 ⏰ 🕒",
    "028": "💋", "029": "🎁", "030": "🎂", "031": "📷 📸", "032": "💡", "033": "☕",
    "034": "📞 ☎️", "037": "🍺 🍻", "038": "🍸", "039": "👦", "040": "👧", "041": "👍",
    "042": "👎", "044": "🐐", "045": "🚌", "046": "☀️", "047": "🌈", "054": "🐌", "055": "🐢",
    "056": "🍽️", "057": "🍜", "058": "🍕", "059": "⚽", "060": "🚗", "061": "✈️", "062": "☂️ ☔",
    "063": "🏝️", "064": "💻", "065": "📱", "067": "⛈️", "068": "🤞", "069": "🖐️ ✋",
    "070": "💰", "071": "🐑", "078": "😪 😴", "079": "☮️", "080": "🐰 🐇", "101": "🚬",
    "106": "☝️",
}


def shrink(src, dst, size=64):
    """big still images are scaled to 64 px (plenty for Discord, and keeps the theme small)"""
    try:
        from PIL import Image
    except ImportError:
        return False
    im = Image.open(src)
    if getattr(im, "is_animated", False) or max(im.size) <= size:
        return False
    im = im.convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    im.save(dst)
    return True


def code(e):
    return "-".join(f"{ord(c):x}" for c in e if ord(c) != 0xFE0F)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = os.path.expanduser(sys.argv[1])
    if not os.path.exists(src):
        sys.exit(f"Not found: {src}\nCheck the name with:  ls ~/Downloads | grep -i msn")
    tmp = None
    if zipfile.is_zipfile(src):
        tmp = tempfile.mkdtemp()
        with zipfile.ZipFile(src) as z:
            for m in z.namelist():   # only images; nothing is run from the archive
                if re.search(r"\.(png|gif)$", m, re.I) and "__MACOSX" not in m and ".." not in m:
                    z.extract(m, tmp)
        src = tmp
    files = {}
    for root, _, names in os.walk(src):
        if "__MACOSX" in root:
            continue
        for n in names:
            stem, ext = os.path.splitext(n)
            if ext.lower() not in (".png", ".gif"):
                continue
            files.setdefault(("hq" if "high-quality" in root else "classic"), {})[stem.split("_")[0] if stem[:1].isdigit() else stem] = os.path.join(root, n)
    os.makedirs(OUT, exist_ok=True)
    done = 0
    for table, kind in ((CLASSIC, "classic"), (HQ, "hq")):       # HQ last, so it wins
        for key, emojis in table.items():
            f = files.get(kind, {}).get(key)
            if not f:
                continue
            for e in emojis.split():
                ext = os.path.splitext(f)[1].lower()
                for old in (".png", ".gif"):                        # replace any earlier pick
                    p = os.path.join(OUT, code(e) + old)
                    if os.path.exists(p):
                        os.remove(p)
                dst = os.path.join(OUT, code(e) + ext)
                if not shrink(f, dst):
                    shutil.copy(f, dst)
                done += 1
    if tmp:
        shutil.rmtree(tmp, ignore_errors=True)
    if not done:
        found = sum(len(v) for v in files.values())
        sys.exit(f"No emoticons imported: found {found} pictures in {sys.argv[1]}, but none named like the MSN "
                 "pack (001.png …, regular_smile.png …).")
    print(f"Imported {done} emoticons into {OUT}. Now run: aerodark-discord-icons")


if __name__ == "__main__":
    main()
