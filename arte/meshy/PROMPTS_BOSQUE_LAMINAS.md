# Láminas de bosque para Meshy (16 de octubre de 2026)

Las generaciones de Meshy que hemos medido (las tres láminas, la pluma y las manos) salen todas entre 15 000 y 16 500 triángulos, **sea cual sea el objeto**: un tronco solo se queda con todos, y por eso sale tan pesado. Con una **lámina** (varias piezas en una imagen)
ese presupuesto se reparte entre todas, y yo las separo después (mismo método que «Verdant Timber Ruins», «Medieval Camp Props» y «Rustic Camp Toolkit»; ver `docs/ARTE.md` §14–15).

## Cómo
1. Genera la imagen de la lámina con un generador de imágenes (prompt «imagen» de abajo), con una referencia de estilo adjunta (tu grimorio o la lámina «Verdant Timber Ruins»).
2. Súbela a Meshy con **Image to 3D**, textura 2048, sin pedir polígonos concretos.
3. Adjunta el GLB: lo separo, pongo el origen y la escala de cada pieza, lo integro y lo dejo documentado.

**Reglas para que se puedan separar** (importan más que el estilo):
- Las piezas **no se tocan ni se solapan**, con un hueco amplio entre ellas (al menos el ancho de una pieza pequeña). Piezas que se tocan salen fundidas en un solo bloque.
- Todas **a la misma escala relativa realista** entre sí, vistas desde 3/4 un poco desde arriba, sin suelo ni sombra. Fondo liso claro.
- **Nada de texto, ni símbolos, ni brillo pintado**, y sin agua pintada.
- Las piezas largas (tronco) **tumbadas a lo largo del eje X** de la imagen; todas con el frente hacia la cámara.

[ESTILO] (al final de cada prompt de imagen):
`Stylized chibi anime game asset sheet, hand-painted texture, soft pastel colors, Ghibli-inspired, cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows, plain light background, no outline, no black lines, no text.`

---

## LÁMINA 1 · Orilla del estanque (la del tronco)

Piezas (id · medida en unidades de juego; la jugadora mide ≈ 1, una casilla = 2,3):
| id | qué es | medida |
|---|---|---|
| `tronco_estanque` | tronco grueso caído con musgo arriba, tumbado en X | 2,6 × 0,6 (Ø) |
| `tocon_musgo` | tocón ancho con musgo y un helecho | Ø 0,9 × 0,5 |
| `roca_musgo_g` / `roca_musgo_m` / `roca_musgo_p` | tres rocas redondeadas con musgo, grande, mediana y pequeña | 1,2 / 0,7 / 0,35 |
| `juncos` | matas de juncos y espadañas de orilla | 0,8 × 1,1 alto |
| `nenufar_a` / `nenufar_b` | dos nenúfares planos con una flor rosa, **sin agua** | Ø 0,7 / Ø 0,5 |
| `helecho_grande` | helecho de seis frondas curvas | 0,9 × 0,7 alto |
| `setas_grupo` | racimo de 4–5 setas de tamaños distintos, sombrero crema y rosa | 0,5 × 0,35 alto |

**Prompt (imagen):**
> A prop sheet for a cozy forest pond shore, nine separate objects laid out in a loose grid with wide empty space between them, none touching: a thick fallen mossy log lying horizontally, long and chunky, dark damp bark with a few knots, thick bright green moss on top, vines hanging off the sides, flat cut ends with visible rings; a wide mossy tree stump with a small fern; three rounded mossy rocks in large, medium and small sizes; a clump of tall reeds and cattails; two flat round lily pads, one with a pink flower, with no water; a big fern with six curled fronds; a cluster of four or five little mushrooms in cream and pink. All at consistent relative scale, seen from three-quarter view slightly from above, evenly lit, no ground, no shadows.
> + [ESTILO]

---

## LÁMINA 2 · Sendero y claro del bosque

