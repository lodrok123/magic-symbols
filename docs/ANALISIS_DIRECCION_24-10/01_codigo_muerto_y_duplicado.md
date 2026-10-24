# Código muerto y duplicación — Magic Symbols (worktree `proyecto-analisis-profundo-bf47f8`, 24/10)

Análisis de SOLO LECTURA. No se ha tocado ningún archivo del repo. Todo lo que aparece aquí es refactor que no cambia lo que hace el juego. Donde quitar algo podría cambiar un comportamiento (aunque sea en una prueba), se avisa.

## 0. Método y límites (para que se pueda repetir)

- **Inventario**: 582 archivos `.gd/.tscn/.tres` fuera de `.godot/`. En las carpetas de juego hay 4 025 funciones `func` (nucleo 25 scripts y 6 175 líneas, magia 6 y 6 941, mundo 14 y 4 955, objetos 29 y 8 269, enemigos 4 y 2 673, jugador 10 y 4 992, escenas 9 y 6 070, presentacion 74 y 33 713, laboratorios 18 y 9 072). Herramientas: 239 scripts y 43 741 líneas.
- **Referencias**: para cada `func nombre(` se cuentan las apariciones de `nombre` como palabra suelta en todo `.gd/.tscn/.tres`, sin comentarios (`#…`, `##…`) y sin la propia definición. La cuenta incluye `"nombre"`, `&"nombre"`, `.nombre`, `call("nombre")`, `has_method("nombre")`, `Callable(…,"nombre")` y conexiones de señal en `.tscn`. El conteo se hace por separado para «juego» (todo menos `herramientas/`) y para `herramientas/`. Los scripts están en el scratchpad (`funcs.ps1`, `consts.ps1`, `dups.ps1`, `near.ps1`, con salida en `funcs.csv`, `consts.csv`, `dups.txt`, `near.txt`).
- **Llamadas dinámicas que se han revisado a mano**:
  - Las tablas `Puzle3D.ACCIONES` y `CONDICIONES` (`escenas/puzle.gd:232-285`) nombran métodos y propiedades como cadenas, así que cuentan como referencia.
  - `PiezaPuzle3D` llama a `call("_c_"+familia)` y `call("_e_"+familia, …)` (`presentacion/pieza_puzle_3d.gd:238` y `:381`): las 24 funciones `_c_*`/`_e_*` están vivas.
  - `reacciones_agua_3d.gd:31` hace `efecto.call(nombre…)`.
  - Los contratos por duck typing (on_spell_hit, spell_reacts, carried_element, nivel_altura, punto_activacion…) y las retrollamadas del motor (`_ready`, `_draw`, `_gui_input`, `_init`, `_notification`, `_validate_property`, `_process_modification[_with_delta]`…) se excluyen.
- **Límite conocido**: si un nombre se define en dos archivos, una llamada a uno hace que el otro también cuente como «usado». Por eso se hizo una segunda pasada a mano sobre los nombres definidos más de una vez con pocas referencias. Ahí aparecieron, por ejemplo, la cadena `Campo` de `Lanzador3D` y `spellcaster.gd`.

## 1. Resumen por impacto (de mayor a menor)

| # | Qué | Clase | Líneas / tamaño que se quitan | Riesgo que se evita |
|---|---|---|---|---|
| 1 | `presentacion/grimorio/` completo (prototipo `GrimorioUI` + 3 GLB Meshy + 6 láminas) | a | 245 líneas de código y 42,1 MB en 40 archivos de git | Importación lenta, repo pesado |
| 2 | Copias `*_copia_2026*` de `mundo/datos_nivel` (5 `.tscn` y 2 mapas `.txt`) | a | 545 KB, unas 9 400 líneas | Abrir una copia vieja por error en el editor |
| 3 | Texturas `Meshy_AI_Wolfwood_*` en `mundo/datos_nivel` (6 jpg y 2 `.glb.import` sin `.glb`) | a | 14,1 MB | Importaciones huérfanas |
| 4 | `magia/spellcaster.gd` (el lanzador 2D) | b (solo 2 herramientas) | 986 líneas, más su cadena en `SpellRecipe`/`Sigils` (unas 230 más) | Dos copias del reconocedor: 331 de las 384 líneas útiles de `grimorio.gd` están repetidas en él |
| 5 | La barrera-burbuja antigua `Lanzador3D.Campo` y todo lo que cuelga de ella | b (solo `prueba_barrera.gd`) | unas 490 líneas de `lanzador_3d.gd` | En el juego `_barrera_activa` vale siempre `null`, así que `absorber_golpe`, `burbuja_contiene` y `burbuja_recibe` devuelven siempre `false` aunque se llamen en cada golpe |
| 6 | `laboratorios/lab_grandmaster_3d.gd` | a | 477 líneas | `LabGrandmaster3D.tscn` ya carga `lab_humanoide_3d.gd`: este archivo no lo abre nadie |
| 7 | `escenas/PruebaJugabilidadBosque.tscn`, `PruebaJugabilidadBosque_1.tscn` y `PruebaNivelBosque.tscn` | a (salvo que Pablo las abra a mano con F6) | 1 672 líneas, 96 KB | Escenas sin referencia ni por ruta ni por uid |
| 8 | `mundo/vista_suelo_editor.gd` (`@tool`) | a | 151 líneas | Su cabecera dice que va dentro de `Nivel_Bosque.tscn`, pero ningún `.tscn` tiene ya el nodo `VistaSuelo` |
| 9 | Funciones sin ninguna referencia (sección 2.1) | a | 45 funciones, 387 líneas | |
| 10 | `SpellRecipe`: partes de la receta 2D (`_points`, `_spread_points`, `_fan`, `apply`…) | a/b | unas 170 de 290 líneas | La clase NO está muerta: `Receta3D` hereda de ella |
| 11 | Campos de sprites de `RuneData` (`vfx_sheet*`, `vfx_frames*`, `beam`, `orient_to_travel`, `setup_sprite`, `frames_for`) | a | unas 105 de 174 líneas, más los PNG que cargan los 9 `.tres` | |
| 12 | `Lanzador3D._barrido` y su cadena | a | 67 líneas | `prueba_activacion.gd` comprueba un camino que el juego no usa |
| 13 | Reenvíos «REENVÍO M1» de `Lanzador3D` hacia `Terreno3D` | a: 10 sin uso; el resto, recolocables | 39 líneas marcadas; 10 reenvíos muertos | Dos nombres para lo mismo |
| 14 | Funciones que solo usan las herramientas (sección 2.2) | b | 100 funciones, 678 líneas | Son ganchos de prueba: no se borran sin revisar la prueba que las usa |
| 15 | Constantes y variables sin lectura (sección 2.6) | a | 66 | |

Duplicación (Tarea 2), por impacto: (1) el armazón repetido de las 181 herramientas que no usan `escenario_base.gd`; (2) las reglas de nivel `bosque_01_3d` y `bosque_01_v01_3d` (280 líneas comunes), con el diálogo y la E repetidos en 5 niveles; (3) los 230 accesos a privados ajenos con `get("_x")`/`call("_x")` en código de juego, más 168 accesos directos `obj._x`; (4) la conversión celda↔mundo (17 constantes 2,3 en el juego y unas 70 en herramientas); (5) los emisores de partículas hechos a mano (unas 580 líneas en 12 funciones); (6) los laboratorios gemelos; (7) las letras del mapa, que se reparten entre tres tablas y 114 comparaciones sueltas.

---

## 2. Tarea 1 — Código muerto

### 2.1 Lo que ya nombra ARQUITECTURA.md «Pendiente»: comprobado

