# Prompts de todo lo que falta (5 de octubre de 2026)

Método de siempre: **una pieza por generación**. Para decorado, *Text to 3D* o *Image to 3D* con su
`referencias/<id>.png` si existe; para personajes, imagen de concepto con la referencia de estilo y luego
*Image to 3D* con rig. Pega el bloque [ESTILO] **al final** de cada prompt de decorado:

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

Al refinar: **target poly count** el de `docs/ASSETS_FALTANTES.md` (entre paréntesis en cada título) y
textura propia. Al bajar: `meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` → `CatalogoAssets` tecla H.

---

## Decorado — bloquean

### `cartel` (300–600 tris, 512)
> A wooden signpost for a forest village: one straight light-brown wooden post, slightly thicker at the base,
> with a single rectangular wooden plank nailed near the top, plank slightly tilted, visible wood grain, two
> small dark nail heads, **no text, no symbols, blank plank**. Chunky and friendly, 1.3 units tall.

### `baldosa_guardado` (150–300 tris, 512–1024)
> A square flat stone floor tile, grey stone with a beveled edge, slightly worn corners, and a **single large
> glowing rune carved in the center**, the rune emits a soft cyan light (emissive), a few small moss patches
> on one edge. Seen from above and 3/4, very flat (height 1/8 of its width).

### `pasadero` (200–400 tris, 512)
> A single rounded stepping stone to cross a stream: a flat grey river rock with a smooth top, slightly
> irregular oval shape, soft green moss on one side, a bit of wet darker stone at the base. Low and wide,
> height about 1/6 of its width.

### `seto_seco` (800–1 500 tris, 1024)
> A dry dead bush: a compact rounded dome of tangled dry brown branches and twigs with a few pale
> dead leaves, no green, dense enough to block the way, roughly as wide as it is tall (1 unit), sits
> directly on the ground. Chunky and readable, not wispy.

