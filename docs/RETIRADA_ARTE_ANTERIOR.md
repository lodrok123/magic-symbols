# Retirar la visión de arte anterior (5 de octubre de 2026)

Decidido por Pablo: **la elfa chibi es el canon** y `PruebaTest2` es el lockeo de arte. Esto es el plan
para quitar todo lo que venía de las direcciones anteriores (Sketch Town, maga sacada de vídeo, héroe
realista de Meshy, hojas cel 2D, pintado 2D de `art/`) sin perder lo que sigue sirviendo.

## 0. La decisión que falta y que cambia el 40 % de este plan

**¿El juego pasa a ser la maqueta 3D, o el juego 2D sigue y la maqueta es "solo arte"?**

| | si el juego es 3D (`PruebaTest2` crece hasta ser el juego) | si el juego sigue 2D (atlas de 8 direcciones) |
|---|---|---|
| `export_godot/` (atlas, losas 128×64) | legado entero | se **regenera** con los modelos chibi: el pipeline es el mismo, cambia el modelo |
| `MsAtlas`/`MsActor`, `nivel_base` (dibujo), `*_block.gd` (sprites) | legado | se quedan |
| `art/` 2D (hielo, tótems, puesto, puente…) | legado | se sustituye pieza a pieza por render de los modelos chibi (fase 3 del plan de homogeneización) |
| `pipeline/` render a atlas | se queda solo para NPC lejanos o se para | núcleo |

Lo que sigue es **común a los dos casos**; donde difiere, se marca [3D] o [2D]. Recomendación de QA: no
borrar nada hasta tomar esta decisión; mientras, **cuarentena** (mover a `_legado/` con `.gdignore`, fuera
de la importación de Godot y del peso del editor, pero recuperable y en git).

## 1. Inventario: conservar / adaptar / retirar

### Conservar (vale tal cual con el chibi)
| qué | por qué |
|---|---|
| `pipeline/` entero (inbox → build → arte → export), `Render Studio/`, `profiles/`, `schemas/` | es independiente del modelo: ya ha procesado `chibi_elf`, `bookseller_chibi`, `goblin_warrior_chibi` |
| `poc_25d/` (menos lo de `ORDENAR_POC.cmd`) | es el lockeo |
| `docs/ARTE.md` §1 (colores de elemento) y §2 (paletas de bioma) | son del juego, no del estilo de dibujo; los VFX nuevos ya los siguen |
| `docs/referencia_personaje.png` | sigue siendo la referencia de la elfa (el chibi sale de ella); **falta** actualizarla con el color decidido (vestido verde azulado del master) |
| `art/ui/` (grimorio, glifos, barras, paneles), `art/particles/`, `art/recogibles/` | interfaz y partículas: no pisan la rejilla; el grimorio 3D del POC los sustituirá cuando exista |
| `audio/`, `gesture_library.tres`, `*_rune.tres`, todo el núcleo de hechizos | no es arte |
| `tools/podar_gestos.py`, `tools/subir_a_github.bat`, `tools/godot_ruta.txt`, `Godot_v4.7.2…exe` | herramientas vivas |
| `docs/guia_arte.png` | **con nota**: la guía era "fantasía pintada oscura"; el lockeo es "chibi pastel". Se conserva por las paletas y los VFX por elemento, no como dirección de personajes |

### Adaptar (útil, pero hay que tocarlo)
| qué | qué cambiar | quién |
|---|---|---|
| `export_godot/characters/{hero, goblin_warrior, goblin_archer, master_elf, ranger_human, bookseller_woman}` | [2D] regenerar desde los modelos chibi (`chibi_elf`, `goblin_warrior_chibi`, `bookseller_chibi`; faltan arquero y alquimista chibi). [3D] legado | Pipeline (render), Pablo (modelos que faltan) |
| `export_godot/terrain/bosque_01` (hojas cel) | [2D] renderizar losas y props desde el kit 3D del POC con la misma luz (plan de homogeneización, fase 2). [3D] legado | Pipeline |
| `docs/ARTE.md` §3–§8 | §3 (contrato de hoja 64×64) y §4 (maga de vídeo) son historia; §5–§8 reescribir para el chibi/3D | Pipeline (propuesta), Pablo (integra) |
| `docs/ASSETS_PENDIENTES.md` | reescribir en términos de modelos chibi, no de PNG 2D | Juego pide, Pipeline entrega |
| `docs/CONTEXTO.md` "Arte" y "Personaje" | decir que el canon es `chibi_elf` y que `art/` está en retirada | Pablo |
| `docs/PROPIETARIOS.md` | añadir `poc_25d/` (dueño), `_legado/` (nadie edita), los docs nuevos de QA | Pablo |
| `ms_atlas.gd` `frames_heroe()` | [2D] `ID_HEROE = "chibi_elf"` y `escala_relativa` en su meta | Pipeline |
| `nivel_base.gd` rutas `art/*` (`PUESTO_ART`, `BOSQUE_ART`, `EMPUJABLE_ART`, `GUARDADO_ART`, puente, piedras, fogata) | [2D] cambiar a lo renderizado del kit 3D por tandas; [3D] legado | Juego |