| Elemento | Archivo:línea | Resultado | Detalle |
|---|---|---|---|
| `magia/spellcaster.gd` | 986 líneas | **b**, no a | Lo cargan con `load()` `herramientas/captura_libro_bosque.gd:15` y `herramientas/prueba_receta_v2.gd:276`. En el juego no lo usa nada (ni ruta, ni uid, ni clase). 28 funciones son copia exacta o casi exacta de `magia/grimorio.gd` (ver 3.1). Al borrarlo hay que adaptar esas 2 herramientas o archivarlas |
| `RuneData` sprites | `nucleo/rune_data.gd:69-173` | **a** | `vfx_sheet`, `vfx_frames`, `vfx_sheet_mid/high`, `vfx_frames_mid/high`, `beam`, `orient_to_travel`, `VFX_COLUMNS`, `POWER_MID/HIGH`, `setup_sprite` (24 líneas) y `frames_for` (6): 0 lecturas en `.gd`. Solo los rellenan 9 `.tres` (vfx_sheet ×9, beam ×35 entre `.tres` y `.tscn`). Si se quitan los `@export`, Godot ignora la propiedad sobrante del `.tres` y avisa; lo limpio es reguardar los `.tres` desde el editor (Godot cerrado → que lo haga Pablo) |
| `Lanzador3D._barrido` | `magia/lanzador_3d.gd:1415` (31 líneas) | **a** | 0 llamadas. Arrastra `_activacion_al_final` (`:1448`, 16 líneas; solo la llama `_barrido` y `herramientas/prueba_activacion.gd:58-71`), `_visual_en` (`:1488`, 9 líneas) y `_tiempo_de_viaje` (`:1477`, 11 líneas; sus 2 llamadas están dentro de `_barrido`). Total: 67 líneas |
| `Lanzador3D._una_ola` | `magia/lanzador_3d.gd:1409` (6 líneas) | **b** | Solo `herramientas/prueba_barrera.gd:51`. Es la única puerta a la barrera antigua (ver 2.4) |
| Indicador de voltereta | `presentacion/ui/page_hud.gd:78-87` (10 líneas) | **a** | `has_method("roll_cooldown_fraction")`: ese método no existe en ningún `.gd`. El bloque no pinta nunca. El resto de `page_hud.gd` está vivo (`Lanzador3D` lo monta en `:557` y llama a `destello` en `:1056` y `:1101`) |
| `Estado.nuevo()` | `nucleo/estado.gd:52` | **b** | 0 llamadas en el juego y llamadas en 29 herramientas: es el «reinicio» de las pruebas. No es código muerto; conviene cambiarle el comentario |
| `nucleo/spell_recipe.gd` | 290 líneas | **vivo en parte** | `class Receta3D extends SpellRecipe` (`magia/lanzador_3d.gd:2420`). Detalle en 2.5 |
| `Sigils.GLIFOS_V2` | `nucleo/sigils.gd:343` (17 líneas) | **vivo, duplicado** | Lo leen `Sigils.aplicar_v2`, `cooldown_v2`, `repertorio_de` e `is_known` (`sigils.gd:267, 409, 477, 486`), `Receta3D.apply` (`lanzador_3d.gd:2443`), `Hechizo` (`hechizo.gd:485-486`), `spellbook.gd:1267`, `lab_recetas_3d.gd` (×7) y `lab_hechizos_3d.gd` (×9). No se puede borrar: se puede **derivar** de `GLIFOS` (ver 3.9) |
| `carried_element()` | 14 definiciones en `objetos/*.gd` | **vivo, sin efecto** | Solo lo llama `Lanzador3D.trazar` (`lanzador_3d.gd:1607-1608`). `trazar` sí lo usa `HechizoVivo` (`hechizo_vivo.gd:444`), pero no lee el elemento llevado (como dice ARQUITECTURA). Quitarlo es una decisión de diseño, no un refactor: déjalo hasta que Pablo decida |

### 2.2 (a) Funciones sin ninguna referencia (45 funciones, 387 líneas)

| Archivo:línea | Función | Líneas | Nota |
|---|---|---|---|
| `nucleo/spell_recipe.gd:154` | `_points` | 58 | Receta 2D (ver 2.5) |
| `nucleo/rune_data.gd:141` | `setup_sprite` | 24 | Sprites 2D |
| `mundo/pieza_3d.gd:238` | `cambiar_visual` | 19 | `@tool`, `static`. «Seta azul → quemada»: nadie la usa |
| `nucleo/spell_recipe.gd:262` | `_fan` | 19 | Receta 2D |
| `presentacion/prueba_test2.gd:2897` | `_poner_puente` | 18 | El comentario de `:3357` dice «se queda por si se vuelve a él» |
| `presentacion/runa_losa_3d.gd:25` | `en_losa` | 17 | La clase está viva (`pieza_3d.gd:82`); su fábrica estática no |
| `mundo/caminos_3d.gd:120` | `arista_ok` | 13 | |
| `jugador/pj_3d.gd:2009` | `apuntar_clip` | 12 | Junto con `soltar_apuntado`: API de apuntar que no usa nadie |
| `nucleo/playlog_3d.gd:403` | `_log_error` | 12 | Firma de `Logger._log_error`, pero `PlayLog` no se registra como Logger (0 `add_logger`); sería (c) si un día se hace |
| `presentacion/prueba_test2.gd:5039` | `imprimir_estado` | 12 | QA |
| `objetos/objetos_3d.gd:1161` | `ajustar_arroyo` | 10 | |
| `mundo/agua_sim_3d.gd:804` | `textura_eventos` | 9 | |
| `presentacion/prueba_test2.gd:5029` | `impactar_en` | 9 | «capturas y QA», pero ninguna herramienta la llama |
| `presentacion/hierba_3d.gd:540` | `set_viento` | 8 | |
| `presentacion/prueba_test2.gd:5725` | `_adyacente_letra` | 8 | |
| `nucleo/gesture_rectify.gd:61` | `rectificar_gesto` | 7 | |
| `nucleo/sfx.gd:257` | `for_element` | 7 | Recibe `Node2D`: resto del 2D |
| `jugador/pj_3d.gd:2022` | `soltar_apuntado` | 6 | |
| `nucleo/repertoire.gd:152` | `lock_element` | 6 | |
| `nucleo/rune_data.gd:168` | `frames_for` | 6 | Sprites 2D |
| `objetos/veta_pulso_3d.gd:185` | `color_en` | 6 | |
| `presentacion/agua_render_3d.gd:1359` | `poner_topes` | 6 | |
| `presentacion/pozo_cauce_3d.gd:118` | `borrar_humedad` | 6 | |
| `presentacion/prueba_test2.gd:5605` | `salpicadura_agua` | 6 | |
| `laboratorios/lab_vfx_3d.gd:298` | `poner_nota` | 5 | |
| `nucleo/gesture_library.gd:229` | `clear_all` | 5 | |
| `presentacion/prueba_test2.gd:5023` | `set_modo_hierba` | 5 | La tecla J no pasa por aquí |
| `presentacion/vfx_estado_3d.gd:676` | `_punto_interior` | 5 | |
| `enemigos/combate_3d.gd:1592` | `_factor_tamano` | 4 | |
| `jugador/brazo_libro_3d.gd:133` | `pose_de` | 4 | «para las pruebas», y ninguna la usa |
| `jugador/jugador_3d.gd:622` | `en_gesto` | 4 | |
| `nucleo/objetos.gd:141` | `duracion_aviso` | 4 | |
| `nucleo/tinta.gd:262` | `frascos_vacios` | 4 | |
| `objetos/objetos_3d.gd:1362` | `esta_plegado` | 4 | Puente plegable retirado |
| `objetos/pulso_3d.gd:216` | `paso_actual` | 4 | |
| `presentacion/agua_metaballs_3d.gd:168` | `marcar_oclusores` | 4 | |
| `presentacion/agua_render_3d.gd:1415` / `:1419` / `:1424` | `milisegundos_paredes` / `caras_paredes` / `milisegundos_hielo` | 4 + 4 + 4 | Medidas que no lee nadie |
| `presentacion/prueba_test2.gd:3872` | `origen_nivel` | 4 | |
| `presentacion/ui/marco_calidad.gd:61` | `color_acento` | 4 | |
| `magia/lanzador_3d.gd:2510` | `Receta3D.es_volador` | 3 | |
| `nucleo/estado.gd:116` | `subir_capacidad` | 3 | |
| `presentacion/runa_losa_3d.gd:61` | `esta_encendida` | 3 | |
| `nucleo/gesture_rectify.gd:165` | `tramos_de` | 2 | |

Fuera de la tabla, por ser retrollamadas del motor: `jugador/proporcion_chibi.gd:106` `_process_modification` (43 líneas) y `jugador/brazo_libro_3d.gd:138` `_process_modification_with_delta`. Son la API vieja y la nueva de `SkeletonModifier3D` y las dos están **vivas**. En 4.7 la vieja está obsoleta, pero sustituirla cambia la API que se usa, no el comportamiento.

### 2.3 (b) Vivas solo para pruebas y capturas (100 funciones, 678 líneas)

Son ganchos de prueba: borrarlas rompe la herramienta indicada (la columna «h» es el número de referencias desde `herramientas/`). Las más grandes:

| Archivo:línea | Función | Líneas | h |
|---|---|---|---|
| `presentacion/pieza_fuego_3d.gd:624` | `poner_llama` | 21 | 3 |
| `jugador/pj_3d.gd:1152` | `giro_al_andar` | 20 | 2 |
| `presentacion/albedos_3d.gd:39` / `:58` | `k_de` / `valor_de` | 19 / 15 | 10 / 9 |
| `presentacion/pieza_puzle_3d.gd:1085` | `poner_estado_tinaja` | 19 | 3 |
| `magia/cast_points.gd:192` | `desde_diccionario` | 18 | 5 |
| `presentacion/prueba_test2.gd:1363` | `joints_aristas` | 18 | 6 |
| `mundo/pieza_3d.gd:285` | `formas_colision` | 14 | 3 |
| `nucleo/hechizo.gd:549` | `figura` | 12 | 16 |
| `mundo/agua_sim_3d.gd:814` | `eventos_pendientes` | 12 | 4 |
| `jugador/pj_3d.gd:958` | `libro_asentar` | 11 | 9 |
| `magia/lanzador_3d.gd:813` | `lanzar_pagina_ya` | 11 | 5 |
| `jugador/ropa_3d.gd:131` | `zonas_apagadas` | 11 | 15 |
| `nucleo/hechizo.gd:687` | `describir` | 10 | 2 |
| `objetos/objetos_3d.gd:230` | `papeles_efectivos` | 10 | 2 |
| `presentacion/ui/tinta_pluma_2d.gd:108` | `dibujar_limpio` | 10 | 1 |
| `magia/lanzador_3d.gd:719` | `aviso_receta` | 9 | 3 |
| `enemigos/combate_3d.gd:442` | `reacciones_soportadas` | 9 | 2 |
| `mundo/agua_sim_3d.gd:761` | `textura_caida` | 9 | 2 |