### `remolino_viento` (sprite 256², 2D, no 3D)
> Game VFX sprite, a single stylized wind swirl: a spiral gust with two curling tails, **light green**
> (#8FD46A) with paler highlights, hand-painted cartoon style, soft edges, transparent background, PNG
> 256×256, single object centered, no extra swirls, no background.

## Decorado — mejoras

### `arbusto` (500–900 tris, 512)
> A round leafy bush: a chunky dome of overlapping rounded leaf clusters in two greens (mid green and
> lighter yellow-green on top), small dark trunk base barely visible, **only green, no flowers, no pink,
> no fruit**. 1 unit tall.

### `arbusto_flores` (600–1 000 tris, 1024)
> The same round green bush with 5–7 **small round white and pale-yellow flowers** scattered on top, each
> flower a simple 5-petal shape with a yellow center, flowers clearly smaller than the leaf clusters, no
> pink, no red. 1 unit tall.

### `tocon` (200–400 tris, 512)
> A tree stump: a short wide cut trunk with light brown bark, the cut face on top **light tan wood with
> soft concentric rings**, a couple of root bumps at the base, a little moss on one side. No pink, no red
> tones. 0.6 units tall.

### `matas` (150–300 tris, 512) — solo si no se retira
> A small clump of grass: 3–4 tufts of soft green blades leaning outward, rounded chunky blades not thin,
> two greens, no flowers, no rocks, no crystals. 0.45 units tall.

### `oro` (100–200 tris, 256)
> A small pile of 3 chunky gold coins, two flat on the ground and one leaning, thick rounded edges, a
> simple embossed star on the face, warm yellow gold with soft highlights. 0.3 units tall.

### `puerta_pruebas` (2 000–3 000 tris, 1024)
> A stone archway gate for a trial chamber: two square stone pillars and a rounded arch, carved from
> grey-beige stone blocks with soft beveled edges, **six round empty rune sockets** set into the arch
> (three on each side, evenly spaced), each socket a shallow circular recess, a little moss at the base,
> no door leaf, open passage. 3.4 units tall, front view.
>
> (Las 6 runas encendidas son materiales emisivos por socket en Godot, no hace falta otro modelo.)

### `cartel_camara_<elemento>` ×6 — texturas, no modelos (6 × 512)
Usar el modelo `cartel`; pedir **seis imágenes 2D** de la tabla (una por elemento) para pintarlas en la
plank. Prompt de imagen, cambiando el color/símbolo:
> A hand-painted wooden sign plank texture, flat front view, light wood grain, with a single bold painted
> symbol in the center: **[fire: an upward flame, orange-red #F2551E] / [water: three wavy lines, blue
> #2A9DFB] / [ice: a six-point snowflake, light cyan #5ECFF5] / [earth: a rounded mountain with a dot,
> ochre #C8875A] / [wind: a three-tail swirl, green #8FD46A] / [lightning: a zigzag bolt, yellow #F2C63C]**,
> painted with slightly worn edges, no text, no border, square 512×512.

### `plate_trial_<elemento>` ×6 — texturas (6 × 512)
Mismo modelo que `baldosa_guardado`; seis texturas de la cara superior con el símbolo del elemento
(usar la lista de símbolos y colores de arriba): "grey stone tile top, beveled edge, a single carved
glowing [symbol] in [color], flat top view, square 512×512".

## VFX sin satélites (sprites 256², 2D)
Para los cinco, mismo esqueleto; cambia solo la pieza:
> Game VFX sprite, hand-painted cartoon style, soft edges, transparent background, PNG 256×256,
> **exactly one object centered, no extra copies, no small floating pieces, no background**:
- `burbuja`: a single translucent soap bubble with a soft highlight, pale blue and lilac tints.
- `gota`: a single rounded water drop, bright blue with a white highlight, pointed top.
- `hoja`: a single fresh green leaf, slightly curved, lighter vein in the middle.
- `brasa`: a single glowing ember, orange-red core with a yellow highlight and a soft dark edge.
- `petalo`: a single pink flower petal, slightly curled, lighter at the base.
- `llama` (solo si no se usa `llama_tira8`): a single cartoon flame, orange with yellow core, **with clear
  empty margin on all sides**, the flame not touching the image border.

## Personajes

### `goblin_archer_chibi` (8 000–12 000 tris, 2048) — imagen de concepto con `referencias/goblin_referencia.png`
> The same goblin character as the reference image, same stylized chibi 3D game style, same proportions
> (big head, short stubby legs, 3 heads tall), same soft hand-painted texture and warm earthy palette
> (saturated muted green skin, tan leather, cream bandages). This one is an archer: a **dark brown hooded
> cloak with the hood up**, the hood part of the body, shadowing the top of the face so only the big eyes
> and the pointed ears poking out of the hood are visible; short dark-brown tunic under the cloak, a
> leather strap across the chest with a small cream quiver on the back, cloth bandages on forearms and
> shins like the warrior, bare feet. Slightly leaner and more upright than the warrior but the same
> silhouette language. Relaxed A-pose, arms slightly away from the body, **empty hands, no bow, no
> arrows**. Full body, front and 3/4 views side by side, plain light background, soft even lighting, no
> outline strokes.

Meshy: *stylized chibi game character, single character, A-pose, empty hands, hooded cloak as part of the
body mesh, no weapon* → rig humanoide. Clips a pedir: `idle`, `walk`, `walk_back`, `run`,
`archery_shot`, `aim`, `alert` (grito al detectar), `hit_reaction`, `electrocution_reaction`, `dead` (+ `dodge`).

### `arco` para `equipo\` (300–600 tris, 512)
> A short wooden bow for a goblin archer: a curved light-brown wooden limb with a cream cloth-wrapped
> grip in the middle, a taut pale string, two small leather bindings near the tips. Chunky rounded
> shapes, friendly, not realistic. Single object, standing vertically, full object visible, front view.
>
> (Al integrar: mango en el origen, puntas hacia ±Y, ~0,5 u de alto.)

### `alchemist_chibi` (8 000–12 000 tris, 2048) — imagen de concepto con `referencias/bookseller_referencia.png`
> A new character in the same stylized chibi 3D game style as the reference image: same proportions
> (3 heads tall, big head, short legs), same soft hand-painted pastel texture, chunky rounded shapes,
> clean simple silhouette. A young male elf alchemist: pointed ears, **short messy dark auburn hair**,
> confident slight smile. A **long bright red coat, hood down, reaching mid-calf, open at the front**,
> showing a **black sleeveless undershirt**, dark grey trousers tucked into brown leather boots, and
> **white work gloves**. On his belt two large glass potion vials (one green, one blue) and a small brass
> alembic charm. Palette: red coat, black undershirt, white gloves, warm brown leather, brass details.
> Relaxed A-pose, empty hands, full body, front and 3/4 views side by side, plain light background,
> soft even lighting, no outline strokes.

Meshy: *stylized chibi game character, single character, A-pose, empty hands, long coat as part of the
body mesh* → rig humanoide. Clips: `idle`, `talk_with_left_hand_raised`, `walk`.

### `goblin_warrior_chibi` v2 (solo si molesta a 50–75 px) — con `goblin_referencia.png`
> The same goblin warrior as the reference image, same style, proportions and clothes, but with **short
> cropped dark hair that leaves the whole face visible** (big eyes, big nose, pointed ears clearly seen)
> and **saturated green skin** (clearly green, not pale or beige). Relaxed A-pose, empty hands, front and
> 3/4 views, plain light background, soft even lighting.

## Suelo (solo si se quiere textura de hielo)
### `hielo_arriba.png` (1024², sin costuras)
> Seamless tileable hand-painted ice texture, top view, pale cyan and white with soft cracks and a few
> frosted patches, cartoon style matching a pastel painted water texture, no objects, no snowflakes,
> square 1024×1024, tileable on all four edges.
