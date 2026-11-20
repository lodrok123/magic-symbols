# Concepto: notas manuscritas y el cuaderno del grimorio

Fecha: 20/11/2026. Estado: propuesta visual y de animación. No cambia nada del juego.

Página interactiva con el libro animado: https://claude.ai/artifact/BhE4hFewvZ6zgm8wYztH7X (privada; copia local en `docs/CONCEPTO_NOTAS_CUADERNO_2026-11-20.html`, que se abre en el navegador).

Los textos de ejemplo de este documento y de la página no son canon.

## Idea

Las últimas páginas del grimorio sirven de cuaderno. Ahí están las notas viejas de Leonardo, y ahí escribe Mid lo que le pasa. Parte de la historia se cuenta con esas notas y con papeles sueltos por el mundo (cartas, avisos, notas en celdas).

Todo el texto manuscrito usa **Caveat** (Google Fonts, licencia OFL): se lee bien en textos largos, tiene ñ, tildes, ¿ y ¡, y es variable (peso 400–700), así que una sola fuente da una mano distinta a cada personaje.

El libro sigue el estilo de `art/ui/grimorio_bosque.png` (ARTE §16): cuero marrón, lomo verde, esquinas doradas, cenefa de hojas con flores melocotón y cinta verde.

## Tres maneras de que aparezca el texto

Ver una nota escribirse solo tiene sentido si se escribe en ese momento.

| Modo | Qué se ve | Cuándo |
|---|---|---|
| **Ya escrita** | La nota aparece entera con el gesto de desdoblar el papel. | Notas encontradas: Marimanta, Benvito, aprendices, carteles. Páginas viejas de Leonardo. |
| **Trazo** | Una pluma recorre cada letra de izquierda a derecha. La tinta sale oscura y brillante y se seca en 1,8 s. Tacha cuando cambia de idea; marca casillas; dibuja bocetos. | Lo que escribe Mid: diario, encargos, listas que se van tachando. |
| **Despertar** | La tinta sube del papel con brillo verde (`#B9E57D`) y se asienta en sepia. Sin pluma. | Notas ocultas de Leonardo que se desbloquean cuando Mid aprende algo (sello, glifo, zona). Sirven de pista de puzle. |

Ejemplo de pista con *despertar*, ligada a T5 (Las mámoas, `docs/PUZLES_DEMO_RUTA_2026-11-20.md`): «Las mámoas no se cavan. Se tapan. Derriba al mouro y, mientras humee, echa tierra encima.», que aparece al conseguir el sello de tierra.

## Una mano por personaje

| Mano | Peso Caveat | Tinta seca | Tinta fresca | ms por letra | Modo normal | Papel |
|---|---|---|---|---|---|---|
| Mid | 450 | `#27497F` | `#0B2156` | 38 | trazo | páginas del grimorio |
| Leonardo | 500 | `#4B2D1B` (vieja `#6A4A33`) | brillo `#B9E57D` | 55 | despertar / ya escrita | páginas del grimorio |
| Marimanta | 640 | `#2D5B39` | `#0D381B` | 45 | ya escrita | carta con lacre verde de la Torre |
| Benvito | 420 | `#55514C` (carbón) | sin brillo | 30 | ya escrita | papel basto clavado |
| Aprendices | 420 | `#5D3C27` | `#2A160A` | 40 | ya escrita | trozo doblado |

Pausas en el modo trazo, sobre los ms por letra: espacio ×1,5 · coma ×4 · punto ×8 · cambio de línea ×10. La pluma va 60 ms por detrás de la letra, como `ManoPluma2D`.

## El libro como modelo 2D

Se genera por piezas sueltas y se monta en Godot. Una sola hoja sirve para todas las páginas y el giro lo hace el motor: un generador de imágenes no mantiene la misma hoja de un fotograma a otro, así que no se dibujan fotogramas. Medidas a la escala de `grimorio_bosque.png` (1470 × 1070).

| Pieza | Archivo | Medida (px) | Animación |
|---|---|---|---|
| Tapa exterior | `libro_tapa.png` | 735 × 1070 | Gira 180° sobre el lomo al abrir y cerrar. Lleva esquinas, emblema y correa. |
| Tableros abiertos | `libro_tableros.png` | 1470 × 1070 | Fondo fijo del libro abierto: cuero sin páginas. |
| Hoja con cenefa | `libro_hoja.png` | 700 × 975 | Todas las páginas. El reverso es la misma imagen espejada. |
| Hoja lisa | `libro_hoja_lisa.png` | 700 × 975 | Páginas arrancadas y notas dentro del libro. |
| Cantos de páginas | `libro_cantos.png` | 24 × 975 | Se repite en horizontal. El bloque izquierdo engorda según las páginas escritas; el derecho adelgaza. |
| Lomo | `libro_lomo.png` | 70 × 1100 | Cuero verde con costuras; asoma arriba y abajo. |
| Cinta | `libro_cinta.png` | 70 × 360 | Skeleton2D de 3 huesos. Balanceo continuo y sacudida al abrir y al pasar página. |
| Broche | `libro_broche_cerrado.png`, `libro_broche_abierto.png` | 140 × 180 | Se suelta antes de abrir: gira 24° y cambia de sprite. |
| Esquina dorada | `libro_esquina.png` | 140 × 140 | Una imagen, girada en las cuatro esquinas. |
| Sombra | `libro_sombra.png` | 1500 × 160 | Se encoge a la mitad con el libro cerrado. |

