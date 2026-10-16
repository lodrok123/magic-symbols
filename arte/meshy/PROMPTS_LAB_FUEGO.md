# Prompts de los assets del laboratorio de fuego (16 de octubre de 2026)

Lo que falta de **arte** para `LabPuzlesFuego3D` (F1–F10, `docs/FASE14_PRESENTACION.md` §6; primera tanda F1–F5 hecha por el Juego, entrada 100 del diario).
Mismo método que `PROMPTS_PIEZAS_PUZLE.md`: **una pieza por generación**, *Text to 3D* (o *Image to 3D*), pega el bloque [ESTILO] **al final** de cada
prompt y refina con el *target poly count* y la textura de cada título. Al bajar: `meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` → `CatalogoAssets` tecla H.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas que NO son de estilo (las mismas de las piezas de puzle, y las que más fallan con el fuego)

1. **Nada de fuego, brasas ni brillo pintado.** Las llamas, las brasas, el humo y el calor los pone el motor (`Fuego3D`, `Vfx3D`) y la luz es una `OmniLight3D`.
   Todo lo que «arde» se pide **apagado**: la antorcha sin llama, la hoguera sin fuego, la caldera sin lumbre. Si sale con llama pintada no se puede apagar.
2. **Lo que cambia de estado va en GLB aparte** y cada parte sale **en su posición de reposo**, con el origen en el centro de su base (o donde se indica).
3. **Lo que «arde» y se quema tiene dos mallas, no una:** la pieza entera y la pieza **quemada** (mismo tamaño y mismo origen, para que el cambio no salte).
   El estado «ardiendo» es la entera con un tinte oscuro y llamas del motor.
4. **Piezas que se calientan** (caldera): hierro **gris oscuro neutro**, sin óxido naranja: el rojo del calor lo pone el motor como emisión.
5. **Medidas** (casilla = 2,3 u; la jugadora mide ~1): las de cada título; si Meshy no las respeta se escalan al integrar. **Frente hacia +Z.**
6. **Sin texto** salvo las marcas que se piden (anillo, grieta en aspa) y **sin colores de elemento** (nada rojo llama, nada azul agua): son neutros o de material.

## Prioridad
1) **Cuerda** (cuatro piezas) y **placa del contador**: F3 y F1/F2 ya están en el lab con cajas de placeholder. 2) **Leña y hoguera apagada** (F7). 3) **Caldera** (F6).
4) **Antorchas y baldosa falsa** (F8). 5) **Escudo del goblin** (F10).

## Lo que YA hay y no hay que generar
- **Brasero / antorcha de mapa** (`brasero`, 1,4 u), **fogata encendida** (`fogata`), **tótem** y **seto seco**: ya salen de las bibliotecas de Meshy; el relé
  (F2) no cambia su aspecto, el brasero se apaga solo y ya deja ceniza. **Hielo** (compuerta, tapón), **roca**, **compuerta** y **puerta**: modelos de las láminas «puzle» (ARTE §12).
- **Barril**: el modelo ya existe en `PiezaPuzle3D` (Ø0,95, calavera); falta que `Barril3D` (Juego) lo use en vez del cilindro. No es un asset.
- **Losas de runas** (`losa_runas_llana/ovalo/remaches`): sirven de baldosa **segura** de F8; solo falta su gemela falsa.

## Lo que NO es un asset (lo hago yo, en código)
Seto **mojado** (tinte oscuro y gotas mientras `esta_mojado()`), el **charco** que apaga la antorcha, el **calor** de la caldera (emisión y vapor), las **llamas** de
la hoguera y las antorchas, la **brasa que vuela** (F9), el **humo** de lo quemado, la **luz** de las antorchas. Y el icono 2D del leño para la bolsa (`objeto_leno.png`, lo saco con `iconos.py`).

---

## 1. Cuerda que sostiene una compuerta (F3) — `Cuerda3D`: hijos «poste», «cuerda», «cabo»

Hoy son tres cajas. Estados: ENTERA · ARDIENDO (entera + tinte + llamas) · ROTA (la cuerda cae y la compuerta se cierra).

