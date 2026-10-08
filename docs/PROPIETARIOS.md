# Propietarios — quién toca qué

El proyecto lo desarrollan **dos contextos en paralelo** (dos proyectos de
Claude, a veces en máquinas distintas): el de **Juego** (jugabilidad, runas,
niveles) y el de **Pipeline** (arte, sprites isométricos, exportación a
Godot). Este archivo dice qué archivos posee cada uno y dónde se encuentran.

> **Regla de oro: un archivo tiene UN propietario.** Si una tarea pide tocar
> un archivo que no es tuyo, **no lo edites**: para, di qué cambio hace falta
> y en qué archivo, y Pablo se lo pasa al otro contexto o lo hace él.

Esto existe porque ya pasó: un contexto reescribió `test_jugabilidad.gd`
entero desde una copia vieja y se perdieron los ganchos que `nivel_base.gd`
necesitaba. `Mundo.tscn` y `Test2.tscn` dejaron de arrancar.

---

## 1. Juego (proyecto "Juego 2D con sistema de runas")

**Posee**

| Qué | Archivos |
|---|---|
| Runas y hechizos | `spell*.gd`, `spellcaster.gd`, `spellbook.gd`, `sigils.gd`, `rune_*.gd`, `runes.gd`, `gesture_*.gd`, `gesture_library.tres`, `*_rune.tres` |
| Mundo que reacciona | `*_block.gd`, `*Block.tscn`, `earth_builder.gd`, `grass_*.gd`, `block_fx.gd`, `prop.gd`, `door.gd`, `brazier.gd`, `fogata.gd`, `combustible.gd`, `circuit.gd`, `conductor.gd`, `recolectable.gd`, `reagente.gd`, `poc_25d/emisor_rayo_3d.gd` (emisor de rayo ambiental: pieza aprobada por Pablo el 8/10, diseño pendiente; su letra de marcador la añade el Pipeline en `marcador_3d.gd`) |
| Jugador y enemigos | `player.gd`, `enemy.gd`, `enemy.tscn`, `archer.gd`, `arrow.gd`, `goblin_*.gd`, `combate_comun.gd`, `health_bar.gd` |
| Sistemas de partida | `estado.gd`, `objetos.gd`, `botin.gd`, `bolsa_ui.gd`, `alquimia.gd`, `misiones.gd`, `progresion.gd`, `repertoire.gd`, `pantalla_muerte.gd`, `page_hud.gd`, `playlog.gd`, `level_controller.gd`, `goal.gd`, `sonidos.gd`, `sfx.gd` |
| Niveles | `test_jugabilidad.gd`, `nivel_base.gd`, `test_1.gd`, `test_2.gd`, `mundo.gd`, `vfx_lab*.gd`, `blockout.gd`, `iso_test.gd`, `iso_grid.gd`, `reaction_lab.gd` y sus `.tscn` |
| Documentación | `docs/NUEVOS_SISTEMAS.md`, `docs/TEST2_CONCLUSIONES.md`, `docs/QA_ARTE.md` (lo escribió el Juego; lo que pide al Pipeline va por el diario) |
| Herramientas | `tools/podar_gestos.py` |

**No toca**: nada de la sección 2. En particular **no edita `ms_atlas.gd`
ni `ms_actor.gd`**: si necesita otra animación, otro clip o otro dato del
`meta.json`, lo apunta en `docs/ASSETS_PENDIENTES.md` (sección 0, "Urgente")
y mientras tanto usa un clip que exista.

---

## 2. Pipeline (proyecto "pipeline sprite isométricos")

**Posee**