La lista completa de las 100 está en `tB.txt` (scratchpad). Incluye `_barrido` (`lanzador_3d.gd:1415`), que no debería estar ahí: su única «referencia» en herramientas es otra función con el mismo nombre (`prueba_suelo_impactos.gd:289`), así que está muerta y se trata en 2.1. Destacan:
- `Pj3D` tiene 14 métodos que solo usan las pruebas (`quitar_ropa`, `ropa_puesta`, `estado_anim` con h=21, `pose_fija`, `lista_clips`, `velocidad_animacion`, `cadera_mundo`…).
- `LabPlaytestEoW3D` tiene 7 (`total_logros`, `puzle_nodo`, `rutas_visibles`…).
- `BordePiedras3D` (`n_bordes` con h=35, `n_piedras`, `n_triangulos_labio`), `Tinta` (`ganar_jefe`, `ganar_secreto`, `pigmento_de_zona`, `rellenar_barra`), `Repertoire` (`lock_sigil`, `reset_to_p0`), `Niveles` (`registrar`, `alfa_fundido`) y `Sigils.flotar`.

Recomendación: que no se borren. Se puede anotar «para pruebas» en su `##` (hoy casi ninguna lo dice).

### 2.4 (b) La barrera-burbuja antigua de `Lanzador3D` (unas 490 líneas)

Cadena comprobada a mano (las búsquedas distinguen mayúsculas, `Campo` como tipo):

- `Campo.new()` aparece una sola vez, en `_crear_campo` (`magia/lanzador_3d.gd:1776`).
- A `_crear_campo` solo lo llama `_una_ola` (`:1412`).
- A `_una_ola` solo la llama `herramientas/prueba_barrera.gd:51`.
- Por tanto, en el juego `_campos` está siempre vacío y `_barrera_activa` (`:143`) vale siempre `null`.

| Archivo:línea | Pieza | Líneas |
|---|---|---|
| `magia/lanzador_3d.gd:2578-2784` | `class Campo extends Node3D` | 207 |
| `:1769` | `_crear_campo` | 95 |
| `:1926` | `_visual_campo` | 72 |
| `:2175` | `_levantar_columna` (solo desde `_crear_campo` y `_visual_campo`) | 28 |
| `:2024` / `:2011` / `:2062` | `aplicar_elemento` / `atacante_en` / `reaccion_burbuja` (solo desde `Campo`, `:2654`, `:2720`, `:2652`) | 15 + 13 + 13 |
| `:1511` | `_campo_terminado` | unas 8 |
| `:1762` / `:1757` | `vida_campo` / `es_barrera_cupula` | 7 + 4 |
| `:2039` / `:2047` / `:2053` / `:2000` | `absorber_golpe` / `burbuja_contiene` / `burbuja_recibe` / `_proteger_con` | 7 + 4 + 7 + 6 |
| `:1409` | `_una_ola` | 6 |
| constantes | `REACCIONES_BURBUJA` (`:69`), `MULT_VIDA_BARRERA` (`:75`), `VIDA_MIN_BARRERA` (`:76`), `CAUDAL_CHORRO_CELDA` (`:488`, solo en `_crear_campo`) | |

Quien lo llama desde el juego (y hoy recibe siempre `false`): `jugador/jugador_3d.gd:269` (`absorber_golpe`) y `enemigos/combate_3d.gd:1132` y `:1134` (`burbuja_contiene` / `burbuja_recibe`). **Clase b con cautela**: antes de borrarlo, Pablo debe confirmar que la barrera V2 (`SolidezV2`/`HechizoVivo`) no tiene que absorber golpes por esta vía. Si se borra, `prueba_barrera.gd` (218 líneas) se archiva con ella.

### 2.5 `SpellRecipe`: lo que queda vivo y lo que no

`Receta3D` (lanzador) hereda y usa: los campos `travels`, `reach`, `spread`, `height`, `copies`, `bounces`, `pulse`, `blocks`, `barriers`, `cooldown`, `calidad`, `lifetime`, `origin`, `direction`, `_init`, `_es_chorro`, `_es_barrera_movil`, `_expande`, `_es_volador`, `_es_quieto` y `_powered`.

Muerto, o vivo solo por `spellcaster.gd`:

| Archivo:línea | Pieza | Líneas | Por qué |
|---|---|---|---|
| `nucleo/spell_recipe.gd:71` | `apply` | 33 | `Receta3D.apply` la sobrescribe; la base solo la usa `spellcaster.gd:795` |
| `:154` | `_points` | 58 | 0 llamadas |
| `:216` | `_spread_points` | 44 | Solo desde `_points` y desde `super` en `Receta3D._spread_points` (`lanzador_3d.gd:2490`, 12 líneas), al que a su vez solo llama `_points` |
| `:262` | `_fan` | 19 | 0 llamadas |
| `:131` / `:137` | `_espeja` / `_sigue` | 3 + 3 | Solo desde `_points`/`_fan` |
| `:14-56` | `TILE`, `ESCALA_ARO`, `CURVA_MURO`, `LEVEL`, `mirror`, `pull`, `delay`, `_base`, `_aplicados` | unas 12 | Solo los usan las anteriores (`pull` también lo usa la cadena `Campo`/`_barrido`) |
| `magia/lanzador_3d.gd:2436` | `Receta3D.line` | — | El comentario dice «en la V2 nunca vale true»; se lee en `:1758`, `:1782`, `:1940` y `:1962`: las ramas `receta.line` son inalcanzables |

En `Sigils` queda vivo solo por esa cadena (o por nada):
- `FORM` (37 líneas): `spell_recipe.gd`, `spellbook.gd:1576` y `prueba_receta_v2`. **Ojo**: `spellbook.gd:1576` lo recorre, así que hay que mirar ese uso antes de borrar.
- `OPERATOR`.
- `size_factor`, `jet_cells`, `RING_POINTS`, `MAX_SIZE_FACTOR`, `STACK_SIZE_GAIN`, `MAX_JET_CELLS`.
- `flotar` y `FOLLOW_RATE` (solo `prueba_kit`).
- `WALL_SPEED` (`sigils.gd:148`) y `PULSE_SPEED` (`:217`), que solo aparecen en comentarios de `lanzador_3d.gd:55-56`.
- `WAVE_GAP` (`:218`) y `FOLLOW_LIFETIME` (`:219`), con 0 referencias.

### 2.6 Constantes y variables miembro sin lectura (0 apariciones fuera de su declaración)

| Archivo:línea | Nombre |
|---|---|
| `magia/lanzador_3d.gd:36, 51, 54, 111, 112, 113, 174` | `CAPA_HECHIZO`, `ALCANCE_FLECHA`, `ALCANCE_HAZ`, `HUECOS_POR_PAGINA`, `ELEMENTOS_TEST3`, `SELLOS_TEST3`, `_huecos_usados` |
| `nucleo/sigils.gd:148, 217, 218, 219` | `WALL_SPEED`, `PULSE_SPEED`, `WAVE_GAP`, `FOLLOW_LIFETIME` |
| `nucleo/estado.gd:21, 30, 31` | `VEL_BASE`, `cura_pocion`, `vel_extra` |
| `nucleo/consumibles.gd:22` | `COLOR_OK` |
| `objetos/pared_hueca_pulso_3d.gd:30` | `ESCALA_MODELO` |
| `objetos/salida_nivel_3d.gd:22` | `COLOR_RAYA` |
| `jugador/equipo_3d.gd:30` | `NIVELES_GRIMORIO` |
| `jugador/jugador_3d.gd:101` | `_beber_previa` |
| `escenas/bosque_01_v01_3d.gd:166` | `_lineas_alquimista` |
| `escenas/prueba_titan.gd:23` | `_foco_extra_y` |
| `escenas/titan_3d.gd:18` | `ALTURA_REF` |
| `presentacion/ui/bolsa_ui.gd:22, 60` | `SEP`, `panel_textura` |
| `presentacion/ui/hud_eow.gd:37` | `_vida_vista` |
| `presentacion/ui/spellbook.gd:1524` | `DIRECTIONAL` |
| `presentacion/ui/tema_interfaz.gd:14, 21` | `FONDO_PANEL_SUAVE`, `TINTA_PERGAMINO` |
| `presentacion/vfx_elementos/viento.gd:19` | `ATLAS_LADO` |
| `presentacion/agua_render_3d.gd:1198` | `_hielo_est` |
| `presentacion/posproceso_3d.gd:29` | `SSAO_AFECTA_REFLEJOS` |
| `presentacion/prueba_test2.gd:78, 142` | `PJ_ASESINO`, `PX_POR_UNIDAD_1080` |
| `presentacion/reacciones_vfx_3d.gd:29` | `EFECTOS` |
| `presentacion/vfx_3d.gd:54` | `TONOS_LLAMA` |
| `presentacion/vfx_elemento_3d.gd:20` | `PROPIOS` |
| `presentacion/vfx_kit_3d.gd:30` | `EJE_UV_Y` |
| `laboratorios/lab_hechizos_3d.gd:42, 95` | `FASES_CONJURO`, `_impacto_nodos` |
| `laboratorios/lab_puzles_agua_3d.gd:54` | `CAUDAL_ARROYO` |

