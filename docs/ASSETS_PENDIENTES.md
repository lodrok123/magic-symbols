# Assets pendientes (2D y 3D)

Siguiendo el **pipeline de sprites isométricos**:
- **3D (Meshy → GLB)**: a `pipeline/inbox/<id>/` con su `asset.json` (id en minúsculas con prefijo:
  `character_*`, `enemy_*`, `prop_*`, `tree_*`). `PROCESAR_PERSONAJES.cmd` lo renderiza en 8 direcciones
  (E, SE, S, SW, W, NW, N, NE) y `EXPORTAR_GODOT.cmd` lo deja en `export_godot/<tipo>/<id>/` con
  `meta.json` (atlas por animación, `frame_px`, `ancla_suelo_px`, `offset_visual_px`). Godot lo lee con
  `MsAtlas`/`MsActor` sin tocar código.
- **Bloques / cubos**: losa isométrica de **128 x 64** (`tile_px`), la cara de arriba centrada en la fila
  **y = 33** del sprite; los costados hacia abajo. Van en `export_godot/terrain/bosque_01/sprites/blocks/`.
- **Props 2D sueltos** (`art/`): dibujados a **2x** (en juego a escala 0.5), anclados en el **centro de la
  base** (se apunta el ancla en píxeles del PNG, como `ANCLA_PUESTO = (175,175)`). Si tienen estados, un
  PNG por estado con el MISMO lienzo y ancla (`_sano` / `_chamuscado`, `_off` / `_on`, `_1_` / `_2_` / `_3_`).
