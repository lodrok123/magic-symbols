# Prompts del fondo del agua: algas, rocas de río y textura de lecho (22 de octubre de 2026)

Para el agua «filtro» (agua casi transparente y turquesa sobre un fondo real, referencia de Pablo: un río de *Echoes of Wisdom*).
El agua tiñe y oscurece todo lo que hay debajo, así que **el fondo se pide con sus colores de verdad, claros y de bajo contraste**: el turquesa lo pone el motor.
Mismo método que `PROMPTS_ELEMENTOS.md`: lámina por familia (`recibir_assets.py ver` → `lote` → `instalar`) o pieza suelta. Pega el bloque [ESTILO] **al final** de cada prompt.

```
[ESTILO] Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired,
cute rounded chunky shapes, clean readable silhouette, soft cel shading, matte, low contrast albedo,
no harsh baked shadows, no baked lighting, single object, centered, no base, no ground plane,
no background, no outline, no black lines.
```

## Reglas que NO son de estilo

1. **Sin agua pintada:** ni tinte azul, ni brillos, ni cáusticas, ni burbujas en la textura. Colores secos y naturales; el agua del juego los vuelve turquesa.
2. **Bajo contraste** (el valor varía poco): bajo el agua todo se lee como una sola masa; si una piedra lleva sombras pintadas fuertes, sale como una mancha.
3. **Pocos triángulos:** algas 100–400, rocas 600–1.500; textura 512² (256² las algas).
4. **Origen** en el centro de la base, Y arriba, frente +Z. Casilla = 2,3 u; la jugadora mide ~1 u.
5. Los ids son los que el juego ya busca (`arte/meshy/piezas/<id>.glb` y `arte/suelo_meshy/lecho_rio.png`): con poner el archivo, se usa solo.

---

## 1. Textura de lecho — `lecho_rio.png` (imagen 2D, no 3D)

Va en `arte/suelo_meshy/lecho_rio.png`, **1024 × 1024, seamless (que repita sin costura en los 4 lados)**, vista cenital.

> A seamless tileable top-down texture of a shallow riverbed: densely packed smooth rounded river pebbles and flat cobbles of different sizes (small to palm-sized), soft beige, warm grey, sand and pale ochre stones with a few muted green-grey ones, thin gaps of fine sand between them, a few tiny patches of soft green moss. Hand-painted stylized game texture, soft pastel colors, very low contrast, flat even lighting, no shadows, no water, no reflections, no caustics, no blue tint. Seamless tiling on all four sides.

Variantes que conviene pedir (2–3 generaciones y elegir): una con cantos más grandes (lecho de río) y otra más menuda (charca).

## 2. Algas — lámina `algas` (`alga_0..3`)

**Para qué:** matas que crecen del fondo en la parte honda y se mecen (el juego las anima con el viento de la corriente).

### Lámina
> A game asset sheet of stylized underwater river plants laid out in a row with space between each piece: four clumps of soft aquatic grass and ribbon-like water weeds growing upward from a small common base, each a different shape (a tight tuft of thin blades, a wide fan of long ribbons, a short bushy clump, a tall clump with a few curling tips). Soft fresh green and teal-green with lighter tips, simple rounded blade shapes, double-sided. Each piece separate and not touching. No water, no bubbles, no glow.

| id | qué | medida | tris | textura |
|---|---|---|---|---|
| `alga_0..3` | mata de algas | 0,3–0,7 u de alto, 0,3–0,5 de ancho | 100–400 | 256² (puede ser la misma para las 4) |

**Si Meshy las saca macizas o raras:** pide la versión 2D (tarjetas): un atlas 4 × 1 de 1024 × 256 con fondo transparente, «four clumps of stylized underwater grass and water weeds, side view, hand-painted, soft green and teal, transparent background, no outlines», y el juego las pone como tarjetas cruzadas.

## 3. Rocas de río — lámina `rocas_rio` (`roca_rio_0..2`)

**Para qué:** las piedras grandes del fondo (como la roca del ejemplo), sueltas en la parte honda del río y de las charcas.

### Lámina
> A game asset sheet of stylized river boulders laid out in a row with space between each piece: three large smooth water-worn rocks, rounded and slightly flattened, one made of a few stacked rounded lumps, one single smooth egg-shaped boulder, one low wide flat-topped rock. Soft warm grey and pale blue-grey stone with a few gentle patches of muted green moss on top, faceted rounded forms, very low contrast. Each piece separate and not touching. No water, no wet shine, no glow.

| id | qué | medida | tris | textura |
|---|---|---|---|---|
| `roca_rio_0..2` | roca grande del fondo | 0,6–1,2 u de ancho, 0,3–0,7 u de alto | 600–1.500 | 512² |

Referencia de forma y de piedra: la `roca` de la lámina «puzle» y las rocas musgosas del bosque (`roca_musgosa`), pero **más lisa** (desgastada por el agua) y **más clara**.

## Prioridad

1) **`lecho_rio.png`** (es lo que más cambia el aspecto: todo el fondo). 2) **Rocas** (dan escala y puntos de interés). 3) **Algas** (vida; las más difíciles de que salgan bien en 3D).
Hasta que lleguen, el juego usa un lecho de cantos procedural y no pone algas ni rocas (sin primitivas de relleno).
