# QA de arte — revisión del 4 de octubre de 2026

Revisión hecha **midiendo los PNG y leyendo el código que los coloca**, no
mirando el juego: cada punto marcado con **[Godot]** hay que confirmarlo con
F6 antes de arreglarlo. Responsable según `docs/PROPIETARIOS.md`.

Cómo se midió: para cada PNG, la fila más ancha del dibujo (= centro de la
cara superior de una losa) y el rectángulo opaco; para cada clip, la altura
de la figura en cada fotograma de la fila S.

---

## 1. Bloques — lo que cumple y lo que no

| Pieza | Medido | Contrato (128 ancho, cara en y=33) | Estado |
|---|---|---|---|
| 15 bloques `export_godot/.../blocks/*.png` | 128×102, cara en y=33, centro x=63.5 | ✔ | **bien** |
| `art/hielo_1..3.png` | 128×176, cara en **y=96** | ✗ | desalineado (1.1) |
| `art/earth.png` (EarthBlock) | 128×176, cara en **y=92**, sin escala ni offset | ✗ | desalineado (1.2) |
| `art/empujable_*.png` | 200×207 a 0.5 → cubo de 100 px con costado de ~40 | — | otra familia (1.3) |
| props del pipeline | 38–51 px de ancho, el juego los amplía ×1.2–1.6 | — | borrosos (1.4) |

### 1.1 El hielo baja ~22 px al congelar el agua — **[Godot]** · Pipeline (o Juego)

> **Hecho 5/10 (copia `paranda`, Pipeline):** `nivel_base._agua()` usa `water_frozen_1..3` del pipeline y se quitó `HIELO_ART`. Falta comprobar en Test2 y borrar `art/hielo_1..3` (con Godot cerrado).

`water_block.gd` hace `$Visual.texture = hielo[0]` sin tocar `offset`. El
offset lo fijó `_dibujar_bloque()` para `water.png` (102 de alto, cara en
33 → offset 18). Con el hielo (176 de alto, cara en 96) la cara queda
`-88 + 18 + 96 = 26 px` por debajo del centro de la casilla (22 px en
pantalla con `SY`). Simulado con la aritmética del juego: el hielo se ve
hundido respecto a las losas vecinas.

**Comprobar:** Test 2, congelar una casilla de agua junto a hierba; mirar si
la cara del hielo queda más baja que la de la hierba.

**Arreglo recomendado (Pipeline):** entregar los tres hielos con el mismo
lienzo que los bloques, 128×102 con la cara en y=33, en
`export_godot/terrain/bosque_01/sprites/blocks/water_frozen_1..3.png`
(donde `ASSETS_PENDIENTES.md` §2 dice que van). El Juego solo cambia la
ruta en `nivel_base._agua()`. *Por qué así y no corrigiendo el offset en
`water_block.gd`:* el bloque dejaría de saber de píxeles, que es la gracia
del contrato; si cada textura trae su cara en un sitio, cada script
necesita una tabla.

### 1.2 El bloque de tierra creado por hechizo no encaja en la rejilla — **[Godot]** · Juego + Pipeline

`EarthBlock.tscn` dibuja `art/earth.png` tal cual: sin `scale (SX, SY)`,
sin `offset`, y con dos `RectangleShape2D` de 64×64 (justo lo que
`iso_grid.gd` explica que no vale). Resultado esperado: un bloque un 10 %
más ancho que la casilla (128 frente a 116), con la cara a ras de suelo
(+4 px) y los costados colgando 71 px sobre la casilla de delante.

**Comprobar:** TestJugabilidad, lanzar tierra sobre suelo neutro al lado
de un bloque de piedra del mapa; comparar anchos y bordes.

**Arreglo (Juego, `earth_builder.gd` o `EarthBlock.tscn`):** tras
instanciar, hacer lo mismo que `nivel_base._dibujar_bloque()`:
`Visual.scale = (SX, SY)`, `Visual.offset = (0, alto*0.5 - cara_y)`, y
cambiar las dos formas por `IsoGrid.diamond()`. Mientras `earth.png` siga
siendo el de `art/`, `cara_y = 92`; cuando llegue el bloque del pipeline
(`earth_stepping_stone`, §2 de la lista), `cara_y = 33` y se quita la
constante.

### 1.3 Los empujables son otra familia de cubos · Pipeline

`empujable_hielo/tierra.png` son cubos completos (costado igual de alto que
la cara) pintados con luz direccional; a 0.5 miden 100 px de ancho y su
costado ~40 px, frente a los 59 px de costado del terreno. Al lado de un
bloque de piedra del mapa se leen como de otro juego. Ver §3.

### 1.4 Los props del pipeline llegan pequeños y el juego los infla · Pipeline

`PROP_DATOS` en `nivel_base.gd` escala cada prop ×1.2–1.6 (`fern` 38×32 →
×1.4). Ampliar un raster emborrona justo lo que está delante del jugador,
mientras las losas son nítidas. **Pedir al Pipeline:** renderizar los props
al tamaño final (o al doble, para que el Juego los reduzca a 0.5 como el
resto de `art/`); el Juego deja `PROP_DATOS` a 1.0. Cambio de contrato →
diario.

