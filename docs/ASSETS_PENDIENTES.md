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
