# Plan para homogeneizar el arte — 4 de octubre de 2026

Comparación de **lo que hay en pantalla** con la guía (`docs/guia_arte.png`,
`docs/ARTE.md`), medida sobre los PNG, y un plan por fases para que todo
parezca del mismo juego. Montajes: `familias.png` (guía / pipeline / `art/`)
y `heroe_ref_vs_render.png` (adjuntos en la conversación).

---

## 1. Diagnóstico: no son dos familias, son cuatro

Leyendo `pipeline/scenes/bosque_01/ms_terrain_config.json` y
`Output/trees/render_tree.log.json` se ve de dónde sale cada cosa; es
distinto de lo que dice `CONTEXTO.md` ("el arte sale del pipeline 3D"):

| Familia | De dónde sale | Aspecto | Medido |
|---|---|---|---|
| **A. Guía** (`guia_arte.png`) | referencia | *fantasía pintada*: valores oscuros, detalle, luz cálida, contorno suave | paleta bosque V 0,20–0,76, S 0,24–0,60 |
| **B1. Losas y props del pipeline** | **hojas 2D generadas** (`Terrain/Terreno.png`, `Assets/Forest001-004.png`) cortadas en rejilla; `dirt/path/water` se **dibujan por código** (`procedural_blocks`) | *cartoon cel*: contorno negro grueso, color plano y claro, sin textura | `grass` V **0,82** S 0,73; detalle interno (desv.) **4–8** |
| **B2. Árboles del pipeline** | **un solo GLB** (`tree_ghibli_01`, CC-BY) renderizado toon + contorno 3D, 12 variantes por tono | toon suave, verde azulado | V 0,38–0,48, detalle 13–15 |
| **B3. Personajes del pipeline** | GLB de Meshy, estilo `personaje_toon` | **render realista**: proporción 7 cabezas, sombreado suave, sin contorno, desaturado | héroe 130 px; goblins 75 px |
| **C. `art/` nuevo** (hielo, tierra, empujables, tótems, seto, puesto, baldosa, puente, recogibles) | imágenes 2D generadas sueltas, a 2x | pintado detallado, luz direccional, musgo, brillos | V 0,40–0,64, S 0,19–0,73, detalle **38–64** |

Dos conclusiones que cambian el plan:

1. **La familia más cercana a la guía es `art/`, no el pipeline.** Lo que
   desentona en pantalla son las losas cel (B1) y los personajes
   realistas (B3). Homogeneizar "hacia el pipeline" sería alejarse de la
   dirección de arte aprobada.
2. **La maga no es la de la referencia.** `docs/referencia_personaje.png`
   (canon según `ARTE.md` §4): chibi de ~3 cabezas, capa azul con ribete
   dorado, dos trenzas. El `hero` exportado: 7 cabezas, abrigo blanco/rojo/
   verde, pelo recogido. No es un problema de estilo de render; es otro
   personaje. Y en el catálogo sigue `"estado": "pendiente"`.

Lo que hace que se note en pantalla, por orden:

| Diferencia | Dónde se ve | Por qué molesta |
|---|---|---|
| **Valor** (luminosidad): losas a V 0,7–0,8 junto a props/`art/` a 0,4–0,6 | todo el suelo | el suelo "flota" más claro que lo que hay encima; la guía es oscura |
| **Contorno**: grueso en B1, fino 3D en B2, ninguno en B3 ni C | bordes de todo | el ojo clasifica por contorno antes que por color |
| **Proporción**: cubos y props chibi (B1, C) con personajes realistas (B3) | cada vez que la maga pisa una losa | un adulto de 7 cabezas sobre un cubo de juguete |
| **Textura**: 4–8 de desviación en losas frente a 40–60 en `art/` | hielo/tierra/empujable sobre hierba | una pieza "fotográfica" sobre un suelo plano |
| **Luz**: direccional marcada en C (sombras a un lado) frente a plana en B1 | tótems, seto, puesto | `ARTE.md` §6 lo prohíbe porque la repetición delata la sombra |
| **Resolución**: props B1 ampliados ×1,2–1,6; `art/` reducido ×0,5 | props | lo ampliado se emborrona, lo reducido queda nítido |

---

## 2. La decisión que hay que tomar primero (Pablo)

**Objetivo visual = la guía** (fantasía pintada, oscura, contorno suave).
Es lo que dice `ARTE.md` desde septiembre y es lo que `art/` ya cumple a
medias. Las alternativas y lo que cuestan:

