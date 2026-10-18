# Regenerar el catálogo de assets: prompts de las 36 piezas (17 de octubre de 2026)

Pablo quiere **regenerar todos los objetos de `CatalogoAssets`** (`bosque.glb` 13 + `objetos.glb` 13 + `magia.glb` 10 = 36 piezas). Aquí hay un prompt por pieza con su id, su medida en el juego y lo que el motor
espera de ella. Mismo método que `PROMPTS_PIEZAS_PUZLE.md`: **una pieza por generación** (*Text to 3D*, o *Image to 3D* si generas antes una imagen de referencia con el prompt), el bloque
[ESTILO] **pegado al final** de cada prompt, y al bajar: `meshy\entrada\<id>.glb` (renombrado con su id) → `INTEGRAR_PIEZAS.cmd` → `CatalogoAssets` tecla **H**. Si Meshy no respeta la medida o pasa de
5.000 triángulos, la escalo y la decimo yo al integrar (Meshy da ≈ 15.000 triángulos por generación sea cual sea el objeto: pide *target poly count* 5.000, y 3.000 en las pequeñas).

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas comunes (valen para las 36; importan más que el estilo)
1. **Origen en el centro de la base** (y = 0 el suelo), **frente hacia +Z**, sin suelo ni sombra pintada. Medidas en unidades de juego (**la jugadora mide ≈ 1; una casilla = 2,3**): la primera cifra es el **alto** del juego (`Pieza3D.MEDIDA`); si
   la pieza se mide por ancho (`MEDIDA_ANCHO`) se dice «ancho».
2. **Paleta cerrada del bosque** (`docs/ARTE.md` §10): hierba amarillo-verdosa y **cálida** (no azulada), madera `#8C5C33`, piedra gris cálida `#B8ADB8` con sombras `#7D747C`, tierra `#835832`. Nada de colores fuera de eso salvo
   donde se pida.
3. **Nada de rosa salvo en `flor_reactiva` y `pocion`**: el rosa es el color de lo reactivo y se confunde si aparece en arbustos, setas o tocones (fallo de la primera tanda: manchas salmón en `arbusto`, cara cortada rosada en `tocon`).
4. **Nada de brillo, fuego, brasas ni runas encendidas pintados**: lo luminoso lo pone el motor. Las runas se piden **grabadas, monocromas, sin luz**.
5. **Sin texto ni letras** en ninguna (carteles en blanco).
6. **Sin figuras ni «satélites»**: un solo objeto, sin piezas sueltas alrededor (la `fogata` de la primera tanda salió con un muñeco de madera en el centro).
7. **Lo que arde** (árboles, arbustos, seto, valla, cartel, cajas, barril, puesto, juncos, tronco, tocón) se pide **sano, sin quemar**: el estado quemado es otro modelo.

## Prioridad
1) lo que cambia la lectura del puzle: `baldosa_guardado`, `pasadero`, `placa_peso`, `puente`, `cartel`, `portal_salida`, 2) lo reactivo: `seta_reactiva`, `flor_reactiva`, `raiz_reactiva`, `seto_seco`, `totem_runico`, `brasero`, `fogata`, `dummy`,
3) árboles y arbustos (lo que más se ve): `arbol_redondo`, `pino`, `arbusto`, `arbusto_flores`, 4) construcciones: `arco_puerta`, `puesto`, `pilar`, `valla`, 5) el resto.
`matas`, `flores` y `caja_cristal` **ya no se usan** (los pone `Hierba3D` o son cubos con textura): sus prompts están al final solo por si Pablo los quiere de todos modos.

---

## A. Bosque: árboles y arbustos (`bosque.glb`)

### `arbol_redondo` · alto 4,2 (copa ≈ 2,8 de ancho)
Colisión «tronco»: se pasa por debajo de la copa, así que **el tronco debe verse limpio y la copa empezar alta** (a partir de ≈ 1,6). Arde.
> A round-canopy forest tree, a thick short trunk with a visible bare lower part and a few small roots, a big fluffy rounded crown made of soft puffy leaf clumps in warm yellow-green with lighter tips, the crown starting high above the ground, full tree visible, no flowers, no fruit, no pink
> + [ESTILO]

