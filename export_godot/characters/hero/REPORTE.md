# APROBADO: hero  (`hero`)

Fecha: 2026-10-02 20:08

## Archivos de entrada

- `charged_spell_cast_001.glb` -> **charged_spell_cast_001** (animacion nueva) | huesos 28, animaciones: Charged_Spell_Cast_1
- `charged_spell_cast_002.glb` -> **charged_spell_cast_002** (animacion nueva) | huesos 28, animaciones: Charged_Spell_Cast
- `idle_001.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_11
- `idle_002.glb` -> **idle** (nombre de archivo; variante -> animacion idle_002) | huesos 28, animaciones: Idle_4
- `idle_003.glb` -> **idle** (nombre de archivo; variante -> animacion idle_003) | huesos 28, animaciones: Swim_Idle
- `mage_soell_cast_001.glb` -> **mage_soell_cast_001** (animacion nueva) | huesos 28, animaciones: mage_soell_cast_5
- `mage_soell_cast_002.glb` -> **mage_soell_cast_002** (animacion nueva) | huesos 28, animaciones: mage_soell_cast_7
- `Meshy_AI_biped_Animation_BookWrite_withSkin.glb` -> **bookwrite** (animacion nueva) | huesos 28, animaciones: 01a0e933-0f4e-70fc-8103-a64fa1bd8be1, 01a0e933-0f4e-70fc-8103-a64fa1bd8be1.001
- `Meshy_AI_biped_Animation_Climb_Stairs_withSkin.glb` -> **climb_stairs** (animacion nueva) | huesos 28, animaciones: Climb_Stairs
- `Meshy_AI_biped_Animation_Collect_Object_withSkin.glb` -> **collect_object** (animacion nueva) | huesos 28, animaciones: Collect_Object
- `Meshy_AI_biped_Animation_Hit_Reaction_1_withSkin.glb` -> **hit_reaction** (animacion nueva) | huesos 28, animaciones: Hit_Reaction_1
- `Meshy_AI_biped_Animation_Hit_Reaction_to_Waist_withSkin.glb` -> **hit_reaction_to_waist** (animacion nueva) | huesos 28, animaciones: Hit_Reaction_to_Waist
- `Meshy_AI_biped_Animation_open_door_withSkin.glb` -> **open_door** (animacion nueva) | huesos 28, animaciones: open_door
- `Meshy_AI_biped_Animation_Roll_Dodge_1_withSkin.glb` -> **roll_dodge** (animacion nueva) | huesos 28, animaciones: Roll_Dodge_1
- `Meshy_AI_biped_Animation_Shot_in_the_Back_and_Fall_withSkin.glb` -> **shot_in_the_back_and_fall** (animacion nueva) | huesos 28, animaciones: Shot_in_the_Back_and_Fall
- `Meshy_AI_biped_Animation_Swim_Forward_withSkin.glb` -> **swim_forward** (animacion nueva) | huesos 28, animaciones: Swim_Forward
- `run_001.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `run_002.glb` -> **run** (nombre de archivo; variante -> animacion run_002) | huesos 28, animaciones: Run_Turn_Right
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walk_Turn_Right

## Avisos

