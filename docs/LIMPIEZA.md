# Limpieza de primavera — catálogo y plan (13/10/2026)

> **Estado a 13/10 12:40 (Pablo ejecutó):** Fase 1 hecha y revisada (los 26 muertos y las copias, borrados). **Reorganización hecha:
> `poc_25d/` ya no existe**; las rutas nuevas son las de §3 (`tools/reorganizar.ps1`, 365 archivos con rutas reescritas, 0 `res://poc_25d/`
> restantes). Fase 3 hecha (arte 2D, sprites, `tests/`, `actor_animator`/`ms_*`); quedan en la raíz `pipeline/`, `export_godot/`, `Spellbook/`,
> `assets/` (sin referencias; Pablo las borra a mano) y la **cadena de `nivel_base`** + los hechizos 2D, que caen con la Fase 2 cuando el
> Juego cierre L2.1/L2.2. Pruebas: 5/7 en FALLOS 0; `prueba_agua_hechizos` y `prueba_canal_tinaja` fallan por las constantes que el Pipeline
> cambió el 12/10 (entradas 36, 37, 39), no por la reorganización. Lo que sigue de este documento se escribió antes de ejecutar y usa las rutas viejas donde habla del pasado.

Lo escribe el Juego a petición de Pablo. **Los movimientos no se han ejecutado todavía**: el Juego no tiene terminal en el PC de Pablo (solo
puede escribir archivos), así que los hace `tools/limpieza_mover.ps1` a mano de Pablo (§5). El análisis se hizo el 13/10
sobre el repo al día (`Documents\magic-symbols`, tras el pull): `main_scene` sigue siendo `Mundo.tscn` y
`prueba_test2.gd` sigue cargando `test_2.gd`.

## 1. Cómo se ha medido

No se ha juzgado archivo por archivo «a ojo». Se construyó el grafo de dependencias de todo el código
(`.gd`, `.tscn`, `.tres`, `project.godot`): una arista por cada `res://…` en escenas y recursos, por cada
`preload`/`load`/`extends "…"` y por cada uso de un `class_name` (palabra entera). Después se calculó qué es
**alcanzable desde las escenas 3D** (`poc_25d/Prueba*.tscn`, `Lab*.tscn`, `CatalogoAssets.tscn`) y qué solo desde
la escena principal 2D (`Mundo.tscn`, que sigue siendo `main_scene` en `project.godot`) o desde nada.

Resultado en cifras (solo la raíz del repo, el 2D):

| Grupo | Archivos | Qué son |
|---|---|---|
| **A. Muertos** | 26 | No los alcanza ninguna escena, ni 3D ni 2D |
| **B. Vivos solo por un hilo** | 41 | Los arrastra `test_2.gd` (que `extends nivel_base.gd`) o un comentario; el 3D no los ejecuta |
| **C. Usados por el 3D** | 37 | De estos, **11 están «arrastrados»** por referencias de tipo en archivos que sí se usan |
| **C′. Núcleo real** | 26 | Lo que el 3D usa de verdad: runas, sigilos, receta, grimorio, gestos, estado, objetos, playlog… |

En `poc_25d/` hay además copias de seguridad, escenas duplicadas y la prueba 2D prerenderizada.

El grafo (JSON) y el script que lo genera quedan en el adjunto `grafo_dependencias.json` / `grafo.py` para repetir la
medida tras un pull.

## 2. Catálogo, archivo por archivo

### 2.A — Muertos (ir a `_a_eliminar/2d_muertos/`)

Ninguna escena los carga. `Mundo.tscn` es la excepción: es la `main_scene` 2D; al moverla hay que cambiar
`project.godot` (Pablo, §5).

| Archivo | Por qué muere |
|---|---|
| `Mundo.tscn`, `mundo.gd` | Menú/escena principal del 2D |
| `TestJugabilidad.tscn`, `test_jugabilidad.gd`, `Test2.tscn` | Niveles 2D; su contenido vive hoy en `Nivel_Jugabilidad.tscn`, `Bosque.txt`… |
| `IsoTest.tscn`, `iso_test.gd`, `Blockout.tscn`, `blockout.gd` | Pruebas isométricas 2D previas al 3D |
| `ReactionLab.tscn`, `reaction_lab.gd`, `VfxLab.tscn`, `vfx_lab.gd`, `VfxLabMundo.tscn`, `vfx_lab_mundo.gd` | Laboratorios 2D (en 3D son `LabVfx3D`, `LabAgua3D`…) |
| `Brazier.tscn`, `brazier.gd`, `conductor.gd`, `prop.gd`, `progresion.gd` | Objetos y progresión 2D sin heredero |
| `node_2d.tscn`, `node_2d.gd`, `sprite_2d.gd`, `adventurer_visual_smoketest.(gd|tscn)` | Pruebas visuales de sprites |
| `cartografa_arcana.tres` (+ `cartografa_arcana.png`, 11 MB) | Fuente/atlas 2D; duplicado en `Sprites/` |