### `pino` · alto 4,6 (base ≈ 2,0 de ancho)
> A chunky stylized pine tree, a visible bare trunk at the bottom, then three or four stacked rounded layers of soft needle clumps in a slightly darker warm green, narrower toward the top, simple and fluffy, no snow, no cones, no pink
> + [ESTILO]

### `arbusto` · alto 1,0
> A round fluffy bush made of soft puffy leaf clumps, fresh warm yellow-green in two tones with lighter tips, dense and compact, **no flowers, no berries, no pink, no salmon spots**
> + [ESTILO]

### `arbusto_flores` · alto 1,0
> The same kind of round fluffy leafy bush in warm yellow-green, with five to seven **small round** white or butter-yellow flowers scattered on it, each flower a tiny rounded bloom with a pale center, **no pink flowers**, no berries
> + [ESTILO]

## B. Rocas, troncos y suelo (`bosque.glb`)

### `roca_grande` · alto 1,4
> A big rounded boulder, chunky and smooth, warm gray stone with soft darker cracks and a little green moss on the top, a second small rock fused at its side, flat bottom, no crystals, no glow
> + [ESTILO]

### `piedras` · alto 0,35
> A small cluster of three rounded pebbles and stones of different sizes, warm gray with a hint of moss, low and compact, fused into one object
> + [ESTILO]

### `tocon` · alto 0,6
> A wide short tree stump, rough dark-brown bark, a flat cut top showing light **tan-brown** growth rings (no pink, no red), a little moss on one side and two small roots at the base
> + [ESTILO]

### `tronco` · alto 0,7 (tumbado a lo largo de X, ≈ 2,0 de largo)
> A thick fallen log lying horizontally, dark damp bark with a few knots, a patch of bright green moss on top, both cut ends showing tan growth rings, no branches, no vines
> + [ESTILO]

### `setas` · alto 0,35
Decorativas: **no azules** (la seta azul es la reactiva) **ni rosas**.
> A small cluster of four or five mushrooms of different sizes growing together, rounded caps in cream and warm tan with a few soft brown spots, short pale stems, no blue, no pink, no glow
> + [ESTILO]

### `juncos` · alto 0,8 (≈ 0,8 de ancho)
> A clump of tall reeds and cattails, slim curved green blades in two tones and three or four brown cattail heads, a compact bunch with a small mud base, no water
> + [ESTILO]

## C. Construcciones, caminos y salida (`bosque.glb`, `objetos.glb`, `magia.glb`)

### `valla` · alto 0,8 (un tramo de ≈ 2,0 de largo, a lo largo de X)
> A short stretch of rustic wooden fence, two thick posts with rounded tops and two horizontal rails between them, slightly crooked planks, weathered warm brown wood with a little moss at the base
> + [ESTILO]

### `cartel` · alto 0,95
Antes era **solo un poste sin tablón**.
> A wooden signpost: a sturdy post and a rectangular wooden board nailed to it facing forward, the board **completely blank**, visible wood grain, slightly rounded corners, a little moss at the foot of the post, no text, no symbols
> + [ESTILO]

### `arco_puerta` · alto 3,4 (el hueco mira a +Z: se cruza avanzando por Z)
La primera tanda salió con la abertura a ±X y hubo que girarla.
> An ancient mossy stone archway, two chunky pillars and a rounded arch on top, the opening facing the viewer (you walk through it toward the camera), weathered warm gray stone with moss and a few vines, a simple engraved rune on the keystone, monochrome carved, no glow
> + [ESTILO]

### `puesto` · alto 1,9
Colisión «mesa»: la mesa baja es sólida, el toldo va por encima. El toldo azul/blanco era de «ciudad»: aquí **ocre y crema**.
> A small woodland market stall, a sturdy wooden counter with an empty top and a sloped canvas awning in soft ochre and cream stripes held by two wooden poles, a little crate under the counter, warm brown wood, nothing on the counter
> + [ESTILO]