Solo las leen las herramientas (b):
- `hechizo.gd:39` `EVENTOS` y `:79` `CONDICIONES_MOMENTO`
- `sigils.gd:300` `GLIFOS_ALTURA_DOS_NIVELES_V2`, `:302` `GLIFOS_ANCHO_MURO_3_V2` y `:330` `MOMENTOS`
- `gesture_library.gd:83` `BIBLIA`
- `cast_points.gd:54` `MANOS` y `:56` `UNA_MANO_DE_ORIGEN`
- `estados_suelo_3d.gd:24` `SEGADA`
- `pj_3d.gd:212-213` `RIM_UMBRAL_VISIBLE` y `RIM_COBERTURA_MAX`
- `paleta_3d.gd:21, 29, 30, 36`
- `tema_interfaz.gd:18` `TEXTO_SUAVE`
- `lab_playtest_eow_3d.gd:125-136` (4 flags)
- `mundo_3d.gd:44` `terreno`
- `vfx_estado_3d.gd:188` `_hechizos`

Límite: no se cuentan las variables que solo se **escriben**, porque su escritura cuenta como aparición.

### 2.7 Reenvíos `Lanzador3D` → `Terreno3D` («REENVÍO M1»)

Hay 39 líneas marcadas `REENVÍO M1`/`ESPEJO M1` en `magia/lanzador_3d.gd:380-470`.
- **Muertos** (0 llamadas `Lanzador3D.x`, 0 internas y 0 por instancia): `sobre_hielo`, `cubre_hielo`, `es_cauce_seco`, `es_canal_ruinas`, `lados_de_canal`, `calcular_huellas`, `es_parcial`, `choca_huella`, `pisable` y `linea_libre` (10 reenvíos de unas 3 líneas cada uno).
- **Solo pruebas**: `fijar_altura` (`prueba_agua_hechizos.gd:75` y `:82`).
- **Vivos**: los demás, con 119 llamadas `Lanzador3D.x`, 59 de ellas desde el juego (`celda_de` ×18, `celda_solida` ×6, `en_mapa` ×6, `y_pies` ×5, `LECHO_AGUA` ×5…). Se pueden cambiar uno a uno por `Terreno3D.x`; el comportamiento es idéntico porque solo reenvían.

### 2.8 Escenas, mapas y archivos sin referencia

| Archivo | Tamaño | Referencias | Clase |
|---|---|---|---|
| `presentacion/grimorio/` (`grimorio_ui.gd`, 3 × `Meshy_AI_*Grimo*` glb+jpg, 6 × `pagina_*.png`, `paginas.json`, `generar_paginas.py`) | 42,1 MB, 40 archivos en git | Solo se nombra a sí mismo (`grimorio_ui.gd:15`) | a |
| `mundo/datos_nivel/Nivel_Bosque_copia_20261010_154655.tscn`, `…_20261013_171600.tscn`, `…_20261013_171626.tscn`, `Nivel_Bosque_01_copia_20261016_191143.tscn`, `…_pre_ampliacion.tscn` y `mapas/Bosque_01_copia_*.txt` (2) | 545 KB (864 + 2 816 + 2 816 + 2 044 + 865 líneas) | 0. Las crea `HorneadorNivel.hornear` (`hornear_nivel.gd:301`) como respaldo; ninguna herramienta las lee (las de hornear solo las cuentan para borrar las nuevas) | a |
| `mundo/datos_nivel/Meshy_AI_Wolfwood_Ranger_*` (6 jpg y 2 `.glb.import` cuyo `.glb` no existe) | 14,1 MB | 0 | a |
| `escenas/PruebaJugabilidadBosque.tscn` (836 líneas), `PruebaNivelBosque.tscn` (827), `PruebaJugabilidadBosque_1.tscn` (9) | 96 KB | 0 por ruta y 0 por uid | a (confirmar con Pablo si las abre a mano) |
| `arte/piezas/_anteriores_v8/` (`.gdignore`, `Nivel_Bosque_01_antes_v8.tscn` de 153 KB, `roca_musgosa`, `troncos_apilados` y `tronco_musgoso` de 1,6 MB cada una) | 4,9 MB | Godot no lo importa (`.gdignore`); está en git | a: el respaldo de v8 ya cumplió su función |
| `laboratorios/lab_grandmaster_3d.gd` | 477 líneas | 0: `LabGrandmaster3D.tscn` carga `lab_humanoide_3d.gd` | a |
| `mundo/vista_suelo_editor.gd` | 151 líneas | 0 (`VistaSuelo` no está en ningún `.tscn`) | a |
| `presentacion/ui/pista_interaccion.gd` | 97 líneas | Solo `herramientas/prueba_tema_interfaz.gd` y `captura_interfaz_eow.gd` | b (pieza de HUD aún sin montar) |
| `escenas/PruebaTest2.tscn` | 6 líneas | Solo `captura_bloque1_eow.gd` | b |
| `mundo/datos_nivel/Nivel_Test2.tscn`, `luz_juego.tscn` | 123 KB / 1 KB | 0 por nombre literal, pero `HorneadorNivel.nombre_archivo` arma `"Nivel_"+Nivel` (`hornear_nivel.gd:208`) | c: `Nivel_Test2` se carga por nombre construido; `luz_juego.tscn`, sin referencia |

### 2.9 Herramientas superadas: qué archivar

Propuesta: crear `herramientas/_archivo/` con `.gdignore` (como `_anteriores_v8`) y mover allí:

| Grupo | Scripts | Líneas | Por qué |
|---|---|---|---|
| Capturas «antes/después» del PLAN_EOW_VISUAL ya cerrado | `captura_look_v1v2` (140), `captura_v3v4` (132), `captura_personajes_v5` (146), `captura_v6` (213), `captura_v6_restos` (167), `captura_v7` (100), `captura_presupuesto_v8` (207) | 1 105 | Cada cabecera dice «mismo patrón que `captura_v3v4`/`v1v2`». Las capturas ya están en `docs/capturas/`. Si se quiere conservar la capacidad, va mejor UN `captura_antes_despues.gd` con una tabla {fase: escena, cámara, interruptor} |
| Revisión EoW del 23/10 | `captura_bloque1_eow` (206), `captura_bloque2_eow` (125), `captura_bloque3_eow` (86), `captura_bloque4_eow` (60) | 477 | Igual: capturas de un bloque terminado. `prueba_bloque3_eow.gd` (115, sin ventana) es una prueba de verdad: **se queda** |
| 2D retirado | `captura_libro_bosque.gd` (34) | 34 | Usa `spellcaster.gd` |
| Prueba de lo muerto | `prueba_barrera.gd` (218) y los casos 1-5 de `prueba_activacion.gd` (80) | 218 + parte | Prueban `Campo` y `_activacion_al_final`, que el juego no usa |

---

## 3. Tarea 2 — Duplicación y funciones comunes

### 3.1 `magia/grimorio.gd` frente a `magia/spellcaster.gd` (se resuelve borrando)

331 de las 384 líneas útiles de `grimorio.gd` aparecen tal cual en `spellcaster.gd`. Funciones idénticas (cuerpo normalizado): `add_sigil` (28), `_add_element` (21), `_recognize_with_templates` (18), `undo_last` (17), `add_gesture` (13), `_count_corners` (12), `place_element` (11), `_ready` (8), `_warn_missing_templates` (8), `_is_straight`, `_pattern_of_stroke`, `_recognize_by_corners` (7 cada una), `_primer_hueco_libre`, `page_element_data`, `_component_at` (6), `clear_sequence` (5), y `_sector_ocupado`, `sigils_used`, `_refuse_locked`, `select_page`, `page_ready`, `_get_total_length`, `_gesture_name_of`, `place_sigil` (4). Casi iguales: `_add_sigil_gesture` (97 %) y `_reconocer_glifo` (89 %). **No hay función común que crear**: basta con retirar `spellcaster.gd` (2.1).

### 3.2 Armazón de las herramientas (el mayor ahorro de líneas)

- 239 scripts: 114 `prueba_*` (24 430 líneas), 76 `captura_*` (10 098), 24 `escenario_*` (6 964) y otros.
- Solo 58 heredan de `escenario_base.gd` (o de un escenario que hereda de él). **181 son `extends SceneTree` sueltos** y repiten el montaje.

