# APROBADO: goblin_archer_chibi  (`goblin_archer_chibi`)

Fecha: 2026-10-05 20:55 (cabecera corregida a mano por QA: el build directo y la fase de arte no reescriben este archivo)

## Por que

- build_character.py (lanzado directo, sin ingesta) termino BUILD VALID: 8 animaciones, 2297 s (log: `C:\Users\paranda\Documents\magic-symbols\pipeline\inbox\_logs\goblin_archer_chibi_20261005_180318.log`)
- Fase de arte: APROBADO (`pipeline_output\goblin_archer_chibi\art_stage.log`)

## Archivos de entrada

- `idle_001.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_03
- `idle_002.glb` -> **idle** (nombre de archivo; variante -> animacion idle_002) | huesos 28, animaciones: Idle_8
- `Meshy_AI_Hooded_Goblin_Scout_biped_Animation_Archery_Shot_withSkin.glb` -> **archery_shot** (animacion nueva) | huesos 28, animaciones: Archery_Shot
- `Meshy_AI_Hooded_Goblin_Scout_biped_Animation_Dead_withSkin.glb` -> **dead** (animacion nueva) | huesos 28, animaciones: Dead
- `Meshy_AI_Hooded_Goblin_Scout_biped_Animation_Electrocution_Reaction_withSkin.glb` -> **electrocution_reaction** (animacion nueva) | huesos 28, animaciones: Electrocution_Reaction
- `Meshy_AI_Hooded_Goblin_Scout_biped_Animation_Hit_Reaction_1_withSkin.glb` -> **hit_reaction** (animacion nueva) | huesos 28, animaciones: Hit_Reaction_1
- `Meshy_AI_Hooded_Goblin_Scout_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walk_Backward_with_Bow_1_inplace

## Avisos

- 2 archivos para 'idle': 'idle' = idle_001.glb; el resto son animaciones idle_002, idle_003...
- 2 archivos para 'walk': 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003... (walk_002 es el andar hacia atras con arco: el Juego lo espera como `walk_back`)
- Animaciones nuevas: archery_shot, dead, electrocution_reaction, hit_reaction
- Animacion DESACTIVADA 'dead': se desplaza 1.30 altos de cadera y se sale del encuadre. No se ha renderizado.
- Fase de arte: todos los clips salen x1.25 frames en el GLB de arte (escena E2E a 30 fps); no afecta a los atlas, que salen del master.

## Validaciones

- idle: PASS (16 frames/dir, 8 dir, 96/96 regiones)
- walk: PASS (8 frames/dir)
- run: PASS (8 frames/dir)
- idle_002: PASS (16 frames/dir)
- walk_002: PASS (8 frames/dir)
- archery_shot: PASS (12 frames/dir)
- electrocution_reaction: PASS (12 frames/dir)
- hit_reaction: PASS (12 frames/dir)

Atlas generados: 8

## Arte

- APROBADO (art_stage.log, 2026-10-05 20:5x). Hojas de revision en `pipeline_output\goblin_archer_chibi\`.

Salida: `pipeline_output/goblin_archer_chibi/`  |  Config: `pipeline/characters/goblin_archer_chibi/character.json`
