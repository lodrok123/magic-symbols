# Prompts de las piezas de puzle (16 de octubre de 2026)

Para sustituir las primitivas de `PiezaPuzle3D` (docs/ARTE.md §9) por modelos de Meshy **sin cambiar ids de estado ni nodos**.
Método de siempre: **una pieza por generación**, *Text to 3D* (o *Image to 3D* con su `referencias/<id>.png` si la hay), pega el bloque
[ESTILO] **al final** de cada prompt y refina con el *target poly count* de cada título y textura propia. Al bajar:
`meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` → `CatalogoAssets` tecla H.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas que NO son de estilo (importan para que los estados funcionen)

1. **Las partes que se mueven o se encienden van en GLB aparte** (el botón no puede ir pegado a su base, ni la hoja de la compuerta a su marco):
   por eso hay pares `*_marco` / `*_hoja`. Cada parte sale **ya en su posición de reposo** y con su origen en el centro de su base.
2. **Medidas** (casilla = 2,3 u; la jugadora mide ~1): las de cada título. Pídelas en el prompt y, si Meshy no las respeta, se escalan al integrar.
3. **Piezas que se TIÑEN** (botón, losa de la runa): color **neutro claro** (gris casi blanco). El tinte rojo/azul/ocre lo pone el motor; si sale ya coloreada no se puede cambiar.
4. **Nada de brillo pintado** (runas encendidas, brasas, cristal luminoso): el brillo lo pone el motor. Pide las runas **grabadas, monocromas, sin luz**.
5. **Hielo y agua**: se pide la forma; el material translúcido lo pone el motor (el mismo de `costra_hielo`).
6. **Sin texto ni símbolos** salvo las runas que se piden. Orientación: **frente hacia +Z**; en la rueda del molino, el eje de giro es el **eje X**.

## Prioridad
1) compuerta (marco + hoja de madera y de hierro) y roca + cascotes, 2) barril, pulsador y placa, 3) pila y molino, 4) reja, poste de nivel,
5) hielo (compuerta, tapón) y tinaja vacía.

---

## 1. Pulsador de piedra

### `pulsador_base` (800–1 500 tris, 1024)
> A short round stone pedestal for a pressure button: a squat cylinder of light grey stone with a slightly wider
> chamfered foot, a shallow round socket on top with a thin carved ring around it, a few small chips and moss
> on the foot. Diameter 0.9 units, height 0.5 units. Chunky and friendly.

### `pulsador_boton` (300–700 tris, 512)
> A round stone button cap, a thick rounded disc with a softly domed top, **almost white light grey, plain
> neutral color, no markings**, small chamfer at the edge, looks like it can be pressed down. Diameter 0.66
> units, height 0.38 units.

## 2. Placa de presión con runa

### `placa_marco` (600–1 200 tris, 1024)
> A square flat stone slab frame: a thin dark grey stone border with a recessed square pocket in the middle
> (the pocket is empty), beveled edges, worn corners, a few small cracks and moss on the outer edge. Seen from
> above and 3/4, very flat. 1.8 units wide, 0.1 units high, pocket 1.55 units wide.

### `placa_tapa` (500–1 000 tris, 1024)
> A square flat stone pressure plate that fits inside a frame: light grey stone, beveled edge, four small
> round copper rivets in the corners, and **one large rune carved into the center (a vertical line with two
> arms forming a Y), monochrome, engraved only, no color, no glow**. Very flat. 1.55 units wide, 0.06 units thick.

## 3. Compuerta (madera y hierro)

### `compuerta_marco` (1 200–2 500 tris, 1024)
> A stone gate frame for an irrigation channel: two thick rectangular light grey stone posts with a deep
> vertical groove on their inner sides, a heavy stone lintel on top with a small iron pulley ring, mossy
> at the base, **open in the middle with nothing inside**, flat bottom threshold. 2.2 units wide, 1.5 tall,
> 0.42 deep. Ruined-temple style, chunky.

### `compuerta_hoja_madera` (600–1 500 tris, 1024)
> A wooden sluice gate panel: four vertical planks in two alternating brown tones, two horizontal dark iron
> straps with round rivets, visible wood grain, flat and rectangular so it slides in a groove. 1.7 units wide,
> 1.3 tall, 0.14 thick.

### `compuerta_hoja_hierro` (600–1 500 tris, 512–1024)
> An iron portcullis panel: seven vertical dark grey iron bars and two horizontal iron crossbars, slightly
> rusty, rounded bar ends, flat so it slides in a groove. 1.7 units wide, 1.3 tall, 0.1 thick.

## 4. Compuerta de hielo

### `compuerta_hoja_hielo` (800–1 800 tris, 512)
> A thick slab of ice for a gate: a rectangular block of pale blue ice with faceted rough edges, a few
> small ice crystals sticking out of the top and the sides, **plain pale blue, no inner glow**. 1.75 units
> wide, 1.3 tall, 0.3 thick. (Uses the same `compuerta_marco`.)