### `cuerda_poste` (400–900 tris, 512)
> A short sturdy wooden gallows post for holding up a gate: a thick rough wooden post with a small cross-arm
> on top and a cast-iron ring hanging from the end of the arm, a few stones piled at the foot, a leather
> strap holding the arm. **Nothing hanging from the ring.** Height 1.9 units, arm 0.45 units long toward +X with the ring
> hanging 0.28 units from the post, post diameter 0.25 units. Chunky and rustic.

### `cuerda_tensa` (400–900 tris, 512)
> A thick hanging hemp rope, vertical and perfectly taut: three twisted strands of pale tan fibers, a knotted
> loop at the top and a heavy iron hook at the bottom, a few loose fibers sticking out. **Straight, no slack, hanging
> straight down.** Length 1.3 units, thickness 0.14 units (diameter). **Origin at the top knot**, the rope hangs toward -Y.

### `cuerda_cabo` (150–400 tris, 256)
> The short burnt stub of a cut rope: a small knotted loop at the top and 0.25 units of pale tan rope below
> it ending in a **frayed, charred black tip**, hanging straight down. Total length 0.35 units, thickness 0.14 units. **Origin at the top knot**, the stub hangs toward -Y.

### `cuerda_caida` (400–900 tris, 512)
> A rope lying on the floor after snapping: the long rope in a loose coil and a short tail, an iron hook at one
> end, **the other end frayed and charred black**, flat on the ground. About 1.1 units across, 0.12 units
> high. No smoke, no fire.

## 2. Placa del contador (F1, F2) — `ContadorReactivos3D` (hoy un rótulo «ENCENDIDAS n/m»)

### `contador_placa` (500–1 000 tris, 512–1024)
> A wide stone lintel plaque that counts lit torches: a rectangular light grey stone slab with a chunky carved frame,
> **four equal round empty recesses in a row, like empty sockets for gems**, evenly spaced, each recess with a thin
> carved ring around it, moss at the base, two stubby legs. **The recesses are empty and plain dark stone, no
> gems, no glow.** 1.6 units wide, 0.45 tall, 0.2 deep. Ruined-temple style.

*(el motor pone una luz en cada hueco al encenderse el brasero que le toca)*

## 3. Leña y hoguera (F7) — `Fogata` con `combustible`; «leño» se recoge (12.1)

### `leno` (300–600 tris, 512)
> One piece of cut firewood: a short split log with rough bark on the sides, pale freshly cut ends with
> visible tree rings, a couple of small knots, one flat chopped face. Length 0.5 units, diameter 0.14 units.
> Plain natural wood, no burn marks.

### `fogata_apagada` (800–1 500 tris, 1024)
> A burnt-out campfire pit: a ring of rough grey stones, a flat heap of pale grey ash in the middle and two or
> three black charred logs half buried in it, soot stains on the stones. **No fire, no glowing embers, no
> smoke.** 1.4 units wide, 0.35 high. Same footprint as the lit campfire.

### `fogata_lenos` (500–900 tris, 512)
> Three fresh logs leaning against each other in a teepee shape, tied with a loop of twine at the top, tan
> wood with pale cut ends. **No fire.** 0.9 units tall, 0.7 units across at the base. (Sits inside the stone
> ring of `fogata_apagada`; the engine lights it.)

## 4. La caldera (F6) — `Caldera3D`: calor fría / caliente / al rojo

### `caldera_cuerpo` (1 500–3 000 tris, 1024)
> A big chunky black-iron cauldron: round pot-bellied body, thick rim, two heavy side handles, rows of round
> rivets, three short stubby legs, **open top with an empty dark inside**, dark grey iron with soft painted
> highlights, **no rust, no orange, no glow, no liquid**. 1.2 units across, 0.9 high including legs.

### `caldera_hogar` (800–1 600 tris, 1024)
> A stone hearth for a cauldron: a low round platform of rough light grey stones with a shallow bed of dark ash
> in the middle and a few black charred logs, flat top so a cauldron can stand on it, soot-stained. **No
> flames, no glowing embers.** 1.8 units across, 0.25 high.

### `caldera_medidor` (400–800 tris, 512)
> A heat gauge post: a slim light grey stone pillar with a tall narrow vertical slot filled with an empty glass tube,
> **five evenly spaced carved tick marks** down one side, a small brass cap on top, moss at the foot. **The tube is
> empty and clear.** 1.4 units tall, 0.3 wide, 0.25 deep.