- 3 archivos para 'idle': renombrados idle_001.glb -> idle_001.glb, idle_002.glb -> idle_002.glb, idle_003.glb -> idle_003.glb. 'idle' = idle_001.glb; el resto son animaciones idle_002, idle_003...
- 2 archivos para 'walk': renombrados walk_001.glb -> walk_001.glb, walk_002.glb -> walk_002.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- 2 archivos para 'run': renombrados run_001.glb -> run_001.glb, run_002.glb -> run_002.glb. 'run' = run_001.glb; el resto son animaciones run_002, run_003...
- 2 animaciones parecidas 'charged_spell_cast': charged_spell_cast_001.glb -> charged_spell_cast_001, charged_spell_cast_002.glb -> charged_spell_cast_002
- 2 animaciones parecidas 'mage_soell_cast': mage_spell_cast_001.glb -> mage_soell_cast_001, mage_spell_cast_002.glb -> mage_soell_cast_002
- Animaciones nuevas: bookwrite, charged_spell_cast_001, charged_spell_cast_002, climb_stairs, collect_object, hit_reaction, hit_reaction_to_waist, mage_soell_cast_001, mage_soell_cast_002, open_door, roll_dodge, shot_in_the_back_and_fall, swim_forward
- Animacion OMITIDA 'walk_002': root motion horizontal 1.743269 excede tolerancia 0.010000
- Animacion OMITIDA 'run_002': root motion horizontal 2.266189 excede tolerancia 0.010000
- Animacion OMITIDA 'roll_dodge': S: Alpha toca un borde del frame (clipping); S: Margen mínimo 0px < requerido 4px
- Animacion OMITIDA 'shot_in_the_back_and_fall': NW: Alpha toca un borde del frame (clipping); NW: Margen mínimo 0px < requerido 4px
- Animacion OMITIDA 'swim_forward': S: Alpha toca un borde del frame (clipping); S: Margen mínimo 0px < requerido 4px

## Validaciones

- OK  animation_audit.json
- OK  bookwrite_atlas_validation.json
- OK  bookwrite_render_validation.json
- OK  charged_spell_cast_001_atlas_validation.json
- OK  charged_spell_cast_001_render_validation.json
- OK  charged_spell_cast_002_atlas_validation.json
- OK  charged_spell_cast_002_render_validation.json
- OK  climb_stairs_atlas_validation.json
- OK  climb_stairs_render_validation.json
- OK  collect_object_atlas_validation.json
- OK  collect_object_render_validation.json
- OK  hit_reaction_atlas_validation.json
- OK  hit_reaction_render_validation.json
- OK  hit_reaction_to_waist_atlas_validation.json
- OK  hit_reaction_to_waist_render_validation.json
- OK  idle_002_atlas_validation.json
- OK  idle_002_render_validation.json
- OK  idle_003_atlas_validation.json
- OK  idle_003_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  mage_soell_cast_001_atlas_validation.json
- OK  mage_soell_cast_001_render_validation.json
- OK  mage_soell_cast_002_atlas_validation.json
- OK  mage_soell_cast_002_render_validation.json
- OK  model_rig_validation.json
- OK  open_door_atlas_validation.json
- OK  open_door_render_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 15

## Arte: APROBADO

- OK    E2E (bake + materiales + GLB limpio): exit 0; QA QA_OK; 
- OK    Render 8 direcciones: exit 0; informe 8/8; PNG en disco: 8 (esperadas 8)
- OK    Aislamiento del personaje: ISOLATION_OK
- OK    Camara: OK
- OK    Sin recortes (clipping): {"left": false, "right": false, "top": false, "bottom": false}
- OK    Ancla al suelo: 0.0 px (max 8.0)
- OK    Alfa (agujeros / parcial): dentro de umbrales
- OK    Direcciones cardinales distintas: S/E/N/W se diferencian

Hojas para revisar a ojo:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\hero\art\review`

- AVISO: '01a0e9330f4e70fc8103A64fa1bd8be1' pasa de 84 a 105 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Bookwrite' pasa de 84 a 105 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ChargedSpellCast001' pasa de 104 a 130 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ChargedSpellCast002' pasa de 65 a 81.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ClimbStairs' pasa de 71 a 88.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'CollectObject' pasa de 144 a 180 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'HitReaction' pasa de 29 a 36.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'HitReactionToWaist' pasa de 40 a 50 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 45 a 56.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle002' pasa de 336 a 420 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle003' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'MageSoellCast001' pasa de 273 a 341.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'MageSoellCast002' pasa de 65 a 81.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'OpenDoor' pasa de 125 a 156.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'RollDodge' pasa de 31 a 38.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Run002' pasa de 39 a 48.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ShotInTheBackAndFall' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SwimForward' pasa de 108 a 135 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 53 a 66.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/hero/`  |  Config: `pipeline/characters/hero/character.json`