### 1.5 `terrain/bosque_01/meta.json` no cumple su propio contrato · Pipeline

`CONTRATO_GODOT.md` dice "terreno: `tile_px`, `variantes`"; el meta lleva
`tile_px` pero no `variantes` (ni la lista de bloques) y `arboles:
["tree_ghibli_01"]` no coincide con los 12 tipos de `sprites/trees/`. El
Juego hoy lo ignora (`ARBOLES` y los nombres de bloque están a mano en
`nivel_base.gd`), que es justo lo que el contrato quería evitar.

---

## 2. Animaciones

### 2.1 La maga muerta se levanta — **[Godot]** · Pipeline (`ms_atlas.gd`)

Mientras no exista `shot_in_the_back_and_fall`, `MsAtlas._clip_muerte()`
usa `hit_reaction_to_waist` entero. Medido: la figura va de 134 px → 96 px
(se dobla) → **134 px (se incorpora)**. Como `player.gd` espera a que
acabe el clip (12 fotogramas / 12 fps + 0,35 s), "HAS MUERTO" sale con la
maga de pie.

**Comprobar:** dejarse matar por el guerrero en Mundo.

**Arreglo mínimo (Pipeline, una línea en `frames_heroe()`):** recortar el
clip al punto más bajo mientras no llegue el bueno:
`"death": [_clip_muerte(), 0, 5, 0.0]` cuando `_clip_muerte()` devuelva
`hit_reaction_to_waist`. El fotograma 5 es el mínimo (96 px) y la
animación no hace bucle, así que se queda doblada. Y procesar
`shot_in_the_back_and_fall` (fase 1.5 del plan).

### 2.2 El guerrero tiene clip de muerte exportado y no se usa · Juego (+ Pipeline)

> **Hecho 5/10 (copia `paranda`, Pipeline):** `_die()` del guerrero y del arquero piden `anim_orden = "death"`, dejan de hacer daño y se desvanecen al segundo (`docs/CAMBIOS_JUEGO_PENDIENTES.md` §2). Falta comprobar en Mundo.

`goblin_warrior/meta.json` lista `shot_and_fall_backward` (12 fotogramas,
sin bucle, acaba tumbado: 76 px → 50 px). `goblin_guerrero._die()` hace
`queue_free()` al instante y `ASSETS_PENDIENTES.md` §1 sigue pidiendo
"death" para el guerrero. Es un cruce entre contextos: el Pipeline ya lo
entregó, el Juego no se enteró.

**Arreglo (Juego, `goblin_guerrero.gd`):** en `_die()`:
`anim_orden = "shot_and_fall_backward"`, `set_physics_process(false)`,
`monitoring = false`, `combate.morir()`, y `queue_free()` tras
`await get_tree().create_timer(0.95).timeout` con un fundido de `modulate:a`.

**Lo que falta del otro lado (Pipeline, `ms_actor.gd`):** `_guion_ia()`
reproduce las órdenes con `jugar(nombre, true, "idle")`, así que al acabar
el cadáver volvería a idle. Haría falta que `jugar()` acepte `volver = ""`
= quedarse en el último fotograma. Hasta entonces, el `queue_free` a 0,95 s
(antes del fotograma 12) lo disimula. Pedirlo en el diario.

### 2.3 El golpe recibido del goblin dura 1 s y patina — **[Godot]** · Juego

> **Hecho 5/10 (copia `paranda`, Pipeline):** un golpe pone `interrupcion = 0,3 s` en los dos goblins (§3 del mismo documento). Si el combate se siente pegajoso, bajar a 0,2.

`anim_orden = "hit"` reproduce `hit_reaction` entero (12/12 = 1 s) y
mientras `_una_vez` está activo `MsActor` no cambia a walk/run; pero
`interrupcion` solo la pone el viento (`combate_comun.gd:139`), así que el
cuerpo sigue andando y atacando con la pose de golpe. Además el clip casi
no se mueve (71–76 px de alto): no se lee como golpe. El héroe lo resuelve
recortando a los fotogramas 2–5 a 20 fps (0,2 s).

**Comprobar:** pegar con agua a un guerrero que corre hacia ti.

**Arreglo (Juego):** en `receive_damage()` de guerrero y arquero,
`interrupcion = maxf(interrupcion, 0.3)`. **Y pedir al Pipeline** el mismo
recorte que el héroe en `_guion_ia()` (`"hit"` → fotogramas 2–5, 20 fps), o
un clip `hit` de 4–6 fotogramas.

### 2.4 El hachazo conecta antes de que baje el hacha — **[Godot]** · Juego