### 2.B — Vivos solo por un hilo (ir a `_a_eliminar/2d_nivel_base/` **después** del corte L2.1)

`prueba_test2.gd` hace `preload("res://test_2.gd")` solo para leer cinco constantes (`MAPA_TEST2`, `GUARDADOS_T2`,
`SUELO_T2`, `ROTULOS`, `COLOR_PRUEBA`). Pero `test_2.gd` `extends "res://nivel_base.gd"` (83 KB, el nivel 2D
entero), y ese archivo arrastra a todo el mundo 2D: jugador, enemigos, bloques, puertas, fogatas, misiones…
Cortado ese hilo (encargo Juego L2.1: sacar las cinco constantes a `mundo/datos_nivel/datos_test2.gd`), los 41 caen
de golpe:

`nivel_base.gd`, `test_2.gd`, `player.gd`, `enemy.gd`, `enemy.tscn`, `archer.gd`, `Archer.tscn`, `arrow.gd`, `Arrow.tscn`,
`goblin_guerrero.gd`, `goblin_arquero.gd`, `goblin_escarcha.gd`, `health_bar.gd`, `earth_block.gd`, `EarthBlock.tscn`,
`earth_builder.gd`, `grass_block.gd`, `GrassBlock.tscn`, `grass_blades.gd`, `grass_burn.gd`, `neutral_block.gd`,
`NeutralBlock.tscn`, `water_block.gd`, `WaterBlock.tscn`, `door.gd`, `fogata.gd`, `combustible.gd`, `circuit.gd`,
`electric_sparks.gd`, `goal.gd`, `Goal.tscn`, `level_controller.gd`, `misiones.gd`, `pantalla_muerte.gd`, `alquimia.gd`,
`reagente.gd`, `recolectable.gd`, `steam_rune.tres`.

Y los tres del pipeline de sprites 2D, que el 3D solo cita en comentarios: `actor_animator.gd`, `ms_actor.gd`,
`ms_atlas.gd` (son del **Pipeline**: los mueve él o lo autoriza).

### 2.C — Usados por el 3D: se quedan (de momento en la raíz)

**Núcleo real (26):** `runes.gd`, `rune_data.gd`, `sigils.gd`, `spell_recipe.gd`, `spellcaster.gd`, `spellbook.gd`,
`page_hud.gd`, `rune_palette.gd`, `bolsa_ui.gd`, `gesture_library.gd`, `gesture_library.tres`, `gesture_recognizer.gd`,
`estado.gd`, `objetos.gd`, `repertoire.gd`, `playlog.gd`, `sfx.gd`, `combate_comun.gd`, y los `.tres` de runa
(`fire`, `water`, `wind`, `earth`, `lightning`, `ice`, `time`). Más `art/ui/` (glifos y grimorio) y `audio/` (lo que `sfx.gd`
toca).

**Arrastrados (11), candidatos tras el corte L2.2:** `spell.gd`, `spell.tscn`, `spell_factory.gd`, `spell_form.gd`,
`spell_material.gd`, `spell_impact.gd`, `spell_beam.gd`, `glow.gd`, `block_fx.gd`, `iso_grid.gd`, `sonidos.gd`, `botin.gd`.
Están vivos solo por cinco referencias de nombre en archivos del núcleo:

| Archivo del núcleo | Referencia | Qué hacer (Juego, L2.2) |
|---|---|---|
| `spell_recipe.gd:421` | `SpellFactory.cast(...)` | Es el lanzamiento 2D; `Lanzador3D` no pasa por ahí. Mover esa función a `_a_eliminar` o protegerla tras `if Engine...`: mejor **borrarla** y dejar `SpellRecipe` como datos puros |
| `rune_data.gd:61` | `SpellBeam` (solo comentario) | Reescribir el comentario |
| `combate_comun.gd:184,197,299,302` | `BlockFx.burst`, `Sonidos.play`, `Botin.soltar` | `Combate3D` usa de `CombateComun` solo la tabla de debilidades (línea 252). Copiar la tabla a `combate_3d.gd` (o a un `tabla_combate.gd` sin nodo) y dejar de heredar |
| `sfx.gd`, `bolsa_ui.gd:137` | `Glow`, `BlockFx`, `Sonidos` | `Sonidos.play` sí se usa (bolsa): `sonidos.gd` se queda; `glow`/`block_fx` solo en comentario de `sfx.gd` |