## 5. Roca de derrumbe

### `roca_entera` (1 500–3 000 tris, 1024–2048)
> A large rounded boulder that blocks a stream: a cluster of four joined grey boulders (one big, three
> smaller leaning on it), chunky faceted shapes, a patch of green moss on top, a few cracks, darker wet
> stone at the bottom. 2.2 units wide, 1.3 tall. No grass around it.

### `roca_cascotes` (4 piezas, 400–800 tris cada una, 1024)
> Four separate pieces of broken grey rock, each a different chunky faceted rubble stone (sizes between 0.4
> and 0.8 units), same grey stone and moss as a large boulder, **placed apart from each other with space
> between them**, no ground. (Se parte con `separar_lamina.py` en `cascote_0..3`.)

## 6. Barril de pólvora

### `barril_polvora` (800–1 800 tris, 1024)
> A chubby wooden powder keg: bulging round barrel of warm brown planks, three dark iron hoops, a flat
> wooden lid with **a small round hole in the center for a fuse**, a small painted dark skull with two eyes
> on the belly, slightly worn. Diameter 0.9 units, height 0.95 units.

## 7. Rueda de molino

### `molino_rueda` (1 200–2 500 tris, 1024)
> A wooden water wheel seen from the side: two thin octagonal rims joined by eight flat paddles, four spokes
> and a thick round hub with a hole through the center, warm brown wood in two tones, a few dark iron bands.
> **Rotation axis along the X axis (left to right)**, diameter 1.5 units, width 0.6 units.

### `molino_soportes` (800–1 600 tris, 1024)
> Two short light grey stone posts each with a round iron bearing notch on the inner side, joined by a thick
> dark wooden axle between them, mossy base. Posts 0.95 units apart, 1.05 tall, axle along the X axis.

## 8. Pila de piedra con bornes

### `pila_piedra` (800–1 600 tris, 1024)
> A round stone basin: a squat grey stone bowl with a thick rim, a shallow **empty** dark hollow inside (no
> water), chipped edges, a little moss, two small flat mounts on opposite sides for metal terminals. Diameter
> 1.1 units, height 0.4 units.

### `pila_borne` (200–500 tris, 512)
> A copper electrical terminal: a flat rectangular copper post with a small round knob on top and a ring
> collar at the base, warm orange copper with a slightly verdigris edge. 0.22 units wide, 0.5 tall. (Se
> duplica x2.)

## 9. Poste de nivel

### `poste_vara` (400–900 tris, 512)
> A thin wooden marker pole: a straight light brown post slightly thicker at the base with a small round
> stone foot, wood grain, **one tiny notch ring carved around it at mid height**, no text. 1.7 units tall,
> 0.1 units wide.

### `poste_farolillo` (500–1 000 tris, 512)
> A small hanging lantern: a little iron cage with four thin bars around a clear round glass bulb, a pointed
> iron cap on top and a small ring, **bulb unlit, plain pale glass**. 0.3 units wide, 0.4 tall.

## 10. Reja o puerta de premio

### `reja_hoja` (800–1 800 tris, 512–1024)
> A tall iron gate panel: eight vertical iron bars with **pointed spear tips**, three horizontal crossbars,
> a round copper lock plate in the middle, dark grey iron, slightly worn. 1.75 units wide, 2.1 tall, 0.1
> thick, flat so it slides in a groove.

### `reja_marco` (1 800–3 500 tris, 1024–2048)
> A grand ruined-temple gate frame: two tall thick light grey stone pillars with carved capitals, a heavy
> stone lintel with a **carved crest in the center** (a simple shield shape with a small round copper medallion),
> moss at the base, **open in the middle with nothing inside**. 2.2 units wide, 2.4 tall, 0.42 deep.

## 11. Tinaja vacía

### `tinaja_ruina_vacia` (el mismo presupuesto que `tinaja_ruina`; Image to 3D con la captura de `tinaja_ruina`)
> The same ancient mossy clay-and-stone jar as the reference, but **dry and empty**: no water, no wet
> darkness, no dripping, the stone looks pale, dusty and slightly cracked, the moss is yellow-brown and dried,
> the spout is dry. Same shape, same size, same pose as the reference.

## 12. Tapón de hielo del desagüe

### `tapon_hielo` (400–900 tris, 512)
> A plug of ice sealing a drain: a short hexagonal block of pale blue ice with faceted rough edges, a few small
> crystals sticking out of the top, **plain pale blue, no inner glow**. Diameter 0.9 units, height 0.4 units.

---

## Total: 21 generaciones

`compuerta_marco` lo comparten las tres hojas (madera, hierro, hielo); `pila_borne` se genera una vez y se duplica; `roca_cascotes` sale en una sola generación y se separa en 4 nodos.