| Qué | Archivos |
|---|---|
| Pipeline 3D → sprites | `pipeline/` entero (inbox, config, profiles, tools, `.cmd`, `catalogo.json`) |
| Lo exportado a Godot | `export_godot/` entero (`characters/`, `terrain/`, `demo/`, `meta.json`, atlas) |
| Lectura en Godot | `ms_atlas.gd`, `ms_actor.gd`, `actor_animator.gd`, `addons/` |
| Arte 2D y herramientas | `art/`, `assets/`, `Sprites/`, `Render Studio/`, `videos/`, `tools/` (`gen_*.py`, `video_a_fila.py`), **salvo `tools/podar_gestos.py`, que es del Juego** |
| Pruebas visuales | `tests/`, `adventurer_visual_smoketest.*`, `node_2d.*`, `sprite_2d.gd` |
| Documentación | `docs/ARTE.md`, `docs/ANIMACION.md`, `docs/PERSONAJE.md`, `docs/ASSETS_PENDIENTES.md`, `docs/*.png` (referencias) |

**No toca**: ningún `.gd` de la sección 1 ni las escenas de nivel. Si un
sprite nuevo necesita que el juego lo use (otro `id`, otro clip, otro
`ancla_suelo_px`), lo publica en `export_godot/<tipo>/<id>/meta.json` y lo
anota en el diario (sección 5); el Juego lo adopta desde su lado.

---

## 3. Archivos de Pablo (nadie los edita sin que lo pida)

| Archivo | Por qué |
|---|---|
| `project.godot`, `.gitignore`, `.gitattributes` | Configuración de todo el proyecto |
| `README.md`, `ARQUITECTURA.md`, `docs/CONTEXTO.md`, `docs/DISENO_FUTURO.md`, `docs/PLAN_ARREGLOS.md`, este archivo | Son la fuente de verdad para los dos contextos; si cada uno los reescribe, dejan de serlo |
| `.godot/`, `*.import`, `*.uid` | Los genera Godot; se tocan abriendo el editor, no a mano |

Si un contexto cree que uno de estos debe cambiar (p. ej. `main_scene`),
**lo propone** con el cambio exacto y Pablo lo aplica.

---

## 4. La frontera: contratos, no ganchos

Los dos contextos solo se encuentran a través de **datos**, nunca editando
el mismo archivo:

| Contrato | Lo escribe | Lo lee | Dónde está definido |
|---|---|---|---|
| `meta.json` + atlas por animación (8 filas, `frame_px`, `ancla_suelo_px`, `offset_visual_px`, `mapeo_direcciones_godot`) | Pipeline | Juego, vía `MsAtlas`/`MsActor` | `export_godot/CONTRATO_GODOT.md` |
| API de `MsAtlas` / `MsActor` (`meta()`, `tiene()`, `fps()`, `en_bucle()`, `frames()`…) | Pipeline | Juego | Las firmas de esas funciones **no cambian sin aviso en el diario** |
| Losas de terreno 128×64, cara superior en `y = 33` | Pipeline | Juego (`IsoGrid`, bloques) | `docs/ASSETS_PENDIENTES.md`, cabecera |
| Props 2D a 2x, ancla en el centro de la base | Pipeline | Juego (`prop.gd`, `Prop.CATALOGO`) | `docs/ASSETS_PENDIENTES.md`, cabecera |
| Colores de elemento | Pipeline | Juego | `docs/ARTE.md` §1 |
| Lista de assets que faltan | **Juego** pide, Pipeline entrega | Pipeline | `docs/ASSETS_PENDIENTES.md` |

**Cambiar un contrato es un cambio de los dos lados**: quien lo necesite lo
propone en el diario, Pablo lo aprueba, y cada contexto adapta lo suyo.

---

## 5. Reglas de edición (para los dos)

1. **Leer del disco antes de editar.** El archivo puede haber cambiado desde
   la última vez que lo viste (otro contexto, otra máquina, Godot).
2. **Cambios parciales, nunca reescribir el archivo entero** desde una copia
   que tengas en memoria o en la conversación. Si hace falta reescribir
   mucho, primero releer y después editar por trozos.
3. **Comprobar la ruta antes de escribir.** La carpeta de trabajo es
   `C:\Users\pablo\Documents\magic-symbols` (en cualquiera de sus
   ordenadores). Si la carpeta conectada es otra (p. ej. la copia vieja de
   `OneDrive\Documentos\magic-symbols`), decirlo y no escribir.