### `caldera_indice` (100–250 tris, 256)
> A small brass ring marker that slides along a gauge: a flat round brass ring with a tiny pointer, plain
> warm yellow metal. Diameter 0.14 units, 0.05 thick. (It moves up and down the gauge; the engine places it.)

## 5. Antorchas y baldosa falsa (F8: luz en la cueva) — la llama y la luz las pone el motor

### `antorcha_pared` (500–1 000 tris, 512)
> A wall-mounted torch in an iron bracket: a dark iron ring bracket fixed to a small stone plate, a wooden
> torch handle sticking out at a slight upward angle, the head wrapped in dark pitch-soaked cloth. **Unlit:
> no flame, no smoke, no glow.** Origin at the stone plate (the wall side), pointing toward +Z. Length 0.9
> units, bracket 0.3 units wide.

### `antorcha_pie` (600–1 200 tris, 512–1024)
> A freestanding torch on a stone base: a short cone of grey stone, a straight wooden pole and an iron cup on top
> holding a bundle of dark pitch-soaked rags. **Unlit: no flame, no smoke, no glow.** Height 1.6 units, base
> diameter 0.45 units.

### `baldosa_falsa` (500–1 000 tris, 1024)
> A square cave floor tile that looks like the safe ones (`losa_runas_llana`) but is a trap: the same thick
> light grey stone slab with beveled edges, **a deep jagged crack running across it and a big carved X made of
> two cracks in the middle**, monochrome, engraved only, no color, no glow. 2.0 units wide, 0.2 thick.
> (Same size and same stone as the safe tile so the two can swap.)

## 6. Escudo del goblin (F10) — escudo de madera que arde: entero / ardiendo / quemado

### `goblin_escudo_entero` (600–1 200 tris, 512)
> A crude goblin round shield: rough wooden planks nailed together, an uneven rusty iron rim, a spiky iron boss in
> the center, a faded red-brown paint stripe across it, a leather grip on the back, a few dents. Chunky, a bit
> lopsided. **Plain wood, no glow.** Diameter 0.55 units, 0.1 thick, front toward +Z. Origin at the center of the grip.

### `goblin_escudo_quemado` (500–1 000 tris, 512)
> The same crude goblin shield after burning: the planks charred black and cracked, **a big chunk of wood burnt away
> on one side showing the boss and the iron rim**, the paint gone, the leather grip scorched. **No fire, no
> embers, no smoke.** Same size and same origin as the intact shield: diameter 0.55 units, 0.1 thick. (The goblin
> is left exposed 6 s; «ardiendo» is the intact shield tinted dark with flames from the engine.)

---

## Cómo entran
**Ya hay modelos de las 17 piezas** (láminas «Medieval Camp Props» y «Rustic Camp Toolkit», 16/10, separadas: ARTE §14): `arte/meshy/fuego/fuego_medieval.glb` y
`fuego_rustic.glb`, un nodo por pieza con el nombre del título, ya orientadas, a escala y con el origen puesto. Estos prompts quedan para **repetir o mejorar** una pieza:
un GLB suelto `arte/meshy/fuego/<id>.glb` con el nombre del título (`caldera_cuerpo.glb`…) pasa por delante de la lámina y `PiezaFuego3D`
(`presentacion/pieza_fuego_3d.gd`) lo escala a la medida del prompt y pone el origen en el centro de la base (en `cuerda_tensa`/`cuerda_cabo`, en el nudo de arriba; en `goblin_escudo_*`, en el centro del disco).
Sin ninguno de los dos, dibuja primitivas.

## Resumen (17 generaciones)
| Tanda | Piezas | Para |
|---|---|---|
| 1 | `cuerda_poste`, `cuerda_tensa`, `cuerda_cabo`, `cuerda_caida`, `contador_placa` | F3 · F1/F2 |
| 2 | `leno`, `fogata_apagada`, `fogata_lenos` | F7 |
| 3 | `caldera_cuerpo`, `caldera_hogar`, `caldera_medidor`, `caldera_indice` | F6 |
| 4 | `antorcha_pared`, `antorcha_pie`, `baldosa_falsa` | F8 |
| 5 | `goblin_escudo_entero`, `goblin_escudo_quemado` | F10 |