### 2.D — Dentro de `poc_25d/`

| Archivo | Veredicto | Por qué |
|---|---|---|
| `niveles/jugabilidad_copia_20261007_115151.tscn`, `niveles/test2_copia_20261007_115221.tscn` | `_a_eliminar/3d_copias/` | Copias de seguridad del 7/10 (Git ya guarda el historial) |
| `niveles/jugabilidad.tscn`, `niveles/test2.tscn` | `_a_eliminar/3d_copias/` **si Pablo confirma** | Son el «camino A» de 6.10 (`_ruta_escena`: `niveles/<nivel>.tscn`), anterior a los `Nivel_<X>.tscn` horneados, que mandan si existen (`HorneadorNivel.existe_nivel`). Con `Nivel_Jugabilidad.tscn` y `Nivel_Test2.tscn` presentes, no se cargan |
| `niveles/nivel_Bosque.tscn` | **borrar** (ya pendiente de Pablo) | En Windows `existe_nivel` no distingue mayúsculas: choca con el futuro `Nivel_Bosque.tscn` |
| `PruebaJugabilidadBosque.tscn` (49 KB), `PruebaNivelBosque.tscn` (49 KB), `PruebaJugabilidadBosque_1.tscn` | `_a_eliminar/3d_copias/` **si Pablo confirma** | Escenas del Bosque anteriores a `PruebaBosque.tscn` + `Bosque.txt` (9.5). Las dos grandes llevan el nivel pegado dentro |
| `test2d/` (5 archivos + `generado/`, 195 ficheros) | `_a_eliminar/2d_prerender/` | Prueba de prerenderizar el 3D a 2D (6/10). Decisión tomada: 3D |
| `catalogo_assets.gd`, `CatalogoAssets.tscn`, `proporcion_chibi.gd` | se quedan (Pipeline) | Herramientas de revisión de piezas y proporciones |
| `_descartado/` (solo en el desktop) | `_a_eliminar/3d_descartado/` | El propio nombre lo dice |
| `herramientas/prueba_*.gd` | se quedan | Son las pruebas headless del agua, hielo, kit… |

### 2.E — Carpetas del Pipeline (decide el Pipeline; el Juego solo lo señala)

| Carpeta | Tamaño | Qué es | Propuesta |
|---|---|---|---|
| `art/` (menos `art/ui/`) | 69 PNG de sprites 2D (héroe, goblins, bloques, puente…) | Arte del 2D | `_a_eliminar/2d_arte/` |
| `Sprites/` | 11 MB | Hojas de sprites y atlas 2D | `_a_eliminar/2d_arte/` |
| `pipeline/`, `export_godot/`, `Render Studio/` (21,6 MB `.blend`) | Pipeline de sprites isométricos (Blender → atlas → `meta.json`) | Era el trabajo del Pipeline **antes** de Meshy | `_a_eliminar/2d_pipeline_sprites/`, o un repo aparte si se quiere conservar |
| `tools/gen_*.py`, `tools/video_a_fila.py`, `tools/empezar_prueba_iso.bat` | 15 scripts | Generadores de sprites y tiles 2D | `_a_eliminar/2d_pipeline_sprites/`; **`tools/podar_gestos.py` se queda** (Juego) |
| `tests/` | 18 archivos | Pruebas del `ActorAnimator` 2D | `_a_eliminar/2d_pipeline_sprites/` |
| `audio/` | 79 archivos | Lo usa `sfx.gd` → se queda | — |
| `Spellbook/`, `assets/` | `.gdignore` sueltos | Carpetas vacías | borrar |

## 3. Estructura de carpetas objetivo

Dos pasos: **ahora** solo aparece `_a_eliminar/`; la reorganización en capas se hace **con** la refactorización
(`ARQUITECTURA_MODULAR.md`), módulo a módulo y **con el editor de Godot** (Mover archivo), que reescribe las rutas
`res://` en escenas y recursos. Mover `.gd` a mano rompe los `preload("res://sigils.gd")` que hay por todo el código.

