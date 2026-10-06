# El grimorio de la elfa: libro, pluma y páginas (5 de octubre de 2026)

El arma de la elfa **no es un báculo: es el grimorio**. Es el elemento principal del personaje. Lo lleva
siempre puesto, colgado de la cadera izquierda con una correa, y es el mismo libro que se abre con **T**.
Por eso la tapa del libro 3D y las páginas 2D tienen que parecer del mismo objeto: cada estilo de
abajo trae su tapa, su pluma y su página.

**Ya está en la maqueta, provisional:** la elfa lleva un libro sencillo hecho por código en la cadera,
con la pluma en el lomo (`equipo_3d.gd`). En `LabVfx3D`, la **T** abre la doble página con su animación;
dentro, **1/2** cambia de libro (aprendiz o avanzado), **Q/E** cambia de estilo y **Espacio** llena los
huecos de muestra. Las páginas provisionales salen de `grimorio/generar_paginas.py`.

**Referencias:** la imagen de la elfa nueva (la tuya) y `referencias/bookseller_referencia.png` para el
estilo. Para las páginas, `poc_25d/grimorio/pagina_<estilo>_<libro>.png`.

---

## 1. Estilos (elige uno o mezcla)

| estilo | tapa del libro | pluma | página |
|---|---|---|---|
| **botánico** (recomendado: va con su vestido) | cuero verde azulado como su vestido, esquinas de latón dorado, una hoja dorada en relieve en el centro, ramitas bordadas en el lomo, cierre de cuero con broche de hoja | pluma crema con la punta verde azulado y cañón dorado | papel crema, ramas con hojas verde salvia y florecitas rosas en las esquinas |
| **astral** | azul noche suave, estrellas y luna creciente doradas, esquinas de latón, una piedra lunar pálida en el centro | pluma blanca con la punta lavanda y estrellitas doradas | papel lila muy claro, fases de la luna arriba y constelaciones abajo |
| **acuarela** | cuero marrón claro como su cinturón, flores pintadas en acuarela (rosa y menta), cantos de latón, cinta rosa de marcapáginas | pluma rosa pálido con la punta menta | papel blanco roto con manchas de acuarela rosa y menta en las esquinas |
| **bosque vivo** *(solo tapa; con las páginas del botánico)* | tapas de madera clara con musgo, una flor viva y raíces que abrazan el lomo, un cristal verde en el centro que brilla | pluma hecha con una hoja larga y nervadura dorada | (la del botánico) |

## 2. El libro 3D (imagen de concepto y luego Meshy, como la elfa)

**Paso 1. Imagen de concepto.** Sube la imagen de la elfa nueva como referencia de estilo. Una imagen por estilo:

> A magic grimoire book that belongs to the elf girl in the reference image, same stylized chibi 3D game
> style, same soft hand-painted texture and palette. **[TAPA DEL ESTILO, de la tabla]**. Chunky, slightly
> oversized toy-like proportions, thick soft corners, closed book standing upright, a short leather strap
> with a small buckle on the spine so it can hang from a belt. A writing quill tucked into the strap:
> **[PLUMA DEL ESTILO]**. Single object, no character, three-quarter front view, full object visible, plain
> light background, soft even lighting.

Ejemplo, botánico completo:
> ...teal-green leather cover like her dress, gold brass corners, an embossed golden leaf in the center,
> small embroidered twigs on the spine, a leather clasp with a leaf-shaped brooch... A writing quill tucked
> into the strap: cream feather with a teal tip and a golden nib...

**Paso 2. Meshy, de imagen a 3D**, sin rig. Texto: *"stylized chibi game prop, closed book, single object"*.

**Paso 3. Opcional: el libro abierto**, para cuando se abra en 3D en la mano (no hace falta para la T de
ahora, que es 2D):
> The same grimoire open flat, both pages visible and blank cream, the cover and strap the same as the
> reference, seen from three-quarter above, single object, plain light background.

**Paso 4.** Deja los GLB en `meshy\entrada\` como `grimorio_<estilo>.glb`. Yo los paso a
`poc_25d\equipo\grimorio.glb` y los coloco en la cadera.

**Pluma suelta (opcional).** Para dibujar en la animación de la T, la elfa la sacaría y la tendría en la mano:
> A single writing quill for the elf girl in the reference, **[PLUMA DEL ESTILO]**, slightly oversized and
> soft, golden nib, single object, vertical, plain light background.

## 3. Las páginas (lo que se ve con la T)

Hay dos libros, y cada uno es una lámina distinta:
| libro | qué se dibuja | lámina |
|---|---|---|
| **aprendiz** `s1g3` | 1 sello (elemento) en el núcleo y hasta 3 glifos | núcleo entero y 3 huecos de glifo debajo del círculo |
| **avanzado** `s2g6` | 2 sellos (núcleo partido en dos, como un yin-yang) y hasta 6 glifos | núcleo partido y 6 huecos (2 filas de 3) |

La página derecha es igual en los dos: los 12 glifos conocidos (4 × 3) y los 6 elementos.

**Las medidas mandan.** El juego dibuja encima de la lámina con los números de `grimorio/paginas.json`:
círculo con centro (455, 400) y radio 255, núcleo de radio 105, huecos y rejilla. Para que una lámina
pintada encaje:
1. Usa la `pagina_<estilo>_<libro>.png` provisional como **imagen de composición** (img2img o
   "referencia de estructura" con fuerza alta), **no** como estilo.
2. Pide el mismo tamaño, 1600 × 1000.
3. Cuando la tengas, pásamela: compruebo las medidas, y si se han movido, ajusto `paginas.json` a la
   lámina (como se hizo con `art/ui/grimorio.png`).

Prompt, estilo botánico, aprendiz:
> An open magic grimoire seen from directly above, two pages filling the image, flat and evenly lit, cozy
> pastel storybook style matching a chibi elf game. Cream parchment pages with soft paper texture.
> Left page: a large thin ink circle with a dotted outer ring, divided into 8 sectors by faint dotted
> lines, a smaller solid inner circle in the center (empty, for one element seal), and below the circle
> a row of 3 small empty round sockets. Right page: a grid of 12 empty round frames (4 columns x 3 rows)
> and below a row of 6 small round medallions in soft colors (coral, sky blue, sand, mint, butter yellow,
> pale ice blue). Corners decorated with thin vines, sage-green leaves and tiny pink flowers, thin warm
> brown ink lines, small gold accents. Teal leather cover visible at the edges. No text, no letters,
> no characters, keep all circles and frames EMPTY.

Para el **avanzado**, cambia la parte de la izquierda por:
> ...a smaller inner circle split in two halves by an S-shaped curve like a yin-yang (two seals), and
> below the circle two rows of 3 small empty round sockets (6 total)...

Para **astral**: *"pale lilac paper, moon phases along the top, tiny gold constellations along the bottom,
dark blue cover at the edges, star-shaped gold accents"*. Para **acuarela**: *"off-white paper with soft
pink and mint watercolor washes in the corners, delicate vines, light brown leather cover at the edges"*.

## Qué falta decidir (tuyo)
- **Estilo:** botánico, astral, acuarela o una mezcla.
- **¿El libro avanzado es otro libro** (se cambia la tapa al progresar) **o el mismo** con más páginas
  desbloqueadas? Si es otro, harían falta dos tapas.
- **¿La elfa saca la pluma y "escribe"** en la animación de la T? Haría falta una animación de Mixamo/Meshy
  tipo "writing" o "reading a book".