### `portal_salida` · alto 3,0
La salida del nivel. El remolino lo pone el motor (celeste): **el marco va vacío**.
> A standing stone portal frame, two tall curved pillars joined by a round arch, an empty open center, carved with simple monochrome runes along the arch, pale warm stone with moss at the base and a little pale blue tint on the inner edge, the frame facing the viewer, nothing inside, no swirl, no glow
> + [ESTILO]

### `pilar` · alto 1,8
> A short ancient stone pillar, square chunky shaft with a slightly wider base and capital, one corner chipped, moss at the bottom and a few vines, warm gray stone, plain surface with one small carved ring, no glow
> + [ESTILO]

### `totem_runico` · alto 1,8
Reactivo (fuego / agua / rayo): el motor lo tiñe y lo enciende; aquí **un hueco redondo vacío** donde irá la luz.
> A carved stone totem, a stack of three chunky blocks with a simple stylized face-like pattern, a round **empty recessed socket** in the middle block, a few engraved monochrome runes, warm gray stone with moss at the base, no glow, no color in the socket
> + [ESTILO]

### `puente` · ancho 2,4 (largo a lo largo de X, cubre una casilla de agua; se camina por encima)
Colisión de malla completa: la **cara de arriba debe ser lisa y llana**.
> A short stone and wood footbridge, a flat walkable deck of fitted planks with low stone side walls, two chunky stone abutments at the ends, length about 1.5 times its width, moss on the stones, perfectly flat top
> + [ESTILO]

### `pasadero` · ancho 1,84 · alto 0,10
Antes salió como una placa beige plana que parecía suelo.
> A single large flat stepping stone, roundish and slightly irregular, warm gray, top almost perfectly flat and smooth, moss growing along the edge, chunky beveled sides, looks like it sits **on top** of water
> + [ESTILO]

### `baldosa_guardado` · ancho 1,96 · alto 0,12
Antes: losa gris sin lectura. El brillo celeste lo pone el motor.
> A square stone floor slab with beveled edges, pale warm stone, a single large round rune ring **engraved** in the center with a simple star glyph inside, monochrome carved lines, a thin raised border, no glow, no color
> + [ESTILO]

### `placa_peso` · ancho 1,84 · alto 0,15
> A square stone pressure plate set in a slightly raised stone frame, the plate a little lower than the frame with a simple engraved circle in the middle, warm gray stone, chunky beveled edges, no glow, no metal
> + [ESTILO]

## D. Objetos (`objetos.glb`)

### `brasero` · alto 1,4
**Vacío y apagado**: las llamas, las brasas y la luz las pone el motor.
> A stone and iron brazier, a wide shallow bowl on a short pedestal or three sturdy legs, rim with small carved notches, warm gray stone and dark iron bands, the bowl **empty and clean**, no fire, no coals, no embers, no ash glow
> + [ESTILO]

### `fogata` · ancho 1,38 · alto 0,6
Cuatro troncos y un círculo de piedras; **nada en el centro** (la primera salió con un muñeco de madera).
> A campfire pit: a ring of rounded gray stones around four short logs leaning together in a small tepee, logs dry and unburnt, the center empty between them, no fire, no embers, no ash, no figure
> + [ESTILO]

### `caja_pequena` · alto 0,6
> A small wooden crate with rounded corners, slatted planks and corner bracing, warm brown wood, closed lid, a little wear, no text, no labels
> + [ESTILO]

### `caja` · alto 0,8
> A larger sturdy wooden crate, chunky planks with a cross brace on each side, rope handles, warm brown wood, closed, no text, no labels
> + [ESTILO]

### `barril` · alto 0,8
Barril corriente (el de pólvora del puzle es otra pieza).
> A rounded wooden barrel with three dark iron bands, lid on top, warm brown staves, a small bung hole, no text, no logos
> + [ESTILO]