```
magic-symbols/
├── project.godot                  main_scene → escenas/PruebaBosque.tscn
├── nucleo/        datos puros sin nodo: Runes, RuneData, Sigils, SpellRecipe, Estado, Objetos, Repertoire, PlayLog, Sfx, gestos
├── mundo/         Terreno3D (casillas, alturas, bloqueos), AguaSim3D, estados del suelo, marcador_3d, pieza_3d, hornear_nivel, niveles/ y mapas/
├── magia/         Lanzador3D (grimorio + receta → Hechizo), GeometriaHechizo, formas_3d, efectos sobre el mundo
├── objetos/       Reactivo3D, surtidor, emisor de rayo, puente, enredadera, flotador, canal
├── enemigos/      Combate3D e IA
├── jugador/       Jugador3D, Pj3D, equipo_3d
├── presentacion/  Vfx3D, agua_render / ondas / metaballs, costra, hierba, ocluso, hilo_luz, HUD (spellbook, page_hud, bolsa_ui)
├── niveles/       reglas por nivel (Bosque3D, Jugabilidad3D, NivelPruebas) y las escenas Prueba*.tscn
├── laboratorios/  lab_*.gd/.tscn, catalogo_assets
├── herramientas/  pruebas headless (prueba_*.gd), generador_piezas, podar_gestos.py
├── arte/          piezas/, meshy/, modelos .glb y texturas, art/ui, audio/      (lo ordena el Pipeline)
├── docs/
└── _a_eliminar/   con .gdignore: Godot ni lo importa ni lo compila
    ├── LEEME.md               qué hay, por qué, y cuándo se borra
    ├── 2d_muertos/            §2.A
    ├── 2d_nivel_base/         §2.B (tras L2.1)
    ├── 2d_hechizos/           §2.C arrastrados (tras L2.2)
    ├── 2d_arte/  2d_pipeline_sprites/  2d_prerender/   §2.E y test2d
    └── 3d_copias/  3d_descartado/
```

**Por qué `_a_eliminar/` con `.gdignore` y no borrar:** (1) Pablo quiere una última revisión; (2) con `.gdignore`
Godot deja de importar esos archivos, así que desaparecen los `class_name` duplicados y los avisos de carga sin
perder nada; (3) `git mv` conserva el historial. Cuando Pablo dé el visto bueno, se borra la carpeta y listo.

## 4. Riesgos conocidos al mover

- **`main_scene`**: hoy es `res://Mundo.tscn`. Al moverla, Godot abre el proyecto con aviso y F5 no arranca nada.
  Cambiarla a `res://escenas/PruebaBosque.tscn` (archivo de Pablo).
- **`class_name` fuera de `.gdignore`**: si alguna de las carpetas se moviera sin el `.gdignore`, Godot seguiría
  registrando `Player`, `Enemy`, etc. y los `extends "res://nivel_base.gd"` fallarían con error de ruta. El script
  crea el `.gdignore` antes de mover.
- **Archivos `.uid` e `.import`**: van con su archivo (el script mueve `x.gd` + `x.gd.uid`, `x.png` + `x.png.import`).
- **El `.godot/` de caché**: tras mover, abrir el editor una vez y dejar que reimporte; si queda algún aviso de
  «uid duplicado», es la caché: cerrar y borrar `.godot/` lo arregla (Pablo).
- **Las escenas grandes del Bosque** (`PruebaJugabilidadBosque.tscn`, `PruebaNivelBosque.tscn`): el Juego no ha
  podido comprobar con ventana que no se usan para nada (p. ej. como referencia visual del Pipeline). Por eso van
  marcadas «si Pablo confirma».

## 5. Orden de ejecución

1. **Pablo** (en el desktop, repo al día y `git status` limpio): `git pull`, copiar `tools/limpieza_mover.ps1` y
   ejecutarlo. Mueve solo §2.A, §2.D copias y `test2d/`; crea `_a_eliminar/.gdignore` y `LEEME.md`. Cambiar
   `main_scene`. Abrir Godot, comprobar que `PruebaBosque.tscn` arranca y que las pruebas headless siguen en
   FALLOS 0. Commit «limpieza L1».
2. **Juego** L2.1 y L2.2 (cortar los hilos de §2.B y §2.C). Al terminar, Pablo ejecuta el script con `-Fase 2`.
3. **Pipeline** decide §2.E y `actor_animator`/`ms_*`; añade sus movimientos al script (`-Fase 3`) o los hace con
   el editor.
4. Reorganización por capas: va **dentro** de cada tarea de `ARQUITECTURA_MODULAR.md` (M1…M5), nunca como un
   «mover todo» aparte.