### Tiempos

| Animación | Secuencia |
|---|---|
| Abrir (1,7 s) | broche 0–220 ms · tapa gira 180° 220–1000 ms con rebote al final · cinta se sacude 1000–1700 ms |
| Pasar página (1,4 s) | hoja gira 0–700 ms con sombra sobre la página de abajo · cinta se sacude 700–1400 ms |
| Escribir entrada | pluma con 60 ms de retraso · 38 ms por letra (Mid) · secado 1,8 s |
| Cerrar (0,95 s) | tapa vuelve 0–800 ms · broche 800–950 ms |

El giro de la hoja: un shader en la hoja con dos texturas (anverso y reverso) y un progreso de 0 a 1. Empezar con giro plano con perspectiva (lo que muestra la página). Si se ve rígido, añadir curvatura de cilindro en el mismo shader.

### Prompts

Con `grimorio_bosque.png` como referencia. Páginas siempre en blanco: el texto lo pone el juego con Caveat, y las letras inventadas por el generador no se quitan bien con inpainting. El fondo liso sirve para el recortador de láminas (ARTE §23).

**1 · Lámina de piezas**

> Use the reference image as the exact style: hand-painted storybook game UI, brown leather grimoire, green leather spine, polished gold corner pieces, cream parchment with a leafy vine border and small peach blossoms. Make a game asset sheet with these pieces separated and evenly spaced on a flat solid #1E1F26 background, every piece seen straight from the front, flat, no perspective, no cast shadows, no text and no symbols on the pages:
> - the closed front cover: brown leather, four gold corners, a small embossed gold leaf emblem inside a circle in the center, a leather strap with a gold diamond clasp on the right edge
> - one blank parchment page with the vine border
> - the same blank page without any border
> - a green leather spine strip with light stitches
> - a green ribbon bookmark with a small gold leaf charm, hanging straight down
> - the gold clasp twice, closed and open

**2 · Tableros del libro abierto**

> Same style as the reference image. The open grimoire seen exactly from above with all of its pages removed: only the two inner brown leather boards, the green leather spine in the middle and the four gold corners. Empty, flat, symmetrical, no pages, no paper, no text. Solid #1E1F26 background.

**3 · Papeles para notas sueltas**

> Same hand-painted storybook style as the reference image. Three loose paper notes, flat, front view, evenly spaced on a solid #1E1F26 background, completely blank with no writing:
> - a cream letter sheet with a green wax seal pressed with a leaf near the bottom right corner
> - a torn piece of rough grey-brown paper with an iron nail at the top center
> - a small scrap that was folded in four and unfolded, with soft creases

## Cómo llevarlo al juego (propuesta)

- **Fuente.** `Caveat-VariableFont_wght.ttf` en `presentacion/ui/fuentes/`, con MSDF en la importación. Un `FontVariation` por mano para fijar el peso. Resuelve también lo pendiente de ARTE §11: el libro sigue con `ThemeDB.fallback_font`.
- **Las notas son datos.** Una fila por nota: `id`, `mano`, `modo` (ya / trazo / despertar), `papel`, `texto` y la flag que la desbloquea. Ejemplo: `leonardo_mamoas · leonardo · despertar · hoja · «Las mámoas no se cavan…» · global.sello.tierra`.
- **Control propio para el texto.** Maqueta con `TextParagraph` y dibuja cada letra con su alfa y su color. Así se sabe dónde está cada letra para llevar la punta de `ManoPluma2D` (`PUNTA_PX`) y soltar las gotas de `TintaPluma2D` al acabar.
- **Barrido dentro de cada letra.** Shader que recibe el rectángulo de la letra activa. Si cuesta, basta con que cada letra aparezca en 120 ms con un leve descenso.
- **El texto gira con la hoja.** Cada página se dibuja en un `SubViewport` y su textura va al shader de la hoja.
- **Transcripción.** Botón en la vista de nota que muestra el mismo texto en fuente limpia.

## Sin decidir

- Si el cuaderno vive en las últimas páginas del grimorio de hechizos o es un libro aparte.
- Qué notas ocultas de Leonardo hay y qué desbloquea cada una.
- Qué ocurrió la Noche de la Fada y cuánto cuentan las notas de ello.