| Patrón repetido | Sueltos (181) | Hijos de `escenario_base` (58) |
|---|---|---|
| `func _initialize(` | 157 | 0 (lo da la base) |
| `func _ok(` | 95 definiciones en **15 variantes** (la más común, de 4 líneas, en 62 archivos; las otras en 7, 7, 5…) | 0 |
| `quit(` | 216 en 176 archivos | 1 |
| `await process_frame` | 629 en 159 archivos | 51 en 24 |
| `await physics_frame` | 25 en 10 | 0 |
| `get_texture().get_image()` + `save_png(` | 78 / 73 en 62 / 60 archivos | 28 / 28 en 22 |
| `func _esperar…/_frames…` propias | 18 en 17 | 6 en 6 |
| `make_dir_recursive` | 38 | 23 |
| `Estado.nuevo()` | 28 en 22 | 7 en 7 |
| `const S: float = 2.3` (o `var S`, `const LADO = 2.3`) | unas 70 | — |

`escenario_base.gd` (279 líneas) ya ofrece `_ok`, `_aviso`, `cargar`, `avanzar`, `avanzar_s`, `colocar_jugador`, `mover_hacia`, `lanzar`… pero exige cargar un nivel jugable. Propuesta de 3 utilidades, sin cambiar lo que mide cada prueba:

```gdscript
# herramientas/base_prueba.gd  — para las 95 pruebas con _ok propio
extends SceneTree
var _fallos: int = 0
func _ok(nombre: String, bien: bool, info: String = "") -> void   # la variante de 62 archivos
func _aviso(nombre: String, info: String = "") -> void
func terminar() -> void                                           # imprime el resumen y quit(_fallos)
func fotogramas(n: int) -> void                                   # await process_frame ×n
func fisica(n: int) -> void                                       # await physics_frame ×n
func reiniciar_estado() -> void                                   # Estado.nuevo() + Repertoire/Tinta si hace falta

# herramientas/base_captura.gd — para las 76 capturas
extends "res://herramientas/base_prueba.gd"
func montar(ruta_escena: String, fotogramas_espera: int = 30) -> Node
func foto(carpeta: String, nombre: String) -> String              # get_image + make_dir_recursive + save_png
func carpeta_de_args(defecto: String) -> String                   # el `-- <carpeta>` que repiten todas

# escenario_base.gd pasa a heredar de base_prueba.gd y pierde su _ok/_aviso.
```

Ahorro estimado (medido sobre la variante mayoritaria): 95 × 4-6 líneas de `_ok` (unas 450), más unos 157 `_initialize`/`quit` y unas 140 rutinas de foto. En total, entre 900 y 1 100 líneas. Ojo con las variantes de `_ok` que cambian el orden de los argumentos (`_ok(cond, msg)` frente a `_ok(nombre, bien, info)`): migrarlas obliga a tocar cada llamada; la salida impresa («OK»/«FALLO») cambia de formato en 8 variantes. Si algo lee esa salida (un script de CI o Pablo a ojo), avisar.

### 3.3 Reglas de nivel (`escenas/*_3d.gd`): una base común

Pares medidos (líneas no vacías de más de 12 caracteres de A que están en B):
- `bosque_01_3d` (577) frente a `bosque_01_v01_3d` (800): **280 comunes**.
- `bosque_3d` (359) frente a `jugabilidad_3d` (494): 108.
- `terra_fina_3d` (357) frente a `bosque_3d` (359): 63.

Funciones idénticas o casi idénticas:

| Función | Sitios (archivo:línea [líneas]) | Igualdad |
|---|---|---|
| `_leer_marcas_por_nombre` | `bosque_01_3d.gd:241` [33], `bosque_01_v01_3d.gd:233` [33] | idénticas |
| `_montar_puerta` | `bosque_01_3d.gd:350`, `bosque_01_v01_3d.gd:403` (idénticas, 23); `bosque_3d.gd:138` [23] (75 %); `jugabilidad_3d.gd:363` [21] | |
| `_criterio_secuencia` / `_criterio_propagacion` / `_criterio_antorchas` | `bosque_01_3d.gd:457/432/446`, `bosque_01_v01_3d.gd:595/569/584` | 95 % / 70 % / 83 % |
| `_buscar_alquimista` | `bosque_01_3d.gd:327` [22], `bosque_01_v01_3d.gd:339` [25] | 82 % |
| `_revisar_estanque`, `_montar_aviso`, `_contar_lamparas`, `_activar` | `bosque_01_3d.gd:415/373/516/483`, `bosque_01_v01_3d.gd:548/426/658/621` | idénticas (16/15/5/4) |
| `_crear_loberno`, `_encender_lampara` | `bosque_01_3d.gd:316/505`, `bosque_01_v01_3d.gd:328/645` | 86 % / 89 % |
| `_abrir_puerta` | `bosque_01_3d.gd:524`, `bosque_3d.gd:340` (88 %), `jugabilidad_3d.gd:574 _abrir` (63 %), `bosque_01_v01_3d.gd:667` | |
| `_montar_sello_salida` | `bosque_3d.gd:162` [19], `terra_fina_3d.gd:342` [21] | |
| `_decir(texto, seg)` | `bosque_01_3d.gd:720`, `bosque_01_v01_3d.gd:1003`, `bosque_3d.gd:420`, `jugabilidad_3d.gd:585`, `terra_fina_3d.gd:434`, `lab_playtest_eow_3d.gd:797` | 6 copias, 4-6 líneas |
| `_arrancar` (`call_deferred` + espera a la maqueta) | `bosque_01_3d.gd:136`, `bosque_01_v01_3d.gd:176`, `puzle.gd:945`, `terra_fina_3d.gd:75`, `lab_playtest_eow_3d.gd:201`, `lab_puzles_agua_3d.gd:108`, `lab_puzles_fuego_3d.gd:72`, `lab_recetas_3d.gd:81` | 8 copias de 5 líneas |
| `_runa` / `runa` | `bosque_3d.gd:319`, `puzle.gd:1047` | idénticas (6) |

**Diálogos y E** (pista 5). Cada nivel tiene su tabla y su manejador:
- Tablas: `bosque_3d.gd:43 DIALOGOS`, `jugabilidad_3d.gd:220 DIALOGOS`, `bosque_01_3d.gd:84 DIALOGO_ALQUIMISTA`, y en `bosque_01_v01_3d.gd:110-138` 4 arrays y 6 cadenas sueltas.
- Manejadores de la E: `bosque_3d.gd:363` [39], `jugabilidad_3d.gd:531` [32], `bosque_01_3d.gd:628` [21] + `_hablar_alquimista:703` [17], `bosque_01_v01_3d.gd:928` [21] + `_hablar:949` [13], y además `puzle.gd:465` y `:908`.
- El núcleo repetido en los dos primeros (unas 22 líneas cada uno) es: buscar el NPC más cercano dentro de `ALCANCE_HABLAR`, ir a la siguiente línea en ciclo, `_decir("%s: «%s»")`, `npc.mirar`, `npc.jugar("talk")`, `Sfx3D.play(npc,"conversacion_voz")`, `_hablando = npc`, `_t_habla = 2.5`.

Propuesta:

```gdscript
# escenas/reglas_nivel_3d.gd   (base de bosque_3d, jugabilidad_3d, terra_fina_3d, bosque_01_3d, bosque_01_v01_3d)
class_name ReglasNivel3D extends Node
var m: Node3D                                   # la maqueta
func _arrancar() -> void                        # el call_deferred común; llama a _al_arrancar() (virtual)
func decir(texto: String, seg: float) -> void   # el _decir de las 6 copias
func montar_puerta(c: Vector2i, … ) -> Node3D   # el de bosque_01/_v01 (23 líneas), con parámetros para las diferencias de bosque_3d
func abrir_puerta(nodo: Node3D, c: Vector2i, aviso: String) -> void
func montar_sello_salida(c: Vector2i) -> Node3D
func leer_marcas_por_nombre() -> Dictionary

# escenas/conversaciones_npc.gd
class_name ConversacionesNpc extends RefCounted
func registrar(nombre: String, pj: Pj3D, lineas: Array) -> void
func mas_cercano(yo: Vector3, alcance: float) -> String
func siguiente_linea(nombre: String) -> String           # ciclo por npc (lo que hoy hacen _lineas / _lineas_dialogo)
func hablar(nombre: String, yo: Vector3, decir: Callable, dura: float) -> Pj3D   # mirar + talk + sfx; devuelve el npc para _hablando
```

Los casos especiales (la oferta de la barrera del guardabosques, `bosque_3d.gd:381-393`; la tarea 2 de jugabilidad, `:559`; los diálogos con estado del v01, `_texto_de:963`) siguen en su nivel como un `if` antes o después de `hablar()`. Ahorro estimado: unas 300 líneas entre `bosque_01_3d` y `bosque_01_v01_3d`, más unas 120 en el resto.

### 3.4 Lecturas de privados ajenos (regla «un dato, un dueño»)

