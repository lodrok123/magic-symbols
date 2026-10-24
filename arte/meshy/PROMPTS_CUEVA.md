# Prompts de la Cueva (23 de octubre de 2026)

Arte para la mazmorra pequeña de `docs/PLAN_BOSQUE_EOW.md` §6 (la Cueva, enfoque cerrado) y para lo que comparte con el Bosque
(rompibles, boca de la cueva). Antes de pedir nada: **qué se reutiliza tal cual, qué se adapta sin Meshy y qué hay que generar.**

Método de siempre: **una pieza por generación**, *Text to 3D* (o *Image to 3D* con su referencia), pega el bloque [ESTILO] **al final** de
cada prompt y refina con el *target poly count* de cada título. Al bajar: `meshy\entrada\<id>.glb` → `INTEGRAR_PIEZAS.cmd` →
`CatalogoAssets` tecla H.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows,
single object, centered, no base, no ground plane, no background, no outline, no black lines.
```

## Reglas que importan para que funcione en el juego

1. **Presupuesto** (`arte/meshy/PRESUPUESTO.md`: los árboles de 12 000 triángulos eran el 61 % de la escena): las piezas de la cueva se
   repiten mucho, así que **pide el poly count de cada título** y no aceptes las de 12 k que Meshy da de serie. EoW: piezas de 60–1 600.
2. **Medidas** (casilla = 2,3 u; la jugadora mide ~1; un nivel de altura = 1,04 u): las de cada título. Si Meshy no las respeta, se escalan
   al integrar.
3. **Modular y en rejilla**: las paredes ocupan **una casilla exacta** de planta (2,3 × 2,3), con el origen en el centro de la base y el
   **frente hacia +Z**. Así el plano de letras las coloca solas.
4. **Nada de brillo pintado** (lava, cristales encendidos, grietas incandescentes): el brillo lo pone el motor (`Lava3D`, `MuroAgrietado3D`,
   las luces de los braseros). Pide las formas y los colores apagados.
5. **Lo que se rompe va entero**: el muro agrietado y los jarrones se piden ENTEROS. Las grietas y el «deshacerse por celdas» los hace el
   shader; los cascotes, `VfxPuzle3D.polvo` y los `cascote_0..3` que ya hay.
6. **Sin texto ni símbolos**, salvo las runas que se piden, grabadas y monocromas.

---

## A. Lo que ya hay y se usa TAL CUAL

| pieza | dónde está | en la Cueva |
|---|---|---|
| brasero, antorcha de pared | `arte/piezas/brasero.tscn`, `PiezaFuego3D` | C1 (luz), pasillos |
| cofre animado | `arte/piezas/cofre.tscn` (`Cofre3D`) | cofre de la llave (C4) |
| reja de premio, compuerta, roca de derrumbe, pulsador, placa | `arte/meshy/puzle/puzle_dungeon.glb` y compañía (`PiezaPuzle3D`) | puerta con llave (C6), atajo, pulsador |
| barril, caja, caja pequeña | `arte/piezas/` | barril junto al muro (opcional), cajas rompibles |
| cascotes, terrones, pinchos de tierra, cristales de hielo | `arte/meshy/piezas/` (VFX de elementos) | restos del muro, decorado de C5 |
| roca grande, roca musgosa, rocas pequeñas, piedras, roca hueca | `arte/piezas/`, `arte/meshy/piezas/` | relleno de las salas |
| cristal elemental, cristal del santuario | `arte/piezas/` | fuente eléctrica (C5) |
| goblin guerrero y escudo | `arte/modelos/`, `arte/equipo/` | C4 |
| texturas de suelo `stone_arriba`, `losas_piedra`, `dirt_arriba` | `arte/suelo_meshy/` | suelo provisional de la cueva |

## B. Lo que se ADAPTA sin generar (código o importación)

| qué | cómo | dónde |
|---|---|---|
| **roca como pared** | `roca_grande` y `roca_musgosa` escaladas a una casilla de planta y 2–3 niveles de alto, con giro al azar: paredes provisionales hasta tener el kit (§C1) | lista de piezas de borde de la maqueta |
| **suelo de cueva** | `stone_arriba` más oscura y desaturada con los albedos del suelo (`Albedos3D`), sin hierba (`_solo_zona_v`) | preset de suelo del nivel |
| **cofre grande** | `cofre` a escala 1,4 con otro tinte: el cofre del tesoro de C6 | `Cofre3D`, escala por pieza |
| **llave pequeña** (objeto e icono) | primitiva (anilla y paletón) dorada mientras no haya modelo; icono en `Objetos.DATOS` | `nucleo/objetos.gd` |
| **borde de la lava** | `roca_rio_*` y `cascote_*` oscurecidos en el borde del charco | decorado alrededor de `Lava3D` |
| **cristales que alumbran** | `racimo_hielo_*` con emisión del motor (no pintada) y una `OmniLight3D` pequeña con `LuzTitila3D` a poca fuerza | decorado de C2 y C5 |

## C. Lo que hay que GENERAR

### C1. Kit de paredes de cueva (prioridad 1)

#### `cueva_pared` (600–1 200 tris, 1024)
> A modular cave wall block for a grid-based game: a chunky slab of dark blue-grey rock that fills exactly one square tile, flat back and
> flat sides so it tiles with copies of itself, the front face (+Z) bulging with rounded boulders and soft cracks, a little moss and damp
> streaks near the bottom, slightly lighter top edge. 2.3 units wide, 2.3 deep, 2.6 tall.

#### `cueva_esquina_int` (700–1 400 tris, 1024)
> The inside corner of the same modular cave wall: two rock faces meeting at 90 degrees, facing +Z and +X, rounded boulders, moss at the
> foot, flat outer sides so it joins straight wall blocks. One square tile, 2.3 by 2.3, 2.6 tall.

#### `cueva_esquina_ext` (600–1 200 tris, 1024)
> The outside corner of the same modular cave wall: a rounded rock pillar corner where two walls turn away, smooth chunky boulders, moss
> at the foot. One square tile, 2.3 by 2.3, 2.6 tall.

#### `cueva_pared_baja` (400–800 tris, 1024)
> A low cave rock ledge for the edge of a pit or a room border: a long chunky row of rounded blue-grey stones, mossy, flat underside.
> One tile long (2.3), 2.3 deep, 0.8 tall.

### C2. El muro agrietado (prioridad 1)

#### `muro_agrietado` (800–1 600 tris, 1024)
> A thick block of fitted stone bricks that plugs a cave passage: light warm grey cut stones in uneven rows, slightly bulging, a few
> fine hairline cracks only (the big cracks are added later), dusty base with a couple of fallen pebbles. **Plain matte stone, no glow.**
> One square tile, 2.2 wide, 2.2 deep, 1.6 tall.

### C3. Boca de la cueva (prioridad 2; también para el Bosque)

#### `boca_cueva` (1 500–3 000 tris, 1024–2048)
> A cave entrance set into a grassy hillside: a wide dark arched opening framed by big rounded mossy boulders, roots hanging over the top,
> ferns at the sides, the inside fading to a dark blue-grey void. Seen from above and 3/4. 4.6 units wide (two tiles), 2.3 deep, 3.2 tall.

### C4. Rompibles (prioridad 2; también para el Bosque)

#### `jarron` (300–700 tris, 512)
> A small round clay pot with a short neck and a rolled rim, warm terracotta with a simple painted band, a little chipped, sturdy and
> chunky. 0.6 units wide, 0.7 tall.

#### `jarron_alto` (400–800 tris, 512)
> A tall clay amphora-like jar with two small handles, terracotta with a faded painted zig-zag band, chipped rim. 0.6 wide, 1.0 tall.

### C5. Puerta con cerradura y llave (prioridad 2)

#### `puerta_llave` (1 200–2 500 tris, 1024)
> A heavy stone door set in a carved cave frame: a single thick slab with iron bands and a large round iron keyhole plate in the middle,
> **the door slab is a separate part from the frame**, the frame is chunky carved stone with moss. Frame 2.3 wide, 2.4 tall, 0.5 deep.

(Pedir el **marco** y la **hoja** por separado, como `compuerta_marco` / `compuerta_hoja_*`: la hoja es la que baja al abrir.)

#### `llave_pequena` (200–500 tris, 512)
> A small chunky fantasy key: a round bow with a hole, a short thick shaft and a simple two-tooth bit, warm brass color, slightly worn.
> 0.35 units long.

### C6. Decorado de cueva (prioridad 3)

#### `estalagmitas` (400–900 tris, 1024)
> A cluster of three rounded stalagmites of different heights rising from a shared base, blue-grey wet rock with lighter tips, soft
> drips. 1.2 units wide, 1.4 tall.

#### `setas_cueva` (300–700 tris, 512)
> A small cluster of cave mushrooms with tall thin stems and wide flat caps, pale cyan caps with tiny dots, **no glow painted** (the
> glow is added in the game). 0.7 wide, 0.6 tall.

#### `charco_cueva_borde` (300–600 tris, 512)
> A ring of small flat wet stones and pebbles that outlines the edge of a shallow puddle, dark grey with a damp sheen, empty in the
> middle. One tile, 2.3 by 2.3, 0.1 tall.

### C7. Texturas de suelo (prioridad 2; método de `arte/suelo_meshy/PROMPTS_SUELO.md`)

#### `roca_cueva_arriba.png` (1024, tileable)
> Seamless tileable top-down texture of a cave floor: uneven dark blue-grey rock with soft rounded bumps, fine gravel in the cracks,
> a few damp darker patches, hand-painted, low contrast, no strong shadows, no objects.

#### `basalto_arriba.png` (1024, tileable)
> Seamless tileable top-down texture of cooled basalt near lava: dark charcoal rock plates with thin cracks, a little ash, hand-painted,
> low contrast, no glow, no objects.

---

## Prioridad y total

1. **Paredes (C1, 4) y muro agrietado (C2, 1)**: sin ellas la cueva son rocas sueltas. Mientras tanto vale §B (rocas escaladas).
2. **Boca (C3), rompibles (C4, 2), puerta con llave (C5, 2 + llave) y texturas (C7, 2)**: los comparten la Cueva y el Bosque.
3. **Decorado (C6, 3)**.

**Total: 15 generaciones más la llave** (paredes 4, muro 1, boca 1, jarrones 2, puerta 2, decorado 3, texturas 2). Ninguna bloquea la Fase 1 del plan: la Cueva se puede montar ya con §A y §B y cambiar las
piezas cuando lleguen, porque el plano de letras no cambia.

---

# Segunda tanda: lo que falta para cerrar el nivel (23/10, tras montar la Cueva)

**Ya llegó y está instalado** (Tripo, 4 hojas): las paredes de cueva (C1), el muro agrietado (C2), la boca (C3), los jarrones (C4), la puerta
con llave y la llave (C5), las estalagmitas y tres setas (C6) y las dos texturas de suelo (C7). Sobra `charco_cueva_borde` (la charca usa el
agua de la simulación).

**Lo que falta** sale de `docs/PLAN_PULSO_RESONANTE.md` (las piezas del pulso, el cofre legendario), de `docs/MATERIALES_CUEVA.md` (lo
que se recoge del suelo) y de lo que sigue siendo provisional en las fotos (`docs/capturas/cueva`, `docs/capturas/cueva_agua`): la placa
amarilla «PÍSAME», el cofre pequeño de C6 y la franja marrón de la pared de la charca.

Se piden **en hojas de 4–6 piezas** como la primera tanda (una imagen con las piezas separadas sobre fondo liso → un GLB → `recibir_assets.py
ver` / `lote --escalera` / `instalar`). Cada pieza lleva su id, que es el nombre con que el mapa la pide. Las mismas reglas de arriba:
nada de brillo pintado (lo pone el motor), piezas enteras, sin texto, y el bloque [ESTILO] al final.

## D1. Hoja «pulso» — las piezas de la mecánica (prioridad 1)

Todas comparten material: **roca azul grisácea de la cueva con incrustaciones de cristal aguamarina APAGADO** (el brillo del pulso lo
enciende el motor por emisión, así que el cristal debe ser claro y liso, sin reflejos pintados). Runas, solo grabadas y monocromas.

#### `cristal_resonante` (600–1 200 tris) — emisor y repetidor
> A resonant crystal on a rock base: one tall faceted aquamarine crystal with two smaller ones at its side, growing out of a low round
> blue-grey rock, the crystal pale and matte with clean flat facets, a thin carved stone ring around its foot. 0.9 units wide, 1.6 tall.

#### `prisma_orientable` (500–1 000 tris) — gira el pulso 90°
> A rotating stone prism on a round pivot base: a triangular block of carved stone holding a clear aquamarine triangular crystal through
> its middle, one face clearly marked as the front with a carved arrow groove, the base a low stone disc with a notch. 1.0 wide, 1.2 tall.

#### `receptor_runico` (500–1 000 tris) — recibe el pulso
> A rune receptor pillar: a short thick stone pedestal with a round concave crystal socket on top facing up, a single simple carved rune
> on its front, moss at the foot, the socket crystal pale and matte. 0.8 wide, 1.1 tall.

#### `bloque_enlace` (300–600 tris) — se empuja para cerrar una veta
> A pushable cube of dark stone with thin pale crystal veins running across all its faces from edge to edge, chunky bevelled edges,
> slightly worn corners. 1.0 by 1.0 by 1.0.

#### `estatua_piedra` (1 000–2 000 tris) — el secreto de las estatuas (se repite tres veces)
> A small guardian statue of a seated owl-like spirit carved in weathered blue-grey stone, wings folded, a round empty crystal socket
> on its chest, moss on the head and the base, cute rounded proportions. 1.0 wide, 1.8 tall.

#### `columna_agrietada` (500–1 000 tris) — reactivo que cae con el pulso
> A thick cave column of stacked rough stone drums, slightly leaning, a few hairline cracks only (the big cracks are added in game),
> thin pale crystal veins in the stone, mossy base. Plain matte stone, no glow. 1.0 wide, 2.6 tall.

## D2. Hoja «recompensas» — cofres y placa (prioridad 1)

Los cofres se piden con **la tapa como pieza aparte** (el cofre animado la abre; ver `arte/piezas/cofre.tscn`).

#### `cofre_legendario` + `cofre_legendario_tapa` (1 500–3 000 tris) — el final de la mazmorra
> A large ancient treasure chest of dark carved stone with gold trim and thick golden veins running across its sides like a circuit,
> a big round rune medallion on the front, heavy clawed feet; **the domed lid is a separate piece**. Gold is matte metal, no glow.
> 1.6 wide, 1.1 deep, 1.2 tall with the lid.

#### `cofre_epico` + `cofre_epico_tapa` (800–1 600 tris) — los secretos
> A medium treasure chest of grey stone blocks bound with dark iron, thin violet crystal inlays along the edges, a simple rune lock;
> **the flat lid is a separate piece**. Matte, no glow. 1.1 wide, 0.8 deep, 0.9 tall with the lid.

#### `placa_presion_cueva` (200–500 tris) — sustituye a la placa amarilla
> A square stone pressure plate set slightly above the floor: one worn flat slab with a carved concentric ring and a small rune in the
> middle, a thin gap all around it, moss in the gap. 1.8 by 1.8, 0.2 tall.

## D3. Hoja «recolectables» — lo que se recoge del suelo (prioridad 2)

#### `alga_cueva` (300–600 tris)
> A clump of long ribbon-like cave algae lying flat, deep teal and green strands with paler tips, wet and soft, spreading from one
> point. 0.8 wide, 0.2 tall.

#### `basalto_suelto` (200–400 tris)
> A loose chunk of cooled basalt: a dark charcoal rock with flat hexagonal-ish faces and thin cracks, a little ash on top, no glow.
> 0.5 wide, 0.35 tall.

#### `mineral_veta` (200–400 tris)
> A small rough rock chunk with a thick pale aquamarine crystal vein running through it, matte, broken edges. 0.4 wide, 0.3 tall.

#### `esquirla_cristal` (150–300 tris)
> A small cluster of three sharp aquamarine crystal shards lying on the ground, clean flat facets, matte, no glow. 0.4 wide, 0.3 tall.

#### `jarron_roto` (300–600 tris)
> The broken remains of a round terracotta pot: the bottom half still standing with jagged edges and four curved shards scattered
> around it, same painted band as the whole pot. 0.9 wide, 0.35 tall.

## D4. Texturas (prioridad 2; método de `arte/suelo_meshy/PROMPTS_SUELO.md`)

#### `veta_mineral.png` (1024, tileable, con su máscara)
> Seamless tileable top-down texture of thin branching mineral veins on dark blue-grey rock: pale aquamarine veins with soft edges,
> hand-painted, low contrast rock, no glow, no objects.

Y aparte, la **máscara** de las mismas vetas en blanco sobre negro (`veta_mineral_mascara.png`): el pulso recorre la máscara encendiendo
las vetas casilla a casilla, así que tienen que coincidir.

#### `pared_foso_cueva.png` (1024, tileable en horizontal)
> Seamless horizontally tileable side texture of a wet cave pit wall: stacked rounded blue-grey stones with dark gaps, damp darker band
> near the bottom, a little moss on top, hand-painted, low contrast, no objects.

Sustituye a la franja marrón (tierra del Bosque) que se ve en la pared de la charca y en el borde del mapa.

## Estado (23/10, tras recibir D1, D2 parcial y D4)

Instalado: **D1 completa** (`cristal_resonante` 1 200 tris, `prisma_orientable` 1 000, `receptor_runico` 1 000, `bloque_enlace` 600, `estatua_piedra` 2 000,
`columna_agrietada` 1 000), **D2** (`cofre_legendario` 1 800 + tapa 900, `cofre_epico` 900 + tapa 500, `placa_presion_cueva` 400) y **D4** (`veta_mineral`,
`veta_mineral_mascara` y `pared_foso_cueva` en `arte/suelo_meshy/`). Los cofres llevan `cofre_cuerpo` y `cofre_tapa` con la bisagra en el origen de la tapa
(`arte/meshy/montar_cofre.py`). Enganchado en la Cueva: la pared del foso y el borde del mapa (`pared_foso_cueva`), el `tesoro` (`modelo=legendario`) y la placa
«PÍSAME» (`modelo=cueva`). **Hecho (23/10, fase 1 del pulso)**: el cristal salió turquesa saturado (se pidió aguamarina apagado) y se baja por material en `BrilloPulso3D`
(`SAT_REPOSO`, `OSCURECER_REPOSO`: el cian del atlas se apaga en reposo y solo ahí suma la emisión del pulso), sin regenerar. D3 sigue sin llegar.

## Total de la segunda tanda

| hoja | piezas | prioridad |
|---|---|---|
| D1 pulso | 6 | 1 |
| D2 recompensas | 3 (+2 tapas) | 1 |
| D3 recolectables | 5 | 2 |
| D4 texturas | 2 (+1 máscara) | 2 |

**16 piezas en 4 hojas.** Mientras no lleguen, el plan del pulso se monta con primitivas (fase 1 de `PLAN_PULSO_RESONANTE.md` §12), así que
ninguna bloquea el código.

## E. Pilar de la cascada de C2 (24/10, Pablo: «prompt de Meshy para un pilar de roca de cueva con musgo para la cascada»)

Sustituye a las cajas de piedra que hoy separan las cortinas (`Puzle3D._levantar_terraza`, `pilares=si`; ver
`docs/capturas/cueva_cascada/c2_cascada_terraza_v2.png`). Referencia: los pilares de roca con musgo entre cortinas del vídeo de EoW
(`hoja.png` del 24/10). Se repite **tres veces** (dos flancos y el centro), así que va girado o escalado un poco en cada sitio.

**Qué espera el motor:**
- **Planta estrecha y alta:** ocupa un tercio de casilla de ancho (**≈ 0,8 u**), **≈ 3,1 u de alto** (1,6 de cornisa + 1,5 que asoma por
  encima) y **≈ 1,6 u de fondo** (se mete en la pared norte). Origen en el centro de la base, frente hacia +Z (hacia la cámara).
- **Caras laterales casi lisas y verticales:** por los dos lados le cae una cortina de agua pegada. Si abomban mucho, el agua las
  atraviesa o deja huecos. El relieve redondeado va en el **frente** y en la **cabeza**.
- **Piedra de la cueva**, la misma familia que `pared_foso_cueva` y la `columna_agrietada`: azul grisácea, húmeda y más oscura abajo,
  donde salpica el agua. La cabeza va cubierta de **musgo verde** con una mata de helecho pequeña, y como mucho dos o tres florecillas
  amarillo mantequilla, como en el vídeo. **Sin brillo pintado ni agua pintada**: el agua y la espuma las pone el motor.
- **Presupuesto:** 600–1 200 triángulos; se ve de cerca y está repetido tres veces.

#### `pilar_cascada` (600–1 200 tris) — separa las cortinas de la cascada
> A tall narrow cave rock pillar standing between two waterfalls: a chunky stack of rounded blue-grey stones fused into one column,
> flat almost vertical left and right sides, a rounded bulging front face with soft cracks, the lower third darker and damp, a thick
> cap of soft green moss spilling over the top edge with a small fern tuft and two or three tiny butter-yellow flowers, no water,
> no glow. 0.8 units wide, 3.1 tall, 1.6 deep.
> + [ESTILO]

Si Meshy lo saca demasiado ancho o con laterales abombados, pide *Image to 3D* con una vista frontal y otra lateral generadas antes
con el mismo texto. Al bajar: `meshy\entrada\pilar_cascada.glb` → `INTEGRAR_PIEZAS.cmd`. Después, en `_levantar_terraza` se cambia la
`BoxMesh` del pilar (y su cabeza de musgo) por la pieza `pilar_cascada`.