| Opción | Qué se rehace | Coste | Resultado |
|---|---|---|---|
| **(a) Hacia la guía** (recomendada) | hojas de losas/props del pipeline (2 generaciones con imagen de referencia) + estilo de render de personajes + rehacer el héroe | medio; los scripts del pipeline se reutilizan | el juego se parece a la guía; `art/` casi no se toca |
| (b) Hacia el cartoon cel de B1 | todo `art/` (≈40 piezas), árboles, personajes | alto | más barato de producir después, pero contradice la guía y pierde el ambiente oscuro que `Glow.AMBIENTE` necesita |
| (c) Dejarlo y unificar solo por luz en Godot (`CanvasModulate`) | nada | casi nulo | tapa el valor, no el contorno ni la proporción; se seguirá notando |

Lo que sigue asume **(a)**. Si se elige otra, cambia la fase 2, no la 1.

---

## 3. Fases

### Fase 1 — Un normalizador en el pipeline (Pipeline, 1 sesión)

Antes de regenerar nada, un paso de post-proceso **común a todo lo que
sale a `export_godot/`**, también a lo que hoy está en `art/`. Es lo que
más iguala por euro: pasa a todas las piezas por el mismo embudo.

Herramienta nueva en `pipeline/tools/` (`ms_estilo.py`, un paso más de
`EXPORTAR_GODOT.cmd`), con estos ajustes **medibles**:

1. **Valor**: curva que lleve la media de cada pieza al rango de la paleta
   del bioma (`ARTE.md` §2; bosque V 0,35–0,65). Las losas bajan, nada
   sube. Comprobación: media de V de la cara superior de `grass` entre
   0,50 y 0,60 (hoy 0,82).
2. **Saturación**: tope 0,65 (hoy `grass` 0,73, `barrel` 0,77).
3. **Contorno**: uno solo para todos, 1 px al tamaño final, color = el
   local oscurecido un 55 % (no negro). Se **añade** a B3 y C y se
   **sustituye** en B1 (ver fase 2: la hoja nueva se pide sin contorno).
4. **Luz**: dirección única arriba-izquierda, suave. Para `art/` es un
   check, no un filtro: lo que traiga sombra proyectada marcada
   (tótems, seto, puesto) se regenera en la fase 3.
5. **Tamaño**: cada pieza al **píxel final** (losa 128×102, cara en y=33;
   props con `heights` del config a 1x; personajes 192×240 ya está). El
   Juego deja de escalar: `PROP_DATOS` a 1,0, `art/` sin el ×0,5.
6. **Un `style_report` por pieza** en `REPORTE.md` con V, S, desviación y
   si lleva contorno. Es lo que QA mira antes de aprobar (sección 5).

Por qué un filtro y no "regenerar bien": las hojas se van a regenerar
varias veces (biomas nuevos, estados) y cada tanda sale distinta; el
embudo hace que la quinta tanda se parezca a la primera.

### Fase 2 — Regenerar las hojas de losas y props (Pipeline, 1–2 sesiones)

La hoja `Terreno.png` y `Forest001-004.png` se piden de nuevo, con **la
guía como imagen de entrada** (la regla de `ARTE.md` §4: una imagen
ancla, un texto solo describe) y estas instrucciones fijas:

- Mismo recorte (4×3 y 3×3, mismos nombres), **sin contorno negro**
  (lo pone la fase 1), luz plana, textura pintada en las tres caras.
- Valores de la paleta de bosque; nada por encima de V 0,7 salvo brillos
  puntuales.
- `procedural_blocks.enabled = false` y `dirt`, `path`, `water` salen de
  la hoja: el agua "de código" es hoy la losa más plana de todas
  (desviación 2,0).
- `water_frozen_1..3` y `earth_stepping_stone` **en la misma hoja**, para
  que hielo y tierra creada compartan mano con el agua y la hierba (cierra
  1.1 y 1.2 de `QA_ARTE.md`).

Árboles: se mantienen (un GLB toon ya pasa por el normalizador); solo
bajar `val` de las variantes amarillas (`tree_yellow` ×1,85 se sale de la
paleta) y añadir un segundo GLB para que no sean doce tintes del mismo
árbol. La licencia CC-BY de `tree_ghibli_01` obliga a acreditarlo en el
juego (créditos): anotarlo ya.

### Fase 3 — Lo que hoy vive en `art/` (Pipeline, por tandas)

No se tira: se **pasa por el embudo** de la fase 1 y se mueve a
`export_godot/terrain/bosque_01/sprites/props/` a 1x con su `meta.json`
(`ancla: base_centro`, como dice `CONTRATO_GODOT.md`). Se regenera solo
lo que falle el check de luz (sombra proyectada) o duplique algo del
pipeline:

| Pieza | Acción |
|---|---|
| hielo ×3, `earth.png`, empujables | **se retiran**: salen de la hoja nueva (fase 2) |
| tótems, seto, tronco, setas, telaraña | normalizar; regenerar solo si la sombra lateral se ve al repetirlos |
| puesto, baldosa, placa, puente, piedras | normalizar y mover; son piezas únicas, la sombra se tolera |
| `art/forest/*` (Sketch Town) y `art/fogata_*`, `art/grass*`, `art/water*` | **borrar** cuando el nivel que los usa cambie de ruta; son la tercera y cuarta fogata/hierba |
| `recogibles/`, `ui/` | fuera del plan: interfaz, no pisa la rejilla |

El Juego cambia rutas por tandas (una constante por pieza en
`nivel_base.gd`: `HIELO_ART`, `BOSQUE_ART`, `PUESTO_ART`, `EMPUJABLE_ART`,
`GUARDADO_ART`) y borra el duplicado de `art/` en el mismo cambio.

### Fase 4 — Personajes (Pipeline, la más cara; 2–3 sesiones)

Dos problemas distintos, que se resuelven por separado:

1. **Estilo de render** (todos los personajes): aplicar al perfil
   `personaje_toon` lo que ya hace `anime_a` en los árboles (`toon`,
   `outline3d`, luz con relleno) — el log del árbol muestra que el código
   existe. Después pasa por el normalizador. Comprobación: el goblin con
   contorno y V media 0,4–0,6 junto a una losa de la hoja nueva, en
   `review/scale_test_8dir.png`.
2. **El héroe**: hace falta **otro modelo** que sea la de
   `referencia_personaje.png` (chibi, capa azul, trenzas). Pedirlo a Meshy
   con esa imagen como entrada y, antes de animar nada, aprobar una hoja
   de 8 direcciones estática contra la referencia (el paso que `ARTE.md`
   §4 describe). Los 15 clips se vuelven a procesar después: el pipeline
   ya lo hace solo, lo caro es aprobar el modelo.

   *Proporción*: si se mantiene la maga de 7 cabezas por coste, hay que
   asumir que **el mundo es el que es chibi** y bajar los props de `art/`
   (seto 100 px, tótem 105 px) para que no sean más altos que ella. Es
   la decisión más visible del plan; conviene mirarla en Godot con la
   hoja nueva antes de pedir el modelo.

Goblins: con el estilo de render arreglado valen; sus clips de golpe y
muerte van aparte (`QA_ARTE.md` §2).

### Fase 5 — Luz en Godot (Pablo / Juego, 1 sesión)

Es la fase 4 de `PLAN_ARREGLOS.md` y aquí deja de ser opcional:
`CanvasModulate` con `Glow.AMBIENTE[bioma]` + `PointLight2D` en fogatas,
tótems y hechizos. Con las piezas ya normalizadas, la luz común es lo que
hace que una losa, un tótem y la maga compartan la misma tarde. Sin las
fases 1–2 solo oscurecería el desajuste.

### Fase 6 — Compuerta de QA (este contexto, continuo)

Ninguna pieza entra en `export_godot/` sin:

- `style_report` dentro de rango (V, S, contorno, tamaño final);
- montaje de **la pieza sobre `grass` de la hoja nueva junto al héroe**
  (`review/en_contexto.png`), que es lo que se mira a ojo;
- para losas, la comprobación de geometría de `QA_ARTE.md` (128×102, cara
  en 33); para personajes, `ancla_suelo_px` y clips sin bucle que acaban
  donde deben.

---

## 4. Orden y dependencias

```
Pablo decide (a)  →  F1 normalizador  →  F2 hojas nuevas  →  F3 art/ por tandas
                                      ↘  F4.1 render personajes  →  F4.2 héroe nuevo
                     F5 luz en Godot (cuando F2 esté)      F6 QA en cada paso
```

Qué se ve primero en pantalla: tras F1+F2 el suelo deja de flotar y todo
tiene el mismo borde (es el 70 % de la diferencia). F4.2 es lo más caro
y lo único que de verdad necesita una decisión de diseño (proporción).

## 5. Qué le toca a cada uno

- **Pablo**: elegir (a)/(b)/(c); decidir proporción del héroe (F4.2) tras
  verlo en Godot; F5; acreditar `tree_ghibli_01`; añadir este archivo a
  `PROPIETARIOS.md`.
- **Pipeline**: F1 (`ms_estilo.py` + `style_report`), F2 (hojas con la
  guía como entrada, `procedural_blocks` off, hielo y tierra en la hoja),
  F3 (mover/normalizar `art/`), F4.
- **Juego**: en cada tanda de F3, cambiar la ruta y borrar el duplicado;
  `PROP_DATOS` a 1,0 cuando los props lleguen a 1x; `EarthBlock` y
  `WaterBlock` a la hoja nueva (`QA_ARTE.md` 1.1/1.2).
- **QA (este contexto)**: F6; volver a medir V/S/desviación por familia
  después de F1 y de F2 y anotar aquí los números.