| id | qué es | medida |
|---|---|---|
| `cartel_bosque` | cartel de madera en poste, **tablilla en blanco** | 0,9 × 1,6 alto |
| `valla_tramo` | tramo de valla de madera rústica con dos postes | 2,0 × 0,9 alto |
| `seto_seco_2` | seto seco y redondo de ramas, sin hojas, rehaciendo el viejo (que salió plano) | 1,6 × 1,0 alto |
| `arbusto_flores_2` | arbusto esponjoso con florecillas rosas y blancas | 1,2 × 1,0 alto |
| `tronco_hueco` | tronco corto, vertical y hueco, con musgo | Ø 0,8 × 1,1 alto |
| `troncos_apilados` | pila de 5 leños cortados | 1,0 × 0,6 alto |
| `hojas_montón` | montón bajo de hojas caídas verdes, doradas y rojizas | Ø 0,9 × 0,25 alto |
| `raiz_grande` | raíz gruesa y retorcida que asoma del suelo (arco) | 1,4 × 0,6 alto |
| `piedras_sendero` | tres piedras planas de pasadero | Ø 0,5 cada una |

**Prompt (imagen):**
> A prop sheet for a cozy forest trail clearing, nine separate objects in a loose grid with wide empty space between them, none touching: a wooden signpost with a blank wooden board; a short stretch of rustic wooden fence with two posts; a round bare dry bush of twisted branches without leaves; a fluffy round bush with small pink and white flowers; a short upright hollow mossy log; a neat stack of five cut firewood logs; a low pile of fallen leaves in green, gold and rust colors; a thick twisted tree root arching out of the ground; three flat stepping stones. All at consistent relative scale, seen from three-quarter view slightly from above, evenly lit, no ground, no shadows, **no writing on the sign**.
> + [ESTILO]

---

## LÁMINA 3 · Arbustos (para sustituir a `arbusto_flores`, 16/10, pedido de Pablo)

El actual (`arbusto_flores`) es una bola verde azulada con bultos rosas translúcidos y no pega con la hierba nueva (amarillo-verde, más saturada). Esta lámina da **seis arbustos distintos** para repartir por el nivel; si alguno no gusta, se usa otro. Verde **amarillento y cálido** (no azulado), hojas en mechones blandos, **nada de bultos puntiagudos ni cristalinos**.
| id | qué es | medida |
|---|---|---|
| `arbusto_a` | arbusto redondo y espeso de hojas verdes, sin flores | 1,2 × 0,9 alto |
| `arbusto_b` | el mismo tipo, con florecillas blancas y rosa pálido entre las hojas | 1,2 × 0,9 alto |
| `arbusto_c` | arbusto con bayas rojas pequeñas | 1,1 × 0,9 alto |
| `arbusto_d` | mata baja y ancha de hojas lanceoladas | 1,5 × 0,6 alto |
| `arbusto_e` | arbusto alto y estrecho, hojas en mechones hacia arriba | 0,8 × 1,4 alto |
| `arbusto_f` | arbusto espeso de verde más oscuro, con un par de ramitas secas asomando | 1,3 × 1,0 alto |

**Prompt (imagen):**
> A prop sheet of six separate bushes for a cozy forest, laid out in a loose grid with wide empty space between them, none touching: a round dense leafy bush in warm yellow-green; the same kind of bush with small white and pale pink flowers among the leaves; a bush with tiny red berries; a low wide shrub of long pointed leaves; a tall narrow shrub with leaf tufts pointing upward; a dense darker green bush with a couple of dry twigs sticking out. Soft rounded clumps of overlapping leaves, warm yellow-green palette, no teal or blue greens, no spiky or glassy bumps. All at consistent relative scale, seen from three-quarter view slightly from above, evenly lit, no ground, no shadows.
> + [ESTILO]

---

## Si prefieres piezas sueltas
Un objeto por generación ha salido siempre a ≈ 15 000 triángulos. Para un tronco de 0,6 de grosor es mucho: mejor la lámina 1, o decimar después (lo hago yo).