### Retirar (nada lo usa, o lo usará lo chibi)
| qué | tamaño aprox. | nota |
|---|---|---|
| `art/maga_*.png`, `art/rita_*.png`, `art/hero_*.png`, `art/hero.png` | ~3 MB | maga de vídeo y hojas 64×64 del animador antiguo |
| `actor_animator.gd`, `adventurer_visual_smoketest.*`, `node_2d.*`, `sprite_2d.gd`, `Sprites/` | | el animador antiguo y sus pruebas |
| `videos/`, `tools/video_a_fila.py`, `tools/gen_hero_sheets.py`, `tools/gen_actor.py`, `tools/gen_walk.py`, `docs/ANIMACION.md`, `docs/PERSONAJE.md`, `docs/referencia_direcciones.png`, `docs/referencia_idle_fuente.png`, `docs/rita_fuente.png`, `docs/personaje_ancla.png` | | la vía "personaje de vídeo" |
| `tools/gen_floor.py`, `gen_iso_tiles.py`, `gen_tiles_pintadas.py`, `gen_props.py`, `gen_props_bosque.py`, `gen_enemies.py`, `gen_fx.py`, `gen_fire_tiers.py`, `tools/empezar_prueba_iso.bat` | | generadores de Sketch Town / placeholders |
| `art/floor*.png`, `grass*.png`, `water*.png`, `earth.png`, `ground.png`, `prop_*.png`, `art/forest/` (Sketch Town 2x), `art/fx/` (VFX viejos), `art/archer*`, `goblin_*`, `warrior.png`, `enemy.png`, `arrow.png`, `goal.png`, `shadow.png`, `brazier.png`, `conductor.png`, `door_*.png` | ~2 MB | **[2D] solo cuando `nivel_base`/`prop.gd`/`block_fx.gd`/`fogata.gd` dejen de cargarlos**; hoy los cargan (`grep res://art/`: 10 sitios en `nivel_base.gd`, 5 en `block_fx.gd`, 3 en `prop.gd`, 3 en `fogata.gd`, 2 en `player.gd`, 2 en `grass_block.gd`, 4 `.tscn`) |
| `art/hielo_*`, `empujable_*`, `bosque/`, `puente_*`, `piedras_*`, `baldosa*`, `placa.png`, `puesto.png`, `fogata_*` (el pintado de la semana pasada) | ~2 MB | igual: tras cambiar rutas |
| `tools/BRRRR…mp4/.zip`, `Ejemplo de propagación de fuego.mp4` | **69 MB** | vídeos sueltos dentro de `tools/` |
| `cartografa_arcana.png` (11 MB) + `.tres` | 11 MB | arte de la pantalla de mapa antigua; comprobar que nadie lo carga (`grep cartografa`) |
| `pipeline/characters/{hero, hero_v2, chibi_test}`, `pipeline_output/{hero, hero_v2, chibi_test, ranger*, master_elf, bookseller_woman}` | cientos de MB | modelos realistas y el chibi de prueba; con los logs de `inbox/_logs` que no sean de un chibi |
| `poc_25d/_descartado/` (tras `ORDENAR_POC.cmd`) | ~110 MB | pruebas A–E y modelos viejos |
| `IsoTest.tscn`, `iso_test.gd`, `Blockout.tscn`, `blockout.gd`, `ReactionLab.tscn`, `reaction_lab.gd` | | [3D] laboratorios 2D antiguos; [2D] revisar: `prop.gd` (las negativas de la maga) solo vive en Blockout/IsoTest |
| `gesture_library.tres.bak`, `Documents.lnk`, `pipeline.lnk` | | basura de raíz (ya en el plan de arreglos 0.4) |

## 2. Fases

| fase | qué | quién | cuándo |
|---|---|---|---|
| **0 · Decidir 2D/3D** (§0) y fijar el color canon de la elfa (vestido verde azulado del master; actualizar `referencia_personaje.png`) | — | Pablo | ya |
| **1 · Cuarentena** (sin romper nada): crear `_legado/` con `.gdignore` y mover ahí todo lo de "Retirar" que **ningún script carga** (maga/rita/hero sheets, animador antiguo, vídeos, generadores, `cartografa_arcana` si nadie lo usa, modelos realistas de `pipeline/`); `ORDENAR_POC.cmd` para el POC. Un `.cmd` como el del POC, con Godot cerrado | Pablo ejecuta; QA escribe el `.cmd` | esta semana |
| **2 · Docs**: notas de retirada en `ARTE.md`, `CONTEXTO.md`, `ASSETS_PENDIENTES.md`, `PROPIETARIOS.md` | Pipeline propone, Pablo integra | esta semana |
| **3 · [2D] Regenerar `export_godot/characters` con los chibi** y `ID_HEROE`; [3D] marcar `export_godot/characters` como legado | Pipeline | tras fase 0 |
| **4 · [2D] Cambiar rutas de `art/` en `nivel_base`, `prop`, `block_fx`, `fogata`, `player`, `grass_block` y los 4 `.tscn`** hacia el kit 3D renderizado; mover `art/` (menos `ui/`, `particles/`, `recogibles/`) a `_legado/`. [3D] mover `art/` entero menos `ui/` | Juego (rutas), Pipeline (renders) | por tandas |
| **5 · Borrado** de `_legado/` cuando lleve dos semanas sin que nadie lo eche en falta; git conserva la historia | Pablo | +2 semanas |

## 3. Lo que NO se retira aunque parezca viejo
- `IsoGrid` y el contrato de losas 128×64 / cara en y=33: [2D] siguen siendo la rejilla; [3D] la maqueta
  usa `S = 2,3` y bloques `ALTO = S×0,45`, que es otra rejilla; convendrá que las dos compartan proporción
  (2:1) para que un nivel se lea igual en ambas.
- `gesture_recognizer`, `sigils`, `spell_recipe`, `spellbook` (UI): el núcleo; en 3D se portan, no se retiran.
- `docs/QA_ARTE.md`, `PLAN_HOMOGENEIZAR_ARTE.md`, `EXPERIMENTOS_ESTILO.md`: ya cumplieron (la decisión
  está tomada); se cierran con una nota "superado por el lockeo chibi del 5/10" y se dejan como historia.
