/*
 * Discord icon atlas exporter (for Aero Dark / Aero Light).
 *
 * Paste into Discord's developer console (Vesktop: Ctrl+Shift+I → Console) and press Enter.
 *
 * The first time, the console blocks pasting: type  allow pasting  and press Enter, then paste again.
 *
 * It reads EVERY icon component bundled in Discord's code — not just what's on screen — and saves
 * one file, discord-icons.zip, containing:
 *   discord-icons-page-01.png, -02.png, …   numbered sheets (dark icons on white, labels under each)
 *   discord-icons.json                     index → SVG paths, used to swap redrawn icons back in
 *
 * Icons that are visible right now are put first, so page 1 holds the ones you see most.
 * Settings: change PER_PAGE / ICON / COLS below if you want bigger or smaller sheets.
 */
(async () => {
    console.log('[icons] scanning Discord for icons…');
    const PER_PAGE = 36;      // icons per sheet (36 = 6×6 works well for image generators)
    const COLS = 6;
    const ICON = 96;          // drawn icon size in px
    const CELL_W = 150, CELL_H = 150;

    // 1. get Discord's webpack module cache (works with or without Vencord)
    let cache;
    if (window.Vencord?.Webpack?.cache) cache = Vencord.Webpack.cache;
    else {
        let req;
        window.webpackChunkdiscord_app.push([[Symbol()], {}, r => (req = r)]);
        window.webpackChunkdiscord_app.pop();
        cache = req.c;
    }

    // 2. find icon components: functions that render an <svg> made of <path d="…"> elements
    const seen = new Map();
    const pathRe = /"path",\{([^{}]*?)\}/g;
    const consider = fn => {
        if (typeof fn !== 'function') return;
        let src;
        try { src = Function.prototype.toString.call(fn); } catch { return; }
        if (src.length > 20000 || !src.includes('"svg"') || !src.includes('d:"')) return;
        const vb = (src.match(/viewBox:"([\d. ]+)"/) || [, '0 0 24 24'])[1];
        const paths = [];
        for (const m of src.matchAll(pathRe)) {
            const d = (m[1].match(/\bd:"([^"]+)"/) || [])[1];
            if (!d) continue;
            const rule = (m[1].match(/fillRule:"(\w+)"/) || [])[1];
            const stroke = /\bstroke:/.test(m[1]) && !/\bfill:/.test(m[1]);
            const sw = (m[1].match(/strokeWidth:"?([\d.]+)/) || [])[1];
            const path = { d };
            if (rule) path.rule = rule;
            if (stroke || (sw && !/\bfill:/.test(m[1]))) path.stroke = Number(sw || 2);
            paths.push(path);
        }
        if (!paths.length || paths.length > 12) return;
        const key = paths.map(p => p.d).join('|');
        if (!seen.has(key)) seen.set(key, { viewBox: vb, paths });
    };
    for (const mod of Object.values(cache)) {
        const ex = mod?.exports;
        if (!ex) continue;
        try {
            consider(ex);
            if (typeof ex === 'object') for (const k of Object.keys(ex)) consider(ex[k]);
            if (ex.default && typeof ex.default === 'object') for (const k of Object.keys(ex.default)) consider(ex.default[k]);
        } catch {}
    }
    let icons = [...seen.values()];

    // 3. visible icons first (matched by their first path), then the rest
    const onScreen = new Set([...document.querySelectorAll('svg path[d]')].map(p => p.getAttribute('d')));
    icons.forEach(i => (i.visible = i.paths.some(p => onScreen.has(p.d))));
    icons.sort((a, b) => b.visible - a.visible);
    icons.forEach((i, n) => (i.id = String(n + 1).padStart(4, '0')));
    console.log(`[icons] found ${icons.length} icons (${icons.filter(i => i.visible).length} on screen)`);

    // 4. draw pages
    const svgFor = i =>
        `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${i.viewBox}" width="${ICON}" height="${ICON}">` +
        i.paths.map(p => p.stroke
            ? `<path fill="none" stroke="#1b1b1b" stroke-width="${p.stroke}" stroke-linecap="round" stroke-linejoin="round" d="${p.d}"/>`
            : `<path fill="#1b1b1b" d="${p.d}"${p.rule ? ` fill-rule="${p.rule}"` : ''}/>`).join('') + `</svg>`;
    const load = s => new Promise(res => { const im = new Image(); im.onload = () => res(im); im.onerror = () => res(null);
        im.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s); });
    const files = [];
    const crcT = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
    const crc32 = b => { let c = ~0; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return ~c >>> 0; };
    const zip = list => {   // minimal uncompressed .zip
        const enc = new TextEncoder(), parts = [], central = []; let off = 0;
        for (const f of list) {
            const name = enc.encode(f.name), crc = crc32(f.data), n = f.data.length;
            const h = new DataView(new ArrayBuffer(30));
            h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint32(14, crc, true);
            h.setUint32(18, n, true); h.setUint32(22, n, true); h.setUint16(26, name.length, true);
            parts.push(h, name, f.data);
            const c = new DataView(new ArrayBuffer(46));
            c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint32(16, crc, true);
            c.setUint32(20, n, true); c.setUint32(24, n, true); c.setUint16(28, name.length, true); c.setUint32(42, off, true);
            central.push(c, name); off += 30 + name.length + n;
        }
        const size = central.reduce((a, x) => a + x.byteLength, 0), e = new DataView(new ArrayBuffer(22));
        e.setUint32(0, 0x06054b50, true); e.setUint16(8, list.length, true); e.setUint16(10, list.length, true);
        e.setUint32(12, size, true); e.setUint32(16, off, true);
        return new Blob([...parts, ...central, e], { type: 'application/zip' });
    };
    const save = (blob, name) => { const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name;
        document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 5000); };

    const pages = Math.ceil(icons.length / PER_PAGE);
    for (let p = 0; p < pages; p++) {
        const slice = icons.slice(p * PER_PAGE, (p + 1) * PER_PAGE);
        const rows = Math.ceil(slice.length / COLS);
        const c = document.createElement('canvas');
        c.width = COLS * CELL_W; c.height = rows * CELL_H;
        const g = c.getContext('2d');
        g.fillStyle = '#ffffff'; g.fillRect(0, 0, c.width, c.height);
        g.strokeStyle = '#e2e2e2';
        g.font = '600 15px "Segoe UI", sans-serif'; g.textAlign = 'center'; g.fillStyle = '#555';
        for (let n = 0; n < slice.length; n++) {
            const x = (n % COLS) * CELL_W, y = Math.floor(n / COLS) * CELL_H;
            g.strokeRect(x + 0.5, y + 0.5, CELL_W - 1, CELL_H - 1);
            const im = await load(svgFor(slice[n]));
            if (im) g.drawImage(im, x + (CELL_W - ICON) / 2, y + 14, ICON, ICON);
            g.fillText('#' + slice[n].id, x + CELL_W / 2, y + CELL_H - 14);
        }
        const blob = await new Promise(r => c.toBlob(r, 'image/png'));
        files.push({ name: `discord-icons-page-${String(p + 1).padStart(2, '0')}.png`, data: new Uint8Array(await blob.arrayBuffer()) });
        console.log(`[icons] drew page ${p + 1} of ${pages}`);
    }
    files.push({ name: 'discord-icons.json', data: new TextEncoder().encode(
        JSON.stringify(icons.map(({ id, viewBox, paths, visible }) => ({ id, viewBox, paths, visible })), null, 1)) });
    save(zip(files), 'discord-icons.zip');
    console.log(`[icons] saved discord-icons.zip (${pages} sheets + discord-icons.json)`);
})().catch(e => console.error('[icons] failed:', e));
