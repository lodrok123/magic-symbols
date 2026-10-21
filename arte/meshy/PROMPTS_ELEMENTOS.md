# Prompts de los assets de elementos sólidos: tierra, hielo y viento (21 de octubre de 2026)

Para los VFX de **tierra** y **viento** (y mejorar el **hielo**) de `docs/PLAN_EOW_VISUAL.md` §4: la tierra y el hielo se leen como **materia sólida** (terrones, bloques, cristales), no como partículas; el viento, como cintas y cosas arrastradas.
Mismo método que `PROMPTS_LAB_FUEGO.md` y `PROMPTS_PIEZAS_PUZLE.md`: o **una lámina por familia** (un solo *Text to 3D* con todas las piezas separadas en fila, que luego parte `arte/meshy/recibir_assets.py`: `ver` → `lote` → `instalar`), o **una pieza por generación**. Pega el bloque [ESTILO] **al final** de cada prompt. Al bajar: `arte/meshy/entrada/<id>.glb` → `python recibir_assets.py ver entrada\<id>.glb` → aprobar en `aprobacion3d/` → `instalar`.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, low contrast albedo,
no harsh baked shadows, no baked lighting, single object, centered, no base, no ground plane,
no background, no outline, no black lines.
```

## Reglas que NO son de estilo

1. **Pocos triángulos** (lo que pide el presupuesto, `arte/meshy/PRESUPUESTO.md` y `docs/estudios/eow/EOW_4_ASSETS.md` §6.6): cada pieza **300–1.500 triángulos**, textura **512²** (256² las pequeñas). Se ven pequeñas y muchas a la vez (un muro son 6–10 piezas, una ráfaga 10–20 terrones): en *target poly count* pon el número de cada título, no el de serie.
2. **Facetadas, no lisas:** caras planas grandes y aristas un poco redondeadas (como `pieza_puzle_3d.gd` y la roca de la lámina «puzle»). El volumen lo pone la luz; **sin oclusión pintada** y con poco contraste en el albedo.
3. **Sin color de elemento pintado ni brillo:** la tierra es de su material (marrón tierra, gris piedra: `Paleta3D` `TIERRA` 835832 / `TIERRA_FLANCO` DB8F59 / `PIEDRA` B8ADB8 / `PIEDRA_OSCURA` 7D747C); el hielo, casi blanco azulado translúcido **sin reflejos pintados** (la translucidez, el fresnel y la luz los pone el motor). Nada de lava, nada de llama, nada de magia brillante.
4. **Origen:** centro de la base, salvo donde se diga (los terrones que vuelan: en su centro). **Frente hacia +Z**, Y arriba.
5. **Medidas** (casilla = 2,3 u; la jugadora mide ~1): las de cada título; si Meshy no las respeta se escalan al integrar.
6. **Lo que se rompe va en piezas** que, juntas en su sitio, forman la pieza entera (mismo origen), igual que la roca de la lámina «puzle» (`roca_entera` + `roca_cascote_0..3`).

## Lo que YA hay y se reutiliza (no generar)

- **Hielo:** la **hoja de compuerta de hielo** (`compuerta_hoja_hielo`, lámina `puzle_terrain.glb`, ARTE §12) con su **textura de cristales**: sirve de **«pared» de hielo** (barrera y muro de hielo) y de referencia de material para todo lo de hielo. La **baldosa de hielo** del suelo (`arte/suelo_meshy/hielo_arriba.png`): la pisada helada y la placa del agua. El **`cubo_hielo`** (`arte/meshy/piezas/cubo_hielo.glb`): el bloque empujable. El **`tapon_hielo`** (lámina «forgotten»).
  → **Para todas las piezas de hielo de abajo, usa *Image to 3D* o *texture reference* con una captura de `compuerta_hoja_hielo`**, para que compartan el mismo cristal.
- **Tierra:** la **roca** de la lámina «puzle» (`roca_entera` + 4 cascotes) y las rocas musgosas del bosque: referencia de forma y de piedra. Las **losas** (`losa_runas_*`) para el suelo.
- **Viento:** no hace falta malla. Las briznas y hojas son **tarjetas 2D** (ver el final).

---

## 1. Tierra — lámina «terrones y muro» (`elem_tierra`)

**Para qué:** el proyectil de tierra (un terrón que vuela girando), sus cascotes al impactar (caen y se quedan un momento), y el muro/columna de tierra hecho de **bloques que emergen del suelo** en vez de una caja.

### Lámina completa (opción rápida)
> A game asset sheet of stylized earth and rock chunks laid out in a row with space between each piece: six faceted rounded clods of packed brown earth with some embedded small pebbles, each a different shape (from egg-shaped to flat to blocky), about the size of a fist to a melon; four small broken stone debris fragments with flat fracture faces; three chunky upright earth-and-stone pillar blocks with flat tops and slightly irregular faceted sides, like blocks pushed up from the ground, the bottom of each block rougher with clumps of soil; two short pointed earth spikes. Each piece separate and not touching. Earthy browns and warm greys, no grass, no moss, no glow.

Ids que salen al partirla (los pone `hoja.piezas.json` al aprobar):

| id | qué | medida | tris | textura | variantes |
|---|---|---|---|---|---|
| `terron_0..5` | terrón que vuela | 0,25–0,45 u, origen en su centro | 300–600 | 256² | 6 formas: el juego elige una al azar por proyectil |
| `cascote_0..3` | cascote de impacto | 0,1–0,2 u | 150–300 | 256² (la misma que los terrones) | 4 formas |
| `bloque_tierra_0..2` | bloque que emerge (muro, columna) | 0,9 × 1,0 × 0,9 u (casi media casilla de lado; apilables) | 600–1.200 | 512² | 3 formas; **cara de arriba plana** (se pisa) |
| `pincho_tierra_0..1` | estaca que sale del suelo (impacto fuerte) | 0,3 × 0,9 u | 300–500 | 256² | 2 |

### Piezas sueltas (si la lámina sale mezclada)
- **`terron`** (300–600 tris, 256): *A single faceted rounded clod of packed brown earth with a few embedded pebbles, fist-sized, chunky and slightly irregular.* — pide 2–3 generaciones para tener variedad.
- **`bloque_tierra`** (600–1.200 tris, 512): *A chunky upright block of packed earth and stone pushed up from the ground, flat walkable top, faceted slightly irregular sides, rougher crumbling bottom edge with clumps of soil.*
- **`bloque_tierra_roto`** (mismas medidas, en 4 trozos con el mismo origen): *The same earth block broken into four large chunks still standing in place, clean flat fracture faces.* (para cuando el muro se deshace).

## 2. Hielo — lámina «cristales» (`elem_hielo`) · con referencia de imagen de `compuerta_hoja_hielo`

**Para qué:** el proyectil de hielo (una esquirla), el impacto (racimo de cristales que brota y se funde), la escarcha sobre el suelo y la placa de hielo del agua que se rompe.

### Lámina completa
> A game asset sheet of stylized ice crystals laid out in a row with space between each piece, matching the reference ice texture: one sharp elongated ice shard with faceted sides; three ice crystal clusters of growing size (small, medium, large), each a group of hexagonal prism crystals growing from a common base at different angles; one flat thin ice plate broken into four pieces lying flat, edges slightly rounded; two thin frost spikes. Pale bluish white, translucent-looking, faceted, no reflections painted, no sparkles, no glow, no snow.

| id | qué | medida | tris | textura | variantes |
|---|---|---|---|---|---|
| `esquirla_hielo` | proyectil | 0,45 u de largo, origen en su centro, punta a +Z | 200–400 | 256² | 1 |
| `racimo_hielo_p/m/g` | impacto, barrera de hielo que brota, hielo que atrapa a un goblin | 0,4 / 0,8 / 1,4 u de alto | 400 / 700 / 1.200 | 512² | 3 tamaños |
| `placa_hielo_rota` | placa del agua al romperse: 4 piezas en su sitio (mismo origen) | 2,2 × 0,12 × 2,2 u (una casilla) | 400–800 en total | 512² (usa `hielo_arriba.png` si se parece) | 1 (+ la entera es la baldosa que ya hay) |
| `pincho_escarcha_0..1` | escarcha que sale al helar el suelo | 0,15 × 0,4 u | 100–200 | 256² | 2 |

**El «muro» y la «barrera» de hielo NO se piden:** salen de la hoja `compuerta_hoja_hielo` (la pared) o de racimos `g` en fila.

## 3. Viento — tarjetas 2D (no Meshy 3D)

El viento no es un objeto: son **cintas** (las hace el motor con mallas de tira) y **cosas arrastradas**. Lo único de arte es un **atlas 2D de 512 × 512 con fondo transparente**, 4 × 4 casillas, generado como imagen (no como modelo):
> A 4 by 4 sprite atlas on a transparent background, hand-painted stylized flat game sprites, soft pastel Ghibli style, no outlines: row 1, four different small green leaves seen from above; row 2, four autumn leaves in yellow and orange; row 3, four thin curved grass blades and seed fluffs; row 4, four soft white wind swirl strokes (curved brush strokes, semi-transparent). Each sprite centered in its cell, no overlap.

Va en `presentacion/vfx/viento_atlas.png`; las partículas eligen casilla al azar.

## Prioridad

1) **Tierra** (lámina 1): es el elemento más «caja» hoy. 2) **Hielo** (lámina 2, con la referencia). 3) **Atlas de viento**.
Hasta que lleguen, el Juego hace los VFX con **primitivas facetadas** del mismo tamaño y los mismos ids, así que al instalar los GLB el cambio es solo de malla (como `PiezaPuzle3D` y `PiezaFuego3D`: `usar_modelos`).
