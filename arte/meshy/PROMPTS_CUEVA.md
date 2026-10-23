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