### `cofre` · alto 0,6
**Cerrado**: empieza cerrado y el motor lo abre. Si puedes, pide aparte un segundo modelo `cofre_abierto` (misma caja y bisagras, tapa abierta, **vacío por dentro**).
> A small wooden treasure chest with a rounded lid, iron bands and a simple round lock, warm brown wood with dark iron, lid closed, chunky and cute, no gold showing, no gems, no glow
> + [ESTILO]

### `pocion` · alto 0,45
Es el objeto que se recoge: el único con rosa/rojo junto con `flor_reactiva`.
> A round-bottomed glass potion flask with a short neck and a cork, filled with soft pink-red liquid that fills most of the bottle, a tiny highlight, simple and readable, no label, no text, no sparkles
> + [ESTILO]

### `dummy` · alto 1,4
Reactivo (recibe hechizos). Arde.
> A wooden training dummy: a thick post planted in a small wooden base, crossed arms of wood, a round burlap-wrapped torso and a simple round burlap head with a stitched patch, tied with rope, warm brown and tan, no face, no text, no weapons
> + [ESTILO]

## E. Reactivas y mágicas (`magia.glb`)

### `seto_seco` · alto 1,3
La primera salió **plana y alargada** («un ciempiés»). Arde y reacciona al fuego.
> A compact **round** dry hedge made of tangled bare twisted branches, dry warm brown and tan, no leaves, dense and chunky like a ball, taller than wide, fully three-dimensional from every side
> + [ESTILO]

### `seta_reactiva` · alto 0,8
La **seta azul** (se cambia por `seta_quemada`, 0,57, al quemarse: misma base).
> A single big mushroom with a wide rounded **blue** cap with a few pale cream spots, a thick cream stem and a small leafy base, chunky and cute, soft blue not neon, no glow
> + [ESTILO]

### `flor_reactiva` · alto 0,9
La **flor rosa** (único rosa grande del decorado).
> A single big flower on a thick green stem with two broad leaves, a large rounded bloom with about eight soft **pink** petals around a warm yellow center, chunky and simple, no glow, no sparkles
> + [ESTILO]

### `raiz_reactiva` · alto 0,9
La **raíz** (en el mapa se marca marrón; hay otra, `raiz_mundo`, 0,7).
> A thick twisted tree root rising out of the ground in a curved arch with two smaller roots, dark warm brown bark with lighter ridges, a few small moss patches and a little soil at the base, chunky
> + [ESTILO]

---

## F. Retiradas (no se usan; solo si Pablo las quiere)

### `matas` · alto 0,45 *(retirada: la hierba la pone `Hierba3D`)*
> A low clump of soft grass, three or four rounded tufts of long green blades in two tones, compact and flat at the bottom, only green
> + [ESTILO]

### `flores` · alto ≈ 0,3 *(retirada)*
> A small patch of wildflowers with leaves: two white daisies and two butter-yellow buttercups on thin stems, low and compact, no pink
> + [ESTILO]

### `caja_cristal` *(retirada: los empujables son cubos con textura de tierra / hielo; no regenerar)*

---

## Si quieres gastar menos generaciones
Las piezas pequeñas se pueden pedir **juntas en una lámina** (ver `PROMPTS_BOSQUE_LAMINAS.md`: piezas separadas con hueco amplio, sin tocarse, misma escala relativa, vistas 3/4, sin suelo; yo las recorto):
- **Lámina «suelo del bosque»**: `tocon`, `tronco`, `piedras`, `setas`, `juncos`, `roca_grande`.
- **Lámina «objetos»**: `caja_pequena`, `caja`, `barril`, `cofre`, `pocion`, `dummy`.
- **Lámina «reactivas»**: `seta_reactiva`, `flor_reactiva`, `raiz_reactiva`, `seto_seco`.
- **Lámina «plano de suelo»**: `pasadero`, `baldosa_guardado`, `placa_peso`.
Salen a ≈ 15.000 triángulos entre todas (≈ 2.000 cada una): bien para lo pequeño, **mal para lo grande**: `arbol_redondo`, `pino`, `arco_puerta`, `portal_salida`, `puesto`, `totem_runico`, `puente` y `pilar` van **sueltas**.
