# Más assets en el mismo estilo — lámina 2, vegetación y suelo

La lámina 1 funcionó: imagen con todas las piezas → Meshy *Image to 3D* de la lámina entera → texturizado →
Claude la separa (`separar_lamina.py`). Se repite igual. **Usa siempre `referencias/_lamina.png` como imagen de
referencia de estilo** en el generador de imágenes, para que todo salga de la misma mano.

## Reglas para cualquier lámina (para que Claude la pueda separar)
- Fondo **blanco liso**, piezas **separadas entre sí** (nada se toca ni se solapa), sin sombras en el suelo,
  sin texto ni números.
- **Filas claras**: las piezas de una fila a la misma altura más o menos; Claude las lee por filas, de
  arriba abajo y de izquierda a derecha, en el orden de la lista.
- Vista de 3/4 frontal, cada pieza entera.
- Al subirla a Meshy, igual que la primera: la lámina entera, y después texturizar.
- Deja el GLB texturizado en `poc_25d\meshy\entrada\` **junto con la imagen de la lámina** (Claude la
  necesita para saber qué pieza es cada una).

## Lámina 2 — objetos del juego (13 piezas)

```
Game asset sheet in exactly the same art style as the reference image: cute chibi stylized hand-painted,
soft pastel colors, Ghibli-inspired, rounded chunky shapes, soft shading. 13 separate objects on a plain white
background, 3/4 front view, clear space between objects, no overlap, no ground shadows, no text.
Row 1 (4 big objects): a stone archway gate with a glowing blue rune on the keystone; a small wooden market
stall with a striped pastel awning and a counter; a carved stone totem with a glowing rune; a standing stone
brazier with an iron bowl, unlit.
Row 2 (5 objects): a campfire ring of stones with stacked logs, unlit; a small wooden treasure chest with brass
corners, closed; a wooden barrel; a wooden crate; a pushable earth block (cube of packed soil with grass on top
and a carved rune).
Row 3 (4 objects): a pushable ice block (translucent pale blue cube with frost); a round stone pressure plate set
in the ground; a flat stone checkpoint tile with a carved glowing rune circle; a clump of water reeds and two
lily pads.
```

Ids (en este orden): `arco_puerta, puesto, totem_runico, brasero, fogata, cofre, barril, caja, bloque_tierra,
bloque_hielo, placa_peso, baldosa_guardado, juncos`.

Nota: la luz de las runas y el fuego los pone el juego (shaders y partículas); en el modelo, la runa solo tiene
que verse pintada de azul claro.

## Lámina 3 — vegetación (opcional, rehace `matas` y `flores`, que salieron flojas)

```
Same art style as the reference image. 8 separate small plants on a plain white background, 3/4 front view,
clear space between them, no overlap, no shadows, no text.
Row 1: a tall clump of soft grass blades; a cluster of three flowers with clear pink, cream and yellow petals
and green leaves; a fern; a lavender bush.
Row 2: a small clover patch with tiny white flowers; a berry bush with red berries; a small flowering vine
patch; a clump of short grass with tiny blue flowers.
```

Ids: `matas, flores, helecho, lavanda, trebol, arbusto_bayas, enredadera, hierba_flores`.

## El suelo: texturas, no modelos

Un suelo hecho con Meshy no encaja casilla con casilla (las formas salen irregulares). Lo que sí funciona: los
bloques de la escena, que ya encajan, **pintados con texturas del mismo estilo**. La escena ya está preparada:
en cuanto haya imágenes en `poc_25d\suelo_meshy\`, los bloques las usan en lugar del color liso, y la textura
sigue de una casilla a otra sin cortes.

Genera estas 6 imágenes **cuadradas (1024×1024 o más)**, con `referencias/_lamina.png` como referencia de estilo:

| archivo | prompt (añade delante el bloque común de abajo) |
|---|---|
| `hierba_arriba` | soft mint-green grass seen from directly above, small painted leaf strokes, a few tiny cream and pink flowers |
| `path_arriba` | pale cream sandy dirt path seen from directly above, a few small rounded pebbles, soft peach patches |
| `dirt_arriba` | warm peach-brown soil seen from directly above, small clods and a few tiny stones |
| `stone_arriba` | pale lavender-grey stone flagstones seen from directly above, rounded edges, a little mint moss between them |
| `water_arriba` | light turquoise shallow water seen from directly above, soft painted ripples and small highlights |
| `cuerpo` | side cross-section of the ground: warm peach-brown soil layers with a few small roots and pebbles, seen straight from the side |

Bloque común:
```
Seamless tileable texture, hand-painted stylized, same art style and pastel palette as the reference image,
flat even lighting, no perspective, no shadows, no objects, no border, fills the whole square.
```

Déjalas en `poc_25d\suelo_meshy\entrada\` con cualquier nombre. Claude las pasa a sin costuras de verdad (el
generador casi nunca lo consigue del todo), las renombra y las deja en `poc_25d\suelo_meshy\`.

**Orden recomendado:** primero `hierba_arriba` y `cuerpo` (con esas dos ya se ve el 80 % del suelo), después el
resto, después la lámina 2.