4. **No commitear ni hacer push.** Lo hace Pablo con `SUBIR_A_GITHUB.cmd` / `BAJAR_DE_GITHUB.cmd`. Ningún archivo de más de 95 MB entra en el repo (`.gitignore`).
5. **Diario.** Al terminar una sesión que haya tocado un contrato o algo que
   el otro contexto necesite saber, añadir 2-4 líneas al final de
   `docs/DIARIO.md`: fecha, contexto, qué cambió, qué le hace falta al otro.
   Al empezar una sesión, leer las últimas entradas.

---

## 6. Qué hacer cuando no está claro

- Un archivo que no aparece en ninguna lista → **preguntar**, no asumir.
- Un archivo de **código o escena** nuevo → lo posee quien lo crea;
  añadirlo a este documento.
- Un **documento** nuevo en `docs/` → **no se crea sin proponerlo** (ver 7).
- Una tarea que de verdad necesita tocar los dos lados (p. ej. un clip nuevo
  del héroe + que `player.gd` lo use) → se parte en dos: primero el Pipeline
  publica el `meta.json`, luego el Juego lo consume. Nunca una sola sesión
  haciendo las dos cosas.

---

## 7. Documentos: uno de cada, no uno por sesión

El 5/10/2026 aparecieron doce documentos nuevos en `docs/` en un día, cuatro
de ellos planes paralelos a `PLAN_ARREGLOS.md` y uno duplicando
`ASSETS_PENDIENTES.md`. Un documento que nadie integra es deuda: el siguiente
chat no sabe cuál manda.

**Los documentos vivos son estos, y solo estos:**

| documento | para qué | dueño |
|---|---|---|
| `ARQUITECTURA.md` | lo que el código hace hoy | Pablo |
| `docs/DISENO_FUTURO.md` | lo que se quiere, con prioridad P0–P3 | Pablo |
| `docs/PLAN_ARREGLOS.md` | **el único plan**: tareas, responsable, casilla | Pablo |
| `docs/DIARIO.md` | lo que un contexto le dice al otro | los dos escriben |
| `docs/CONTEXTO.md`, este archivo | reglas | Pablo |
| `docs/NUEVOS_SISTEMAS.md`, `docs/TEST2_CONCLUSIONES.md`, `docs/QA_ARTE.md` | referencia del Juego | Juego |
| `docs/ASSETS_PENDIENTES.md`, `docs/ARTE.md`, `export_godot/CONTRATO_GODOT.md` | referencia del Pipeline | Pipeline |
| `docs/ESTADOS_SUELO.md` | contrato de reglas del suelo entre 2D y la maqueta 3D | Juego escribe, Pipeline lee |
| `poc_25d/LEEME.md` | estado de la maqueta 3D | Pipeline |
| `docs/Playtests/` | un archivo por sesión de juego, solo conclusiones | Pablo |

**Regla.** Un contexto **no crea** un documento nuevo en `docs/`. Si cree que
hace falta, lo propone en el diario (nombre, dueño, qué no cabía en los
existentes) y lo crea Pablo o quien él diga. Una tarea va al plan; una idea,
a diseño futuro; un hallazgo medido, a `QA_ARTE` o `TEST2_CONCLUSIONES`; una
guía de implementación, dentro de la tarea del plan que la necesita (o como
sección de `DISENO_FUTURO`). Los documentos de hoy que no están en la tabla
(`ASSETS_FALTANTES`, `CAMBIOS_JUEGO_PENDIENTES`, `ENCARGO_JUEGO_ESTADOS`,
`EXPERIMENTOS_ESTILO`, `HIERBA_OPTIMIZACION`, `IMPLEMENTAR_TECNICAS`,
`PLAN_ACCION_TEST2`, `PLAN_HOMOGENEIZAR_ARTE`, `PLAN_PASTEL`,
`RETIRADA_ARTE_ANTERIOR`, `TECNICAS_APLICABLES`) se integran en los de la
tabla por su dueño y se borran; hasta entonces son **borradores**, no fuente
de verdad.

**Firmas del diario.** Solo hay dos contextos: `Juego` y `Pipeline`. Una
sesión del Juego que hace control de calidad firma `Juego`, no `QA/Juego`.