`goblin_guerrero._atacar()` aplica el daño a los 0,25 s ("a mitad de la
animación", dice el comentario) pero el clip dura 1,0 s: el daño cae en el
fotograma 3 con el hacha aún arriba. Lo mismo con el arquero: la flecha
sale al empezar `archery_shot_001`, con el arco sin tensar.

**Comprobar:** cuál fotograma de `charged_axe_chop` / `left_slash` /
`archery_shot_001` es el contacto (mirar `review/` o pausar con F6).
Después: subir el timer a ese fotograma / 12 fps, o pedir al Pipeline
ataques a 20–24 fps (0,5 s), que es lo que pide un enemigo cuerpo a cuerpo.

### 2.5 `bookwrite` no se lee como lanzar · Juego

`"write"` (elementos estáticos: pilar, solo elemento) usa `bookwrite`,
que apenas cambia (126–130 px): a la distancia del juego parece que la
maga no hace nada. Opciones: usar `mage_soell_cast_001` para estáticos
también, o pedir un clip corto de "golpear el suelo con el libro".

### 2.6 Datos del `meta.json` que chirrían (no rompen nada) · Pipeline

- `goblin_archer`: `altura_unidades 1.7` (la del héroe) y `goblin_warrior`
  `0.76`; renderizados miden lo mismo (75–82 px). El dato está mal, no el
  sprite.
- Los goblins están en `characters/` como `tipo: character`, sin
  `hitbox_px` ni clips `attack/hit/death`, que es lo que
  `CONTRATO_GODOT.md` exige a `enemies/`.
- `mage_soell_cast_001/002`: errata (`spell`). Cambiarla rompe
  `ms_atlas.gd`, así que o se queda o se cambia en los dos sitios a la vez.
- El arquero no tiene muerte; `face_punch_reaction` como golpe se mueve
  4 px. Ya está en la lista; esto solo confirma que hace falta.

### 2.7 Sin clip (conocido): voltereta y salto

`roll_dodge_1` está en el inbox. Mientras, la voltereta muestra `walk`.

---

## 3. Coherencia de estilo: tres familias en pantalla

Montaje a escala de juego (`estilos.png`, adjunto en la conversación):

1. **Pipeline** (bloques, props, árboles): render 3D de luz plana, poco
   detalle, color saturado. Es la dirección que fija `ARTE.md` §6.
2. **`art/` nuevo** (hielo, `earth`, empujables, tótems, seto, tronco,
   puesto, baldosa, placa): pintado con mucho detalle y **luz direccional
   marcada** (justo lo que §6 prohíbe en losas, porque la repetición se ve
   antes que el dibujo). Al lado de un bloque del pipeline se nota el
   cambio de mano.
3. **Duplicados**: hay dos fogatas (`props/campfire.png` del pipeline y
   `art/fogata_*.png`), dos tierras (`blocks/dirt.png` y `art/earth.png`) y
   dos hierbas (`blocks/grass.png` y `art/grass*.png`).

**Propuesta de regla** (para `ARTE.md`, Pipeline, y `CONTEXTO.md`, Pablo):
*todo lo que pisa la rejilla sale del pipeline con la misma luz y el mismo
lienzo*; `art/` queda solo para interfaz y para lo que no tiene sustituto
aún. Orden sugerido de sustitución, por lo que más se ve: hielo (1.1) →
tierra creada (1.2) → empujables → tótems/seto/tronco → puesto/baldosa.
Cada sustitución borra su duplicado de `art/` para que no vuelva a
cargarse por error.

---

## 4. Lista para comprobar en Godot (Pablo, 10 min)

| # | Escena | Qué hacer | Qué mirar |
|---|---|---|---|
| 1.1 | Test2 | congelar agua junto a hierba | ¿la cara del hielo queda más baja? |
| 1.2 | TestJugabilidad | tierra sobre suelo neutro junto a piedra | ¿más ancho? ¿costados sobre la casilla de delante? |
| 2.1 | Mundo | morir por el guerrero | ¿la maga está de pie cuando sale HAS MUERTO? |
| 2.3 | Mundo | agua a un guerrero que corre | ¿sigue avanzando con la pose de golpe? |
| 2.4 | Mundo | dejar que ataque | ¿el daño llega con el hacha arriba? |
| 2.5 | VfxLab | lanzar solo un elemento | ¿se ve algún gesto? |

Con las respuestas se marca aquí qué se confirma y se pasa a `PLAN_ARREGLOS.md`.

---

## 5. Qué le toca a cada uno (resumen)

- **Juego**: 1.2 (EarthBlock), 2.2 (`_die` del guerrero), 2.3
  (`interrupcion`), 2.4 (timer del hachazo), 2.5 (clip de estáticos).
- **Pipeline**: 1.1 (hielos 128×102), 1.4 (props a tamaño), 1.5
  (`meta.json` de terreno), 2.1 (recorte de muerte provisional), 2.2
  (`jugar(..., volver="")`), 2.3 (recorte del hit en `_guion_ia`), 2.6,
  y la regla de §3 en `ARTE.md`.
- **Pablo**: lista §4; añadir `docs/QA_ARTE.md` a `PROPIETARIOS.md`
  (lo posee el contexto Juego/QA); decidir la regla de §3 en `CONTEXTO.md`.