- Colores de elemento: los de `docs/ARTE.md` §1 (fuego #F2551E, agua #2A9DFB, hielo #5ECFF5,
  tierra #C8875A, viento #8FD46A, rayo #F2C63C).

## 0. Urgente (ya está en el inbox)
| id | Qué falta |
|---|---|
| `hero` → clip `shot_in_the_back_and_fall` | Procesar el GLB (PROCESAR_PERSONAJES + EXPORTAR_GODOT). El código ya lo busca; hasta entonces usa `hit_reaction_to_waist`. Una vez, sin bucle. |
| `hero` → `roll_dodge_1`, `swim_forward` | También en el inbox; preparados para esquivar y nadar (sin código todavía). **En 3D ya están** en `chibi_elf.glb` (`RollDodge`, `SwimForward`, `Readandwrite`) y `Pj3D.validar()` los exige |

## 1. Personajes y enemigos (3D → 8 direcciones)
| id | Animaciones | Para qué |
|---|---|---|
| `character_alchemist` (o `master_elf`) | idle, talk_with_left_hand_raised, walk | El alquimista del puesto (ahora es el guardabosques teñido de morado) |
| `character_shopkeeper_*` | idle, talk | Más tenderos para futuros puestos |
| `enemy_goblin_warrior` | **hit** (4–6 fotogramas, que se lea), attack a 20–24 fps | La **muerte ya existe**: `shot_and_fall_backward`. El Juego la pide con `anim_orden = "death"` y `MsActor` la deja tumbada (4/10). El golpe actual es `hit_reaction` recortado a 2–5, casi no se mueve |
| `enemy_goblin_archer` | **hit**, **death**, shoot | Sigue sin muerte; con `anim_orden = "death"` no pasa nada hasta que exista el clip |
| `enemy_goblin_frost` (dummy) | idle, hit, death | Ahora es el arquero teñido de azul |
| `hero` | `drink_potion`, `push` (empujar bloque), `pick_up` corto | Q, bloques empujables y recolectar decorado |

### Clips mínimos por tipo de personaje (3D, tarea 4.8)
`Pj3D.validar()` los comprueba al cargar cada GLB y avisa por consola (WARNING, una vez por personaje): que cada clip
exista (por nombre, ver `Pj3D.SINONIMOS`; un personaje puede declarar otro nombre en `Pj3D.CLIPS_DE`), que los clips
"en su sitio" no arrastren la cadera más de 0,35 alturas de cadera, y que el modelo mida 0,5–4 unidades tal como viene
(~1,7: si no, es cm contra m). Esta tabla manda; el código la copia en `Pj3D.MINIMOS`.
| tipo (ids) | clips mínimos (rol → nombre habitual en el GLB) | en su sitio |
|---|---|---|
| héroe (`chibi_elf*`, `chibi_test`) | idle, walk, run, cast, hit, death, roll, leer, swim → `Idle`, `Walking`, `Running`, `MageSoellCast003`, `FacePunchReaction`, `Dead`, `RollDodge`, `Readandwrite`, `SwimForward` | todos menos death, roll y swim |
| goblin (`goblin_*`) | idle, walk, attack, hit, death → `Idle`, `Walking`, `LeftSlash`, `SlapReaction`, `Die` | todos menos death |
| arquero (`goblin_archer*`) | los del goblin + walk_back (hoy `Walk002`, que en el 2D es `Walk_Backward_with_Bow`) | todos menos death |
| NPC (librera, alquimista...) | idle, walk, talk → `Idle`, `Walking`, `StandTalkingAngry` | todos |
Estado a 6/10 con los GLB actuales: **héroe, goblin guerrero/espadachín y librera, sin avisos**. Decisiones que salieron de medir
los clips (desplazamiento de cadera en alturas de cadera): el `HitReaction` del goblin arrastra 1,25 y su `Die` 1,5 (la
muerte sí puede), así que el goblin usa `SlapReaction` (0,15) para `hit`; la elfa no tiene `hit_reaction` y usa
`FacePunchReaction` (0,30); su `Walk002` arrastra 1,2 (no se usa; el arquero sí lo necesita como `walk_back`, ver 4.9).
**Pendiente de arte (no hay clip coherente):** `hit` y `death` del arquero (sin GLB todavía); `aim`/`alert` del arquero;
un `death` de la elfa que no termine arrastrando la cadera 1,6 (hoy `Dead`, vale porque se tumba).

#### Clips de lanzar de la elfa por forma (4.6b)
Tabla `Pj3D.ANIM_CAST` (el modo lanzar de `DISENO_FUTURO` §0b la usa): proyectil → `MageSoellCast003` · corro →
`ChargedGroundSlam` (manos al suelo) · columna → `ChargedSpellCast002` (brazos alzados) · muro → `MageSoellCast002`
(brazos abiertos). Sin clip, `Readandwrite`. **Si hay presupuesto de clips:** un lanzamiento horizontal de un solo brazo
(para la flecha) y un barrido lateral (para el muro) leerían mejor que los actuales, que son gestos genéricos de mago.

## 2. Bloques (128 x 64, cara arriba en y=33)
| Archivo | Estados | Para qué |
|---|---|---|
| `water_frozen_path` | **entregado 4/10** como `terrain/bosque_01/sprites/blocks/water_frozen_1_nevado.png`, `_2_escarcha`, `_3_claro` (128×102, cara en y=36, la misma fila que `water.png`; recorte sin pérdida de `art/hielo_*`). **Ruta cambiada en `nivel_base._agua()` el 5/10 (copia `paranda`).** Queda borrar `art/hielo_1..3` y sus `.import` con Godot cerrado | Camino helado |
| `earth_stepping_stone` | 1 | Pasadero de tierra sobre agua (ahora es el bloque genérico) |
| `ash` / `burnt_grass` | 1 | Hierba quemada |
| `wet_ground` | 1 | Suelo mojado (ahora es un tinte) |
| `plate_weight` | `_off`, `_on` | La placa de PESO (letra K); ahora es un óvalo dibujado |
| `plate_trial_<elemento>` x6 | `_off`, `_on` | Losas de las cámaras del Test 2 con el símbolo del elemento |

## 3. Props 2D (a 2x, ancla en la base)
| Archivo | Estados | Para qué |
|---|---|---|
| `puesto_alquimista.png` | 1 | Mostrador con frascos y alambique (ahora se reutiliza `puesto.png`) |
| `puerta_pruebas.png` | cerrada / abierta, 6 runas que se encienden | Puerta norte del Test 2 (ahora es piedra) |
| `antorcha` | apagada / encendida | Ahora es un tocón |
| `cartel_camara_<elemento>` x6 | 1 | Sustituye a los rótulos de texto del Test 2 |
| `bush_berry_vacio`, `lavender_cortada`, `fern_cortado`, `flowers_cortadas`, `rocks_vacio` | 1 cada uno | Cómo queda el decorado tras recogerlo (ahora se oscurece) |
| `seta`, `flor_luna`, `raiz` (plantas reactivas) | sana / recogida | Ahora se dibujan con código |
| `totem_hielo`, `totem_tierra`, `totem_viento` | `_off`, `_on` | Completar la familia (hay rayo, fuego y agua) |

## 4. Iconos de interfaz (64 x 64, fondo transparente)
Oro, poción, y uno por objeto de `objetos.gd`: seta (+ electrificada, asada, helada, empapada), esporas,
flor de luna (+ ardiente, rocío, cargada, escarcha), pétalos, raíz (+ carbonizada, hinchada, magnética),
cristal de tierra, **lavanda, bayas, helecho, flor silvestre, piedra**. Ahora se dibujan con formas.
Además: marco de hueco de mochila (normal / bloqueado / resaltado) y barra de vida de enemigo (marco + relleno).

## 5. VFX / partículas
Copos de congelación, chispa de cortocircuito en agua, polvo al crear tierra, humo de vela apagada,
hojas al recolectar. Hoja de 8 fotogramas por efecto, 64 x 64.

## 6. Sonido
Los de `audio/` ya cubren hechizos, pasos, puertas y libro. Faltan (ahora se sintetizan en `sonidos.gd`):
abrir mochila, moneda, beber poción, comprar, recoger planta, prueba superada, golpe recibido corto.

## 7. Auditoría de modelos y texturas (6/10 · Pipeline)

Pedida por Pablo: «hay texturas muy low poly»; tabla de todo y lista para re-renderizar. **324 filas** (GLB de personajes, equipo, bibliotecas de Meshy, piezas sueltas, texturas de suelo y sprites de VFX) en `docs/auditoria_texturas.tsv` (TSV a propósito: Godot importa los `.csv` como traducciones). Medido a mano con script (sin motor): triángulos por pieza, tamaño de la textura, **densidad de texel** (px de textura por unidad de mundo) y arista mediana de triángulo en pantalla.

**Criterio.** Un metro mide 180 px con el zoom inicial (6) y 540 px con el mínimo (2). Arista mediana en pantalla a zoom 6: ≤ 12 px bien · 12–25 regular · > 25 malo (se ve facetado/«low poly»). Densidad de texel: ≥ 512 px/u bien · 180–512 regular · < 180 malo (borroso al acercar). Las piezas prismáticas (cajas, vallas, placas) aguantan pocos triángulos: ahí solo cuenta la textura.

**Causa raíz (la misma en casi todo).** Meshy da ~15 000 triángulos y UNA textura de 2048² por generación, y las láminas (bosque, objetos, magia, mercado, arboles_2) lo reparten entre ~13 piezas: cada una recibe ~1 000 triángulos y ~1/13 de la textura. Un árbol de 4,2 u con 3 700 triángulos y 91 px/u se ve poligonal y borroso aunque «tenga» textura 2048. **Se arregla generando las piezas SUELTAS** (una por generación: todo el presupuesto y toda la textura para ella; `meshy/REGENERAR.md` §1, `INTEGRAR_PIEZAS.cmd` las deja en `meshy/piezas/<id>.glb` y `prueba_test2.gd` las prefiere a la lámina). Los personajes no tienen el problema (31 000 triángulos, 480–630 px/u).

### Resumen (solo lo que está en uso)

| tipo | ok | regular | malo |
|---|---|---|---|
| glb_atlas | 26 | 0 | 0 |
| glb_equipo | 6 | 0 | 0 |
| glb_personaje | 2 | 1 | 0 |
| glb_pieza | 1 | 13 | 20 |
| sprite_vfx | 27 | 2 | 0 |
| textura_suelo | 5 | 3 | 0 |

### A re-renderizar YA (malas y a la vista)

Orden = lo que más se ve: árboles y rocas (decenas de copias), luego los objetos de juego y el decorado de la plaza. Cada una se pide **suelta**, 1 pieza por generación; presupuesto orientativo al pedirla: 6 000–10 000 triángulos para árboles/arcos/puesto, 2 500–4 000 para objetos medianos, 1 000–2 000 para pequeños; textura 2048².

| pieza | biblioteca | triángulos | px/u | arista a zoom 6 | veredicto |
|---|---|---|---|---|---|
| `arbol_redondo_2` | arboles_2.glb | 3701 | 91 | 50 px | malo |
| `pino_2` | arboles_2.glb | 1780 | 89 | 50 px | malo |
| `arbusto` | bosque.glb | 700 | 142 | 28 px | malo |
| `arbusto_flores` | bosque.glb | 812 | 147 | 25 px | malo |
| `roca_grande` | bosque.glb | 814 | 104 | 35 px | malo |
| `tocon` | bosque.glb | 274 | 113 | 35 px | malo |
| `tronco` | bosque.glb | 430 | 171 | 18 px | malo |
| `totem_runico` | objetos.glb | 1054 | 165 | 25 px | malo |
| `brasero` | objetos.glb | 769 | 157 | 28 px | malo |
| `fogata` | objetos.glb | 462 | 151 | 25 px | malo |
| `puesto_mercado` | mercado.glb | 6404 | 131 | 17 px | malo |
| `arco_ruina` | mercado.glb | 3978 | 86 | 22 px | malo |
| `portal_salida` | magia.glb | 926 | 93 | 54 px | malo |
| `puente` | magia.glb | 747 | 114 | 16 px | malo |
| `pilar` | magia.glb | 618 | 104 | — | malo |
| `barril` | objetos.glb | 278 | 156 | 32 px | malo |
| `juncos` | objetos.glb | 368 | 164 | 19 px | malo |
| `valla` | bosque.glb | 248 | 161 | — | malo |
| `seta_reactiva` | magia.glb | 566 | 162 | 17 px | malo |
| `placa_peso` | objetos.glb | 114 | 118 | — | malo |

### Regulares (después, si hay presupuesto de Meshy)

| pieza | biblioteca | triángulos | px/u | arista a zoom 6 | veredicto |
|---|---|---|---|---|---|
| `piedras` | bosque.glb | 304 | 204 | 14 px | regular |
| `setas` | bosque.glb | 500 | 335 | 6 px | regular |
| `dummy` | magia.glb | 758 | 257 | — | regular |
| `flor_reactiva` | magia.glb | 1118 | 241 | 16 px | regular |
| `raiz_reactiva` | magia.glb | 1474 | 339 | 11 px | regular |
| `pocion` | magia.glb | 706 | 483 | 10 px | regular |
| `roca_cristal` | mercado.glb | 3450 | 328 | 8 px | regular |
| `caja_pequena` | objetos.glb | 210 | 208 | — | regular |
| `cofre` | objetos.glb | 260 | 221 | 23 px | regular |
| `caja` | objetos.glb | 217 | 189 | — | regular |
| `baldosa_guardado` | piezas/lamina_1.glb | 5011 | 362 | — | regular |
| `pasadero` | piezas/lamina_1.glb | 2365 | 266 | 11 px | regular |
| `seto_seco` | piezas/seto_seco.glb | 10360 | 265 | 13 px | regular |

### Texturas de suelo y otros

- `dirt_arriba`, `path_arriba`, `water_arriba` (1024² sobre una casilla de 2,3 u = 445 px/u, regular; **Pablo las aprobó**): si se renuevan, 2048² (≈ 890 px/u) mantiene el aspecto y sube a «bien». No urgente.
- `chibi_elf.glb` sale «regular» (480 px/u) y el resto de personajes «bien»: sin acción.
- Sprites de `vfx/` (`llama`, `llama_pequena` tocan el borde del lienzo): quedan fuera con el paso a partículas 3D (ver DIARIO).

### Retiradas / sin uso (no hace falta rehacerlas)

Ya sustituidas por una versión mejor y puestas en reserva: `arbol_redondo`, `pino`, `cartel`, `seto_seco`, `pasadero`, `arco_puerta`, `puesto`, `baldosa_guardado`. Se pueden borrar de las láminas cuando se quiera liberar memoria (cada lámina pesa 5–7 MB de GLB + 2 JPG de 2–3 MB).

### Personajes nuevos sin GLB

`alchemist_elf` y `goblin_archer_chibi` solo existen como `character.json` + atlas 2D (`export_godot/characters/`); **no hay `*_master.glb` en el repo** (el informe del ensamblado apunta a `C:\Users\paranda\Documents\magic-symbols\pipeline\characters\<id>\<id>_master.glb`, otra carpeta). Hasta que se copien a `poc_25d/` el 3D usa el sustituto (librera / guerrero). `COPIAR_MODELOS.cmd` ya los incluye.


## 8. Plan de assets «bosque» (5.12 · Pipeline · 6/10)

Para un nivel más ambicioso que el Test 2. Reglas comunes: **textura ≤ 1024²**, un solo material por GLB, ancla en la base (pivote en el suelo), sin animación salvo donde se indica, estilo pastel/chibi del resto. «Pantalla» = alto aproximado en pantalla con la cámara ortográfica actual (casilla = 2,3 u). Tope de triángulos pensado para UHD 620: se prefiere lote (`lamina`) de varias piezas por GLB. Las letras son las del plano de `prueba_test2.gd._mapa()`; las marcadas **(nueva)** no existen aún y las define Juego al montar el nivel.

### Decorado (lámina GLB por grupo)

| Asset | Pantalla | Tope tris | Letra | Notas |
|---|---|---|---|---|
| Árbol grande ×3 variantes (redondo, pino, retorcido) | 3,5–4,5 u | 1500 | `#` (pared de bosque, variante por semilla) | copa opaca, tronco visible; ya existe `arbol_redondo` como base |
| Arbusto ×2 | 0,7 u | 400 | `h` (nueva variante) | relleno no bloqueante |
| Roca ×2 tamaños (pequeña 0,6 u, grande 1,4 u) | 0,6 / 1,4 u | 500 / 900 | `r` | la grande bloquea |
| Tocón | 0,5 u | 300 | `r` (nueva variante) | |
| Seto | 1 casilla de largo, 0,9 u | 600 | `h` | sustituye al `seto_seco` retirado |
| Telaraña | 1 casilla, plano | 150 | **(nueva) `w`** | plano con alfa; ralentiza al pasar (decisión de Juego) |
| Puente de madera | 1×3 casillas | 900 | `b` sobre `~` | se cruza de E a O |
| Pasarela (tablones) | 1×2 casillas | 600 | `b` | zona pantanosa |
| Cabaña / puesto | 2×2 casillas, 3 u | 2500 | `M` | ya hay `puesto_mercado`; la cabaña es nueva (puerta hacia la cámara) |
| Tótem ×3 (rayo, agua, tierra) | 2 u | 800 | `T` | emisión que se enciende al activar (usa `Ocluso3D.poner_emision`) |
| Antorcha | 1,2 u | 250 | **(nueva) `i`** | luz con `OmniLight3D` solo cerca de la cámara |
| Fogata | 0,6 u | 400 | `F` | las llamas ya las pone `Vfx3D.fuego_fijo` |
| Nubes de tormenta | — | — | — | **ya hechas por código** (`Vfx3D.lanzar_forma("tormenta", …)`), no hay que encargarlas |
| Orilla de agua (esquina interior/exterior/recta) | 1 casilla | 300 c/u | `~` bordes | con mezcla a baldosa de hierba |
| Cascada pequeña | 1×2 casillas, 2 u | 700 | **(nueva) `c`** | agua con scroll UV (shader de agua existente) |
| Camino (recto, curva, cruce) | 1 casilla, plano | 100 c/u | `.` variante | extiende `path_arriba` |

### Personajes (mismos clips mínimos de 4.8 → §1)

| Personaje | Estado | Clips mínimos |
|---|---|---|
| Héroe | existe (`chibi_elf`) | idle, walk, run, cast, hit, death, roll, `readandwrite`, `swim_forward` |
| Goblin guerrero | existe | idle, walk, attack, hit, death |
| Goblin arquero | existe (`goblin_archer_chibi`); falta clip de arco visible | idle, walk, attack, hit, death + `walk_back` |
| Guardabosques | **nuevo** | idle, talk, walk |
| Librera | existe (`bookseller_chibi`) | idle, talk |
| Alquimista | existe (`alchemist_elf`) | idle, talk, walk |

**Prioridad Meshy:** 1) árboles ×3 y roca grande (cubren el 70 % del plano), 2) puente + pasarela + orilla, 3) tótems, 4) guardabosques, 5) resto.
