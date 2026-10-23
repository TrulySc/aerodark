# Prompt for redrawing Discord's icons as skeuomorphic Aero icons

Use the sheets in `icons/redraw/` (`redraw-page-01.png` … `-14.png`). They hold only the icons that
icon themes don't have; everything else already comes from your Plasma icon theme. Pages 01–11 are
interface icons; 12–14 are the smiley faces on the emoji button, so they can wait.

One message per page: attach the sheet and paste the prompt below. A fresh chat for each page
works best.

---

This sheet shows 36 flat black pictograms in a 6×6 grid, each with a number label (#0005 …).
I'm commissioning a set of skeuomorphic desktop icons in the style of Mac OS X Leopard / Snow
Leopard, iPhone OS 3–6 and Windows Vista / Windows 7 (2007–2012), one for each pictogram. Reply
with the image only — no written explanation.

THINK FIRST, SILENTLY
Before painting, for each pictogram work out what it MEANS in a chat app, then invent the real,
physical object an icon designer of that era would have photographed or sculpted to say the same
thing, and paint that object. Treat my sheet ONLY as a map of where each number goes: do not copy,
trace or follow the shapes of the black pictograms at all — each icon is designed from scratch.

CONCEPTS
- Think like the designers of Apple's old Mail stamp, iChat bubbles, Address Book, iCal's
  leather-and-paper calendar, Preview's loupe, Stickies, the GarageBand guitar, Windows 7's Recycle
  Bin and Control Panel objects. Every icon is a believable thing you could hold: made of glass,
  brushed aluminium, chrome, glazed ceramic, enamel, leather, paper, rubber, wood, felt, frosted
  plastic.
- Never just "a glossy version of the glyph". An arrow might become a curved chrome pipe, a road
  sign or a folded paper arrow; a speech bubble an iChat-style glass bubble or a ceramic sign; a
  list a ruled notepad page with a pen; signal bars a little brushed-metal equaliser with glowing
  LEDs; a letter "A" a wooden typeset block or a keyboard key.
- Colour comes from the object's material, not from a theme. Use a rich, varied palette across the
  sheet — warm woods, leather browns, brass, enamel reds, mint and lime greens, amber, cream paper,
  graphite, frosted aqua glass. At most a third of the icons may be mainly blue.
- Overlay badges (plus, minus, clock, cross, refresh, warning) become separate small objects — an
  enamel pin, a glass bead, a little clock face, a rubber stamp — sitting on the lower-right corner
  of the main object.
- Each concept must stay recognisable at 24×24 pixels: one main object, a bold silhouette.

STYLE
Showcase-quality skeuomorphic icons from the golden age of glossy desktop icons (Mac OS X
Leopard, iPhone OS, Windows Vista/7), in the Frutiger Aero spirit. Each icon is a crafted 3D
object, "more realistic than illustrative, but not quite photorealistic — better than
photorealistic": a flawless studio product photograph of a sculpted miniature. Authentic, crisp,
tactile, optimistic. Real materials with real surface qualities — the grain of wood, the stitching
of leather, the fine brushing of aluminium, the depth of thick glass, the soft sheen of enamel —
idealised and clean, never dirty or busy. No outlines anywhere: every edge is defined by light,
shadow and reflection.

GLOSS: A TOUCH SOFTER
Keep the glossy finish, but slightly toned down: highlights a little smaller and softer, with less
wet-look shine, so the materials underneath show through. Not every surface needs a reflection —
leather, wood, paper and brushed metal can have a gentle satin sheen next to the glossier glass
and enamel.

CAMERA
A slight three-quarter view from a little above, so every object shows its top surface and real
thickness, with gentle perspective. Objects that are flat in real life (paper, signs, cards) are
shown tilted with a visible edge.

LIGHTING (identical for all 36)
One soft key light above, in front and to the LEFT, like a studio softbox; highlights on
upper-left surfaces, form shadows wrapping to the lower right. A cool soft fill from the right
keeps shadows luminous. A thin bright rim light along the lower and right edges. Glass gets a
crisp window-shaped reflection and an inner caustic glow; metal reflects a bright sky.

READABILITY
Bold, simple silhouettes that read instantly at 24 pixels; detail lives in materials and light,
never in tiny lines or text. Each object fills about 80% of its cell, centred.

LAYOUT (STRICT — the icons are cut out of the grid automatically)
- The same 6 columns × 6 rows and order as my sheet: the icon for #0005 goes where #0005 was.
- Keep every number label exactly as written, centred under its icon, in plain dark grey text.
- Each cell on a completely flat, solid pure white (#FFFFFF) background with thin light-grey cell
  borders. No ground shadow, reflection, glow or halo outside the object, no scenery, no extra
  text, no title.

Output one image: the complete 6×6 sheet.

---

## Tips

- Looks traced: *"These still follow the black pictograms. Repaint each as a real object with real
  materials, as if you had never seen my sheet."*
- Everything one colour: *"Use each object's natural material colours; no more than a third of the
  icons mainly blue."*
- Layout changed or numbers missing: *"Keep the exact 6×6 grid and every #number label in the same
  position as the original sheet."*
- An icon doesn't fit what it's for: tell it the number and what the icon does (hover it in Discord
  to check).
- Save each result as `aero-icons-page-XX.png`, with the same number as the sheet you gave it, then:

  ```sh
  python3 ~/.local/share/aerodark/discord/import-redrawn-icons.py aero-icons-page-*.png
  aerodark-discord-icons
  ```

  The first command cuts the sheets into the AeroDiscord icon set; the second puts them into Discord.
  Restart Vesktop (or toggle the AeroIcons theme off and on) to see them.
