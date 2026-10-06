# APROBADO: goblin_warrior_chibi  (`goblin_warrior_chibi`)

Fecha: 2026-10-05 03:55

## Archivos de entrada

- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Die_withSkin.glb` -> **die** (animacion nueva) | huesos 28, animaciones: Shot_in_the_Back_and_Fall
- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Electrocution_Reaction_withSkin.glb` -> **electrocution_reaction** (animacion nueva) | huesos 28, animaciones: Electrocution_Reaction
- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Hit_Reaction_withSkin.glb` -> **hit_reaction** (animacion nueva) | huesos 28, animaciones: Hit_Reaction
- `idle_001.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_03
- `idle_002.glb` -> **idle** (nombre de archivo; variante -> animacion idle_002) | huesos 28, animaciones: Idle_8
- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Left_Slash_withSkin.glb` -> **left_slash** (animacion nueva) | huesos 28, animaciones: Left_Slash
- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_Gribble_the_Goblin_biped_Animation_Slap_Reaction_withSkin.glb` -> **slap_reaction** (animacion nueva) | huesos 28, animaciones: Slap_Reaction
- `sword_parry_backward_001.glb` -> **sword_parry_backward_001** (animacion nueva) | huesos 28, animaciones: Sword_Parry_Backward_1
- `sword_parry_backward_002.glb` -> **sword_parry_backward_002** (animacion nueva) | huesos 28, animaciones: Sword_Parry_Backward
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walk_Backward_with_Sword_inplace
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking

## Avisos

- 2 archivos para 'idle': renombrados Meshy_AI_Gribble_the_Goblin_biped_Animation_Idle_03_withSkin.glb -> idle_001.glb, Meshy_AI_Gribble_the_Goblin_biped_Animation_Idle_8_withSkin.glb -> idle_002.glb. 'idle' = idle_001.glb; el resto son animaciones idle_002, idle_003...
- 2 archivos para 'walk': renombrados Meshy_AI_Gribble_the_Goblin_biped_Animation_Walking_withSkin.glb -> walk_001.glb, Meshy_AI_Gribble_the_Goblin_biped_Animation_Walk_Backward_with_Sword_inplace_withSkin.glb -> walk_002.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- 2 animaciones parecidas 'sword_parry_backward': Meshy_AI_Gribble_the_Goblin_biped_Animation_Sword_Parry_Backward_1_withSkin.glb -> sword_parry_backward_001, Meshy_AI_Gribble_the_Goblin_biped_Animation_Sword_Parry_Backward_withSkin.glb -> sword_parry_backward_002
- Animaciones nuevas: die, electrocution_reaction, hit_reaction, left_slash, slap_reaction, sword_parry_backward_001, sword_parry_backward_002
- Animacion OMITIDA 'die': S: Alpha toca un borde del frame (clipping); S: Margen mínimo 0px < requerido 4px

## Validaciones

- OK  animation_audit.json
- OK  electrocution_reaction_atlas_validation.json
- OK  electrocution_reaction_render_validation.json
- OK  hit_reaction_atlas_validation.json
- OK  hit_reaction_render_validation.json
- OK  idle_002_atlas_validation.json
- OK  idle_002_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  left_slash_atlas_validation.json
- OK  left_slash_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  slap_reaction_atlas_validation.json
- OK  slap_reaction_render_validation.json
- OK  sword_parry_backward_001_atlas_validation.json
- OK  sword_parry_backward_001_render_validation.json
- OK  sword_parry_backward_002_atlas_validation.json
- OK  sword_parry_backward_002_render_validation.json
- OK  walk_002_atlas_validation.json
- OK  walk_002_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 11

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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior_chibi\art\review`

- AVISO: 'Die' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ElectrocutionReaction' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'HitReaction' pasa de 40 a 50 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 103 a 128.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle002' pasa de 192 a 240 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'LeftSlash' pasa de 77 a 96.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SlapReaction' pasa de 116 a 145 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SwordParryBackward001' pasa de 33 a 41.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SwordParryBackward002' pasa de 32 a 40 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 32 a 40 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/goblin_warrior_chibi/`  |  Config: `pipeline/characters/goblin_warrior_chibi/character.json`