En código de juego hay **230** `get("_x")`/`call("_x")`/`set("_x")` sobre otro objeto (en `herramientas/`, 587 más), y además **168** accesos directos `obj._x` (`jugabilidad_3d.gd` ×44 —`m._jugador`, `m._fx`, `m._goblins`, `m._liberar`—, `hechizo_vivo.gd` ×25, `escudo_3d.gd` ×11…; esta cifra incluye algún campo de clase interna del mismo archivo, así que es una cota superior).

Por nombre (juego):

| Privado | Veces | Quién lo lee | Dueño | Público propuesto |
|---|---|---|---|---|
| `_centro_celda` | 22 | bosque_01_3d (5), bosque_01_v01_3d (9), bosque_3d (5), terra_fina_3d (3) | PruebaTest2 | `Terreno3D.centro_de` (ya existe y es igual) |
| `_jugador` | 21 | bosque_01_3d (3), bosque_01_v01_3d (5), bosque_3d (6), terra_fina_3d (2), jugador_3d (1), playlog_3d (2), zonas_3d (2) | PruebaTest2 | `func jugador() -> Pj3D` |
| `_fx` | 21 | combate_3d (3), bosque_01_3d/v01/bosque_3d (2 cada uno), jugador_3d, lanzador_3d (2), emisor_rayo_3d (2), surtidor_3d (5), tronco_puente_3d (2) | PruebaTest2 | `func fx() -> Vfx3D` |
| `_props` | 19 | niveles (13) y labs (6) | PruebaTest2 | `func props()` |
| `_liberar` | 11 | niveles, lanzador_3d:291, tronco_estanque_3d:123, tronco_puente_3d:232 | PruebaTest2 | `Terreno3D.liberar_celda` (ya existe) |
| `_goblins` | 11 | combate_3d (3), gatopedro_3d, bosque_01/v01, puzle:596, jugador_3d:172, lab_playtest | PruebaTest2 | `func enemigos() -> Array` |
| `_pos_marca` | 9 | bosque_01_v01_3d (6), bosque_01_3d, terra_fina_3d, lab_playtest | PruebaTest2 | `func pos_marca(c, y)` |
| `_mapa` | 8 | 4 niveles, surtidor_3d:223 y `set` en `:228` (¡escribe!) | PruebaTest2 | `Terreno3D.mapa` (ya lo tiene, M5) |
| `_bloqueadas` | 7 | bosque_3d (2), terra_fina_3d (2), lanzador_3d:251, terreno_3d:162, surtidor_3d:229 | PruebaTest2 | `Terreno3D.bloqueada` |
| `_lado` | 7 | lanzador_3d:2794, terreno_3d (5), niebla_foso_3d:72 | PruebaTest2 | `Terreno3D.lado_del_mapa()` (ya existe) |
| `_tam_camara` | 7 | secuencia_cofre_legendario_3d (4, incluye `set` en `:296`), zonas_3d (3, incluye `set` en `:248`) | PruebaTest2 | `camara_tam` get/set |
| `_letra` | 6 | lanzador_3d:247, `:2798`, terreno_3d:380, surtidor_3d (3) | PruebaTest2 | `Terreno3D.letra_de` |
| `_personaje` | 6 | combate_3d:288 y `:300`, gatopedro_3d:77, bosque_01/v01, lab_playtest | PruebaTest2 | `func crear_personaje(ids, pos) -> Pj3D` |
| `_bloquear` | 6 | bosque_01_3d (3), bosque_01_v01_3d (3) | PruebaTest2 | `Terreno3D.bloquear_celda` |
| `_pieza` | 5 | puzle:526, brillo_pulso_3d:65, muro_agrietado_3d:227, recolectable_3d:79, rompible_3d:154 | PruebaTest2 | `func pieza(id, …)` |
| `_sol` / `_env` / `_camara` | 5 / 3 / 3 | zonas_3d, secuencia_cofre_legendario_3d, jugador_3d:150 | PruebaTest2 | `func luz_sol()`, `func entorno()`, `func camara()` |
| `_reactivos` | 5 | bosque_01_3d, bosque_01_v01_3d (3), bosque_3d | PruebaTest2 | `func reactivos()` |
| `_hf` | 5 | bosque_01/v01, reacciones_suelo_3d:89, playlog_3d (2) | PruebaTest2 | `func hierba_fases()` |
| `_velo` | 4 | jugador_3d:189 y `:419`, niveles:168, hud_eow:144 | PruebaTest2 | `func hay_velo() -> bool` |
| Resto (1-2 cada uno) | 34 | `_ancho`/`_alto` (terra_fina_3d:138, `:248`), `_mat_suelo` (`:239`), `_mat_lado_suelo` (`:240`), `_es_canal` (terreno_3d:388, surtidor_3d:68), `_abre_hacia` (terreno_3d:395), `_lotes`/`_plantilla` (terreno_3d:629, `:634`), `_es_agua`/`_es_hierba`/`_precalentando` (lanzador_3d:245-249), `_chispas`/`_libro`/`_libro_cinto` (lanzador_3d:1221-1239, sobre Pj3D), `_al_impactar` (lanzador_3d:1903, `:1921`), `_cancelar_modo` (jugador_3d:336), `_tipo_suelo` (jugador_3d:487), `_giro_cam` (jugador_3d:571), `_materiales` (combate_3d:334, sobre Pj3D), `_npc` (bosque_01_v01_3d:718), `_disco` (bosque_3d:121), `_celda_de` (bosque_3d:262, terra_fina_3d:398), `_pisadas` (playlog_3d:325), `_tilt` (zonas_3d:258), `_reconocer_glifo` (spellbook.gd:855, sobre el grimorio), `_aviso` (aviso_objeto.gd:61, `:68`), `_jug` (lab_estados_3d:33, `:95`), `_mundo`/`_efectos` (lab_playtest:212, `:230`), `_mirada` (lab_recetas:189), `_es_tinaja`/`_pie` (prueba_test2:5628, `:5796`) | | |

El 80 % sale de la maqueta `PruebaTest2`. Lo que más ahorra (sin cambiar nada) es que los 4 niveles y `surtidor_3d` usen las funciones de `Terreno3D` que ya existen (`centro_de`, `celda_de`, `bloqueada`, `liberar_celda`, `bloquear_celda`, `letra_de`, `lado_del_mapa`, `mapa`): son 70 de las 230. Las otras necesitan un getter en la maqueta, que es justo la M5 de `ARQUITECTURA_MODULAR.md`.

### 3.5 Celda ↔ mundo (casilla de 2,3 u)

- **Definiciones del 2,3 en el juego**, 17:
  - `hornear_nivel.gd:22 S`, `pieza_3d.gd:30 S`, `objetos_3d.gd:64 S`, `canal_3d.gd:22 S`, `prueba_test2.gd:18 S`, `prueba_titan.gd:9 S` y `:10 LADO = 25×2,3`
  - `puente_reactivo_3d.gd:26 CASILLA`, `lab_fases_fuego.gd:13 CASILLA`
  - `marcador_3d.gd:289 var s`, `pozo_cauce_3d.gd:25 var lado`, `rastrojo_3d.gd:49 var lado`
  - `vfx_elemento_3d.gd:45 casilla`, `vfx_estado_3d.gd:63 casilla`
  - `lab_agua_3d.gd:24`, `lab_agua_capa_3d.gd:19`, `lab_lamina_agua.gd:12`
  - y el dueño, `terreno_3d.gd:66 static var casilla` (que `cargar_datos` fija a partir del `S` de la maqueta en `:724`).
- **Literales `2.3`** en el código de juego: 64.
- **Conversión repetida**:
  - `Terreno3D.celda_de` y `centro_de` (`terreno_3d.gd:309`, `:313`) son las canónicas.
  - Copias: `prueba_test2.gd:1260 _centro_celda` (89 referencias), `:4531 _celda_de` (24), `:5131` (en línea), `colision_pieza.gd:227 _celda`, y los reenvíos de `lanzador_3d.gd:421` y `:424`.
  - `floor(x / S)` escrito en línea: 17 veces (prueba_test2 ×7, agua_sim_3d ×2, y bosque_01/v01, lanzador_3d, terreno_3d, colision_pieza, cuadricula_guia, hierba_3d, lab_agua_3d).
  - `(float(c.x) + 0.5) * …`: 15 veces (hornear_nivel ×3, borde_piedras_3d ×3, vfx_estado_3d ×2, lanzador_3d ×2, hechizo_vivo, terreno_3d, lava_3d, prueba_test2, rastrojo_3d).

Propuesta:

```gdscript
# mundo/terreno_3d.gd (ya es el dueño)
const CASILLA_DEFECTO: float = 2.3             # la usan como valor inicial S/CASILLA/casilla de los demás
static func celda_de(p: Vector3) -> Vector2i   # existe
static func centro_de(c: Vector2i, y := 0.0) -> Vector3   # existe
static func centro_2d(c: Vector2i) -> Vector2  # nueva: lo que hacen a mano hornear_nivel, borde_piedras, vfx_estado y lava
```

`pieza_3d`, `objetos_3d`, `canal_3d` y `hornear_nivel` pasan a `const S := Terreno3D.CASILLA_DEFECTO` (es `@tool`/estático: no puede leer `Terreno3D.casilla` en tiempo de editor, de ahí la constante). En las unas 70 herramientas con `const S = 2.3`, igual; lo hace `base_prueba.gd` (3.2).

