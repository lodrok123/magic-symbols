# Decorado del bosque con Meshy — prompts

Objetivo: que el decorado tenga **el mismo acabado que la chibi**: textura pintada estilo anime, colores pastel,
formas redondeadas, sombreado suave y contraste bajo. Mismo generador, misma plantilla de estilo y misma paleta.

## Vía recomendada: *Image to 3D* con las referencias (5 de octubre)

La lámina `referencias/_lamina.png` (13 piezas en el estilo buscado) ya está recortada pieza a pieza en
`referencias/<id>.png`: 1024×1024, fondo blanco, una pieza por imagen, con el mismo id que la tabla de abajo.
Es mejor entrada que el texto: Meshy copia forma, colores y proporciones de la imagen.

1. *Image to 3D* con `referencias/<id>.png`. Si deja añadir texto, pega el [ESTILO] y el prompt de la pieza.
2. **Pide la textura** (refinado / texturizado). El GLB de prueba que se generó de la lámina entera
   (`Meshy_AI_Whimsical_Forest_Elem_…_generate.glb`) es la vista previa sin textura: una sola malla sin
   material, sin UV y sin normales, con las 13 piezas pegadas. Sirve para ver la forma, no para el juego.
3. **Una pieza por generación**, no la lámina entera: así cada una tiene su textura, su tamaño y su id.
4. **Contorno**: la lámina tiene un trazo oscuro alrededor de cada pieza y la chibi no. Si Meshy lo pinta en la
   textura, añade al texto `no outline, no black lines` o regenera la textura.
5. Exporta GLB y guárdalo como `poc_25d\meshy\<id>.glb`, igual que en la vía de texto.

## Cómo usarlo (vía de texto)
1. Genera **primero `arbol_redondo`** como prueba de estilo. Si no casa con la chibi, ajusta el bloque de estilo
   antes de seguir: cambiarlo después obliga a repetirlo todo.
2. Para cada pieza: *Text to 3D* con **[ESTILO] + el prompt de la pieza**. Genera varias opciones y quédate con
   la que mejor case con la chibi (pon las dos imágenes juntas para decidir).
3. Si Meshy permite **imagen de referencia de estilo**, usa la de la chibi sobre el camino pastel: es lo que más
   homogeneidad da.
4. Si permite elegir **topología / número de polígonos** al refinar o exportar: triángulos, ~10.000 en los
   árboles y ~3.000–5.000 en lo demás. El modelo de la chibi pesa 19 MB; con 13 piezas así el proyecto
   crecería mucho.
5. Exporta **GLB**, sin rig ni animación, y guárdalo como `poc_25d\meshy\<id>.glb` (el id de la tabla).
   El tamaño y el pivote no importan: la escena lo escala a su alto y lo apoya en el suelo.
6. Abre Godot para que lo importe y lanza `PruebaDiorama.tscn`: la pieza sustituye sola al modelo de Kenney.

## [ESTILO] — se pega delante de cada prompt
```
Stylized chibi anime game asset, hand-painted texture, soft pastel colors, Ghibli-inspired, cute rounded chunky
shapes, clean readable silhouette, soft cel shading, matte, no harsh baked shadows, single object, centered,
no base, no ground plane, no background.
```

## Negativo (si el modo lo admite)
```
realistic, photorealistic, metallic, glossy, dark, grim, high contrast, noisy texture, ground plane, base,
pedestal, text, multiple objects, sharp spikes
```

## Paleta (de la captura de la chibi)
Hierba menta `#a8d9a0`, camino crema `#ffe8aa`, vetas melocotón `#f9d09a`, tierra melocotón `#e6b98f`,
piedra gris lila `#dde0ea`, agua `#a3dbe0`, sombra gris cálido `#69645b`, acento rosa `#f7c6d3`,
acentos de la chibi: oro `#f9d792`, petróleo `#225571`.

## Piezas
| id | alto (unid.) | prompt de la pieza |
|---|---|---|
| `arbol_redondo` | 4,2 | Round broadleaf tree with a big fluffy cloud-like canopy in mint and soft green tones, short thick warm brown trunk with a gentle curve, a few leaf clumps, soft rounded volumes. |
| `pino` | 4,6 | Cute stylized pine tree made of three rounded stacked tiers of soft teal-green foliage, short warm brown trunk, pastel tones. |
| `arbusto` | 1,0 | Small round fluffy bush, soft mint-green leaves in rounded clumps, pastel. |
| `arbusto_flores` | 1,0 | Small round bush with tiny pastel pink and cream flowers dotted over soft green leaves. |
| `matas` | 0,45 | Small clump of soft grass blades, mint green with lighter tips, rounded chunky blades. |
| `flores` | 0,4 | Small cluster of three cute flowers, pastel pink, cream and soft yellow petals on short green stems with two leaves. |
| `roca_grande` | 1,4 | Large rounded boulder, soft lavender-grey stone with gentle facets and a little mint moss on top. |
| `piedras` | 0,35 | Group of three small smooth rounded pebbles, soft lavender-grey and cream. |
| `tocon` | 0,6 | Cut tree stump with visible pale peach rings on top, warm brown bark, small mushroom on the side. |
| `tronco` | 0,7 | Fallen log lying on its side, warm brown bark, pale peach cut ends with rings, a little moss. |
| `setas` | 0,35 | Cluster of three cute mushrooms with rounded caps, soft coral-pink caps with cream dots, cream stems. |
| `valla` | 0,8 | Short wooden fence segment, two rounded posts and two horizontal rails, warm peach-brown wood, soft rounded edges. |
| `cartel` | 1,3 | Wooden signpost with one arrow-shaped plank, warm peach-brown wood, rounded edges, blank sign without text. |

## Qué comprobar en cada pieza
- **Silueta legible** desde arriba y algo inclinada (la cámara del juego está a 20° de la vertical).
- **Sin suelo ni peana** pegados al modelo (si los trae, se ven flotando o hundidos).
- **Colores** dentro de la paleta: si sale saturado u oscuro, regenera la textura antes de exportar.
- **Peso** del GLB: árboles por debajo de ~5 MB y el resto por debajo de ~2 MB.
