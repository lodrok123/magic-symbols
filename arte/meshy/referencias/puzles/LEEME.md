# Láminas de puzles para Meshy

Referencias de la primera tanda del [catálogo de puzles](../../../../docs/PUZLES_LOGICA_Y_ASSETS.md). Generadas con la herramienta integrada de imágenes de Codex.

## Modelos 3D

Sube [la lámina conjunta](lamina_puzles_3d.png) a Image to 3D. De izquierda a derecha están el marco, el brote y el peldaño. Hay espacio transparente entre las tres piezas y en el centro del marco. Si Meshy entrega las tres en el mismo GLB, sepáralas por pieza antes de importarlas al juego.

La lámina se generó con la herramienta integrada de imágenes de Codex a partir de los tres PNG individuales, con una vista por pieza y sin texto, suelo ni sombras. Se retiró el fondo en una segunda pasada.

| PNG | Qué conservar al revisar el GLB |
|---|---|
| `p07_borde_bancal.png` | Marco bajo con centro completamente abierto. El suelo del juego ocupa el hueco. Origen en el centro de la base. |
| `p07_brote_vivero.png` | Silueta de hojas grandes y separadas. Origen en la base del tallo. |
| `p03_huella_peldano.png` | Piedra rota muy baja con base plana. La jugadora conjura el escalón sobre la misma casilla. La pieza se monta sin colisión. |

## Texturas

- `p04_grabado_rayo.png` se aplica al receptor rúnico existente y debe leerse con el receptor apagado.
- `p05_hollin_galeria.png` va a ras del suelo. Su longitud se ajusta a la zona de disparo de la trampa.

## Prompts de generación

### p07_borde_bancal

Referencia de estilo `pantano_meshy_01_estructuras.png`.

Stylized-concept, 3D game asset input for Meshy Image-to-3D. One isolated object and one single camera view, centered square canvas, generous 12% margins, complete visible silhouette. Stylized hand-painted fantasy game prop, warm muted materials, broad clean beveled forms, flat even studio light, no text, no labels, no cast shadow, no floor plane, no side objects. If a style sheet is supplied, use only the style, never copy its subjects or multi-object layout. A very low square open ring edging for a single swamp garden plot, four continuous sides, two short weathered horizontal cedar rails on opposite sides alternating with rows of broad taupe stone edging on the two other sides, connected by four squat stone corner blocks. A few olive moss stains painted onto stone. Truly empty square hole, 75 percent of the full width, transparent through the center, no dirt, water, base plate, plants, tall posts or stakes. At most 1:12 ratio of height to width. Shallow isometric view from 55 degrees above, all four sides visible and unambiguous opening.

### p07_brote_vivero

Referencia de estilo `pantano_meshy_01_estructuras.png`.

Stylized-concept, 3D game asset input for Meshy Image-to-3D. One isolated object and one single camera view, centered square canvas, generous 12% margins, complete visible silhouette. Stylized hand-painted fantasy game prop, warm muted materials, broad clean beveled forms, flat even studio light, no text, no labels, no cast shadow, no floor plane, no side objects. If a style sheet is supplied, use only the style, never copy its subjects or multi-object layout. One little magical wetland seedling with a sturdy curving stem, three bold broad waxy jade and lime leaves, and a small curled young leaf at its tip. Stylized folded leaf planes with one broad central vein per leaf and hints of warm yellow green toward tips. A short stem with flat cutoff at ground, no roots, no pot, no soil, no light effects. Each leaf clearly separated in silhouette. Three-quarter eye-level view looking slightly down.

### p03_huella_peldano

Referencia de estilo `baldosa_guardado_meshy.png`.

Stylized-concept, 3D game asset input for Meshy Image-to-3D. One isolated object and one single camera view, centered square canvas, generous 12% margins, complete visible silhouette. Stylized hand-painted fantasy game prop, warm muted materials, broad clean beveled forms, flat even studio light, no text, no labels, no cast shadow, no floor plane, no side objects. If a style sheet is supplied, use only the style, never copy its subjects or multi-object layout. One damaged, extremely shallow square stone stair footprint from an ancient cave ruin, a low thin single slab with blunt broken front edge and a shallow rectangular inset showing where the missing higher step belongs. Gray muted taupe sandstone, broad polished plane, two readable chips, sparse muted olive lichen in one corner. Height less than 1/14 of width. All fragments remain attached to the slab. No luminous rune, pedestal, additional stairs, chunks around it or raised sides. Three-quarter top view from 50 degrees above so top and thinness are clear.

### p04_grabado_rayo

Stylized-concept. One flat 2D decal artwork for the face of a hand-painted stone fantasy rune receiver in a game. Exact orthographic straight-on view. One centered broad angular single lightning bolt mark, with a clear zig and pointed downward end. Main dark slate recessed engraved shape with a narrow weathered warm-gray cut-edge highlight entirely inside the symbol. Strong readable silhouette, subtle stone-tool edge wear, no emission, no background stone, no plaque, no surrounding objects, no circular border, no letters. True alpha transparency everywhere around the bolt, generous clear margins. Square canvas.

### p05_hollin_galeria

Stylized-concept. Top-down orthographic game texture decal of a long horizontal scorched soot trail from a continuous dragon flame, one isolated mark with dark desaturated warm charcoal center, broad readable taper and softly broken jagged stylized feathered edges. Approximate overall silhouette 4:1 width to height, uneven organically tapered ends and completely transparent surroundings with enough margins. Hand-painted stylized fantasy, clear enough from an overhead gameplay camera. Charcoal soot only, no stone floor, fire, embers, cracks, glow, typography, scene or objects.