### 3.6 «¿Está libre o sólida esta casilla?»

| Función | Archivo:línea | Regla |
|---|---|---|
| `Terreno3D.celda_solida(c, nivel)` | `terreno_3d.gd:575` | Fuera del mapa → sí; bloqueada (salvo `~`); hielo gordo; altura ≥ nivel+1 |
| `Terreno3D.ocupado(c, nivel)` | `:597` | **Alias exacto** de `celda_solida`, y solo lo usan las pruebas (`prueba_ocupacion`, `prueba_suelo_impactos`) |
| `Terreno3D.cabe(celdas, …)` | `:603` | `ocupado` por casilla y altura, más `sobre_agua`. **Solo lo usan las pruebas** |
| `Terreno3D.pisable(c, nivel, sube, max, nada, ignora)` | `:675` | Para quien camina |
| `Lanzador3D.celda_solida` / `pisable` | `lanzador_3d.gd:454`, `:466` | Reenvíos (`pisable` sin uso) |
| `Lanzador3D.construir_tierra` | `lanzador_3d.gd:2081-2092` | Repite a mano en 12 líneas: en mapa, no agua, letra no `~`/`b`, no bloqueada, no permanente, sin jugador ni goblin en la casilla. El comentario de `terreno_3d.gd:589` ya lo señala |
| `Caminos3D.transitable` | `caminos_3d.gd:82` | `pisable(c,99,false,99,false)` + no agua + no cauce hondo |
| `Combate3D._puede_estar` / `_cabe_con_cuerpo` | `combate_3d.gd:1300-1326` | `pisable` con 4 puntos de radio |
| `SalidaNivel3D._libre` | `salida_nivel_3d.gd:160` | `letra != "#" and != " "` |
| `PruebaTest2._pisable` | `prueba_test2.gd:5130` | La maqueta antigua: bloqueadas + **la hierba crecida es sólida**, lo contrario que `Terreno3D.pisable` desde la 6.22a (`terreno_3d.gd:686`). Solo lo usa `_mover` (`:5139`), el movimiento de la maqueta sin `Jugador3D` |

Propuesta sin cambiar reglas:
- (1) Borrar `ocupado` y dejar `celda_solida` (o al revés), con 1 nombre para 1 regla.
- (2) Que `construir_tierra` llame a `Terreno3D.cabe([c], 0, 1, false)` más su propia comprobación de actores. **Ojo**: `cabe` no mira la letra `b` (puente) ni `Terreno3D.permanentes`. Para que sea un refactor puro, hay que añadir esas dos condiciones como parámetros de `cabe` (`func cabe(celdas, nivel_desde, alto := 1, sobre_agua := true, sobre_puente := true, permanentes := true)`), o dejar las dos líneas en `construir_tierra`.
- (3) `PruebaTest2._pisable` diverge a propósito o por olvido: **no unificar sin preguntar a Pablo** (cambiaría cómo se mueve el jugador en la maqueta sin `Jugador3D`).

### 3.7 Temporizadores (`create_timer`) y referencias débiles

- 49 `create_timer(` en 24 archivos del juego. 28 con `process_always = false`. 17 conectan directamente a `x.queue_free`: `vfx_kit_3d.gd:369`, `:614` y `:1100`, `vfx_puzle_3d.gd:116`, `vfx_reaccion_3d.gd:88` y `:232`, `vfx_canouro_3d.gd:136`, `hielo.gd:738`, `pieza_puzle_3d.gd:375`, `agua_metaballs_3d.gd:297` y `:351`, `vfx_3d.gd:185`, `pj_3d.gd:1126`, `cofre_3d.gd:360`, entre otros.
- Ayudantes de «borrar si sigue vivo» idénticos (4 líneas): `Lanzador3D._borrar_si_vive` (`lanzador_3d.gd:1504`, estático), `VfxElemento3D._borrar` (`vfx_elemento_3d.gd:513`) y `LabFasesFuego._liberar` (`lab_fases_fuego.gd:196`).
- `_despues(t, f)` en 3 sitios: `lanzador_3d.gd:1527` (ejecuta ya si t ≤ 0,001), `vfx_3d.gd:2403` (sin ese atajo) y `hechizo_vivo.gd:296` (con contador `_pendientes` y referencia débil, distinto a propósito).

Propuesta:

```gdscript
# nucleo/retraso.gd
class_name Retraso extends RefCounted
static func borrar_tras(nodo: Node, t: float, process_always: bool = false) -> void   # weakref + _borrar_si_vive
static func llamar_tras(desde: Node, t: float, f: Callable, process_always: bool = false, ya_si_cero: bool = true) -> void
static func _borrar_si_vive(ref: WeakRef) -> void
```

Hay que conservar el `process_always` de cada sitio (hoy hay mezcla: `agua_metaballs_3d` usa `true` por defecto, `vfx_*` usa `false`, y `pj_3d.gd:1126`/`logros_3d.gd:235` usan `ignore_time_scale`). Pasar `queue_free` directo a weakref no cambia lo que se ve. Solo evita el error del motor cuando el nodo ya murió (riesgo que hoy existe en los 17 sitios).

### 3.8 VFX: emisores de partículas y texturas suaves hechos a mano

- 11 `GPUParticles3D.new()` + `ParticleProcessMaterial.new()` en 9 archivos, y 2 `CPUParticles3D`.
- Funciones que montan un emisor completo (material de proceso, gradiente, curva y malla de cuadro):
  - `vfx_kit_3d.gd:551 particulas` [67] y `:1046 oro_motas` [58]
  - `vfx_puzle_3d.gd:53 _emisor` [67], con un **56 %** de líneas comunes con `VfxKit3D.particulas`
  - `vfx_3d.gd:2259 _particulas` [51] y `:2224 _estallido` [19]
  - `prueba_test2.gd:4406 _particulas` [46]
  - `conjuro_vfx_3d.gd:436 _particulas_luz` [33] y `:708 _motas` [40]
  - `vfx_canouro_3d.gd:186 crear_emisor` [54]
  - `consumo_fuego_3d.gd:184 _montar_particulas` [69]
  - `objetos_3d.gd:804 _montar_emisor` [26]
  - `agua_metaballs_3d.gd:354 _emisor` [22]
  - `fases_fuego_3d.gd:157 _humo` [29]
  - En total, **unas 580 líneas**.
- Textura «mancha suave» (una `Image` con un degradado radial), 6 copias de 13-16 líneas: `consumo_fuego_3d.gd:127 _textura_suave` y `fases_fuego_3d.gd:139 _suave` (idénticas), `vfx_puzle_3d.gd:36 _punto`, `mano_pluma_3d.gd:152 _textura_sombra`, `vfx_kit_3d.gd:275 mancha_emision` y `vfx_puzle_3d.gd:23 _textura`.
- Aros: `logros_3d.gd:152 _anillo` [24] y `vfx_puzle_3d.gd:121 _aro` [23], con un 86 % común.
- Luz puntual: `_luz` en 5 archivos (`vfx_kit_3d:466`, `vfx_estado_3d:619`, `vfx_3d:2310`, `logros_3d:177`, `prueba_test2:4489`) y `objetos_3d:1474 _crear_luz` (75 % común con la de la maqueta).

Propuesta: `VfxKit3D` ya es el kit; que reciba un diccionario de opciones.

```gdscript
static func particulas(padre: Node3D, pos: Vector3, n: int, vida: float, tam: float, vel: float, opc: Dictionary = {}) -> GPUParticles3D
#   opc: textura, chispas, gravedad, dir, abanico, caja, aditivo, color/gradiente, curva_escala, uno_solo, borrar_tras
static func textura_mancha(lado: int, dureza: float = 2.0, color: Color = Color.WHITE) -> ImageTexture   # cachea por (lado, dureza)
static func aro(padre: Node3D, pos: Vector3, radio: float, color: Color, dura: float) -> MeshInstance3D
static func luz(padre: Node3D, pos: Vector3, color: Color, energia: float, rango: float) -> OmniLight3D
```

`VfxPuzle3D._emisor` y las de `conjuro_vfx`/`consumo_fuego`/`fases_fuego` pasan a llamarla con sus valores de hoy. Se ahorrarían entre 300 y 350 líneas. Los nombres de opción de `vfx_puzle` y `vfx_kit` coinciden casi del todo, que es por donde conviene empezar. Para que no cambie nada visual hay que comparar con una captura antes y después (`captura_vfx_*`).

### 3.9 Tablas de datos duplicadas

- **`Sigils.GLIFOS_V2` (`sigils.gd:343-359`) frente a `Sigils.GLIFOS` (`:374-398`)**: los mismos 10 glifos y los mismos números (`prueba_hechizo` comprueba que coinciden). Propuesta: un `static func _v2_desde_glifos() -> Dictionary` que construya GLIFOS_V2 al cargar, traduciendo `modificadores[0]` (`semiejes.x/y/z` → `tipo:"eje"`; el resto → `tipo:"prop"`, con `param`, `inicio`/`desde`, `por_glifo` = `valor`, `tope` y `modo` = `op`). Así hay **un** sitio donde se escribe un glifo. Riesgo: los `inicio` de `flecha` (1,0), `barrera` (1,0) y `repeticion` (1,0) salen de `desde`. Hay que comprobarlo con `prueba_hechizo` y `prueba_receta_v2`. Ahorro: 17 líneas, y desaparece una fuente de errores.
- **Letras del mapa** (pista 9): el significado de cada letra está repartido entre:
  - `Marcador3D.LETRAS` (`marcador_3d.gd:51-93`: 42 letras con grupo, tipo, rótulo, color y pieza)
  - `HorneadorNivel.LETRAS_SUELO = ".~bgv#,cR"` y `LETRAS_DECOR = "UtxV"` (`hornear_nivel.gd:32`, `:36`)
  - la cadena `"#~.,cUtxV"` de `PruebaTest2._colocar_letras` (`prueba_test2.gd:3337`), que es la misma idea con otro conjunto
  - el `match` de `_colocar_letras` (`:3328`, **201 líneas**), que repite casilla a casilla el `tipo`/`pieza` que ya dice `LETRAS` (`z`→seto_seco, `l`→tronco, `j/k/i`→totem_runico, `F`→fogata, `T`→brasero, `n/Q/M/m`→npc…)
  - y **114 comparaciones** de letras sueltas en el juego (`prueba_test2` ×48, `terreno_3d` ×20, `hornear_nivel` ×8, `puzle` ×6, `lanzador_3d` ×5, `marcador_3d` ×5, `lab_agua_3d` ×5…).

  Propuesta: un `LetrasMapa` (o ampliar `Marcador3D.LETRAS` con `suelo: true`, `decor: true` y `bloquea: true`) del que lean `HorneadorNivel`, `_colocar_letras` y `Terreno3D` (`es_agua`, `es_canal`, `pisable`…), con `static func es_decor(l)`, `es_suelo(l)`, `bloquea(l)` y `pieza_de(l)`. `_colocar_letras` puede quedarse con su `match` para lo que tiene lógica propia (pared con árbol o roca por hash, telaraña, `B`) y sacar de la tabla el resto. Ahorro: unas 60 líneas del `match`, y sobre todo un solo lugar donde vive una letra nueva.

### 3.10 Laboratorios gemelos

- `lab_gato_3d` (628 líneas útiles) / `lab_humanoide_3d` (886) / `lab_grandmaster_3d` (400, huérfano, ver 2.8): 273 y 297 líneas comunes.
  - Idénticas: `_montar_escena` (38, grandmaster = humanoide; 84 % con gato), `_camara_preset` (13, ×3), `_unhandled_input` (22, grandmaster = humanoide), `_titulo` (4, ×3) y `_elegir_hueso` (7).
  - Casi iguales: `_slider` (23, ×3, 90-95 %), `_guardar_originales` (×3, 77-83 %), `_dibujar_esqueleto` (×3, 57-71 %), `_cargar_gato`/`_cargar` (81 %) y `_elegir_clip` (82 %).
  - Propuesta: borrar `lab_grandmaster_3d.gd` (las copias exactas desaparecen solas) y una base `LabPersonaje3D` con `_montar_escena`, `_slider`, `_camara_preset`, `_titulo`, `_guardar_originales` y `_dibujar_esqueleto` para gato y humanoide (unas 150 líneas menos).
- `lab_puzles_agua_3d` (186) / `lab_puzles_fuego_3d` (200) / `lab_playtest_eow_3d`: 108 líneas comunes entre los dos primeros.
  - Idénticas: `_montar_hud` (×3), `_cartel` (×3), `colocar_jugador` (×4, también `lab_recetas_3d.gd:309`), `pulsador_en` (×2) y `puzle` (×2).
  - Casi iguales: `iniciar` (94 %), `_montar_salas` (93 %) y `_unhandled_input` (91 %).
  - Propuesta: base `LabPuzles3D` (unas 90 líneas menos).
- UI: `bolsa_ui.gd:570 _ocultar` = `menu_pestanas.gd:334 _ocultar` (idénticas), `_animar` (56 %), y `diario_misiones.gd:69` / `mision_hud.gd:29 _enganchar` (56 %).

### 3.11 HUD e interfaz (`presentacion/ui`)

`TemaInterfaz` (`tema_interfaz.gd`, con `caja_panel` en `:57`) solo lo usan `hud_eow` (14), `menu_pestanas` (4), `barra_hud` (4), `bolsa_ui` (3) y `pista_interaccion` (3). En cambio:
- Constantes `Color` propias por archivo: `bolsa_ui` 14, `spellbook` 9, `diario_misiones` 7, `hud_eow` 7, `ejes_receta_ui` 6.
- `StyleBoxFlat.new()`: 11 veces en 9 archivos (`barra_hud` ×3).
- `add_theme_*_override`: 29 `font_size` y 84 de contorno.
- `draw_string`: 31, con centrado a mano: `page_hud.gd:90 _texto`, `menu_pestanas.gd:627 _texto` y `ejes_receta_ui.gd:111 _rotulo`.
- `Label.new()`: 61 en 33 archivos (los labs, 23).

Propuesta: `TemaInterfaz.texto_centrado(ci: CanvasItem, pos, texto, tam, color)`, `TemaInterfaz.etiqueta(tam, color, contorno := 0) -> Label` (sustituye `bolsa_ui._etiqueta`, `rune_palette._etiqueta` y las de los labs) y que las paletas de `bolsa_ui`/`diario_misiones`/`spellbook` lean de `TemaInterfaz` cuando el color sea el mismo. **Solo** donde el valor coincide hoy: si cambia un tono, ya no es refactor.

### 3.12 Otras copias entre la maqueta y las piezas

`mundo/pieza_3d.gd` se escribió copiando funciones de `prueba_test2.gd`:
- `_caja` (14, ×3 con `catalogo_assets.gd:295`; `equipo_3d.gd:245 _caja_de`, 92 %)
- `_malla_de_glb` (13, idénticas en `pieza_3d.gd:503` y `prueba_test2.gd:2787`; 58 % con `modelo_elemento.gd:19 malla_glb`)
- `_mitad_malla` (`pieza_3d.gd:520` y `prueba_test2.gd:2804`, 91 %)
- `_cargar_bibliotecas` (`pieza_3d.gd:170` y `prueba_test2.gd:2531`)
- `_vruido` (`hornear_nivel.gd:162` = `prueba_test2.gd:2404`)
- `_quad` (`pozo_cauce_3d.gd:162` = `prueba_test2.gd:2508`)
- `abre_hacia` (`terreno_3d.gd:393` / `prueba_test2.gd:5736`, 67 %)
- `_textura_hielo` (`agua_capa_3d.gd:519` / `prueba_test2.gd:3159`, 74 %)

Propuesta: que `prueba_test2` llame a las estáticas de `Pieza3D` y `ModeloElemento` (unas 80 líneas menos y un paso hacia la M5).

---

## 4. Orden de trabajo recomendado (todo sin cambio de comportamiento)

1. **Borrar lo que no carga nadie** (clase a, cero riesgo de juego):
   - `presentacion/grimorio/` (42 MB), las copias `_copia_2026*`, los jpg `Wolfwood` (14 MB) y `_anteriores_v8`
   - `lab_grandmaster_3d.gd` y `vista_suelo_editor.gd`
   - las 3 escenas huérfanas (preguntar antes a Pablo por las F6)
   - las 45 funciones de 2.2, las constantes de 2.6, los 10 reenvíos muertos, el bloque de voltereta de `page_hud`, `_barrido` y su cadena, y `WALL_SPEED`/`PULSE_SPEED`/`WAVE_GAP`/`FOLLOW_LIFETIME`.
2. **Retirar el 2D**: `spellcaster.gd`, `captura_libro_bosque.gd`, la parte 2D de `SpellRecipe` (2.5) y las constantes de `Sigils` que solo usaba esa cadena. Adaptar `prueba_receta_v2.gd:276` (ese bloque usa el spellcaster).
3. **Decidir con Pablo la burbuja antigua** (2.4, unas 490 líneas) y `carried_element`.
4. **Base de herramientas** (3.2) y archivar las capturas cerradas (2.9).
5. **`ReglasNivel3D` + `ConversacionesNpc`** (3.3) y cambiar los privados de la maqueta por `Terreno3D` (3.4, 70 de los 230).
6. **Kits**: `Retraso` (3.7), `VfxKit3D.particulas` con opciones (3.8), `TemaInterfaz` (3.11), `LetrasMapa` (3.9) y GLIFOS_V2 derivado.

Archivos auxiliares de esta medición (scratchpad): `funcs.csv` (las 4 025 funciones con sus cuentas), `consts.csv`, `tA.txt` (tabla 2.2), `tB.txt` (tabla 2.3), `dups.txt` (49 grupos de cuerpos idénticos de 4 o más líneas: 548 líneas sobrantes en el juego) y `near.txt` (74 pares con un 55 % o más de líneas comunes).
