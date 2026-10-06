# APROBADO: goblin_archer  (`goblin_archer`)

Fecha: 2026-10-02 17:37

## Archivos de entrada

- `archery_shot_001.glb` -> **archery_shot_001** (animacion nueva) | huesos 28, animaciones: Archery_Shot_1
- `archery_shot_002.glb` -> **archery_shot_002** (animacion nueva) | huesos 28, animaciones: Archery_Shot
- `Meshy_AI_goblin_archer_3d_biped_Animation_Electrocution_Reaction_withSkin.glb` -> **electrocution_reaction** (animacion nueva) | huesos 28, animaciones: Electrocution_Reaction
- `Meshy_AI_goblin_archer_3d_biped_Animation_Face_Punch_Reaction_withSkin.glb` -> **face_punch_reaction** (animacion nueva) | huesos 28, animaciones: Face_Punch_Reaction
- `Meshy_AI_goblin_archer_3d_biped_Animation_Female_Bow_Charge_Left_Hand_withSkin.glb` -> **female_bow_charge_left_hand** (animacion nueva) | huesos 28, animaciones: Female_Bow_Charge_Left_Hand
- `Meshy_AI_goblin_archer_3d_biped_Animation_Idle_02_withSkin.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_02
- `Meshy_AI_goblin_archer_3d_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_goblin_archer_3d_biped_Animation_Shot_in_the_Back_and_Fall_withSkin.glb` -> **shot_in_the_back_and_fall** (animacion nueva) | huesos 28, animaciones: Shot_in_the_Back_and_Fall
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walk_Backward_with_Bow_1
- `walk_003.glb` -> **walk** (nombre de archivo; variante -> animacion walk_003) | huesos 28, animaciones: Walk_Backward_with_Bow_Aimed
- `walk_004.glb` -> **walk** (nombre de archivo; variante -> animacion walk_004) | huesos 28, animaciones: Walk_Forward_with_Bow_Aimed

## Avisos

- 4 archivos para 'walk': renombrados walk_001.glb -> walk_001.glb, walk_002.glb -> walk_002.glb, walk_003.glb -> walk_003.glb, walk_004.glb -> walk_004.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- 2 animaciones parecidas 'archery_shot': archery_shot_001.glb -> archery_shot_001, archery_shot_002.glb -> archery_shot_002
- Animaciones nuevas: archery_shot_001, archery_shot_002, electrocution_reaction, face_punch_reaction, female_bow_charge_left_hand, shot_in_the_back_and_fall
- Animacion OMITIDA 'walk_002': root motion horizontal 1.104700 excede tolerancia 0.010000
- Animacion OMITIDA 'female_bow_charge_left_hand': SW: Alpha toca un borde del frame (clipping); SW: Margen mínimo 0px < requerido 4px
- Animacion OMITIDA 'shot_in_the_back_and_fall': S: Alpha toca un borde del frame (clipping); S: Margen mínimo 0px < requerido 4px

## Validaciones

- OK  animation_audit.json
- OK  archery_shot_001_atlas_validation.json
- OK  archery_shot_001_render_validation.json
- OK  archery_shot_002_atlas_validation.json
- OK  archery_shot_002_render_validation.json
- OK  electrocution_reaction_atlas_validation.json
- OK  electrocution_reaction_render_validation.json
- OK  face_punch_reaction_atlas_validation.json
- OK  face_punch_reaction_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  walk_003_atlas_validation.json
- OK  walk_003_render_validation.json
- OK  walk_004_atlas_validation.json
- OK  walk_004_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 9

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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_archer\art\review`

- AVISO: 'ArcheryShot001' pasa de 24 a 30 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ArcheryShot002' pasa de 120 a 150 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ElectrocutionReaction' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'FacePunchReaction' pasa de 68 a 85 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'FemaleBowChargeLeftHand' pasa de 12 a 15 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 45 a 56.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ShotInTheBackAndFall' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 36 a 45 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk003' pasa de 36 a 45 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk004' pasa de 29 a 36.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/goblin_archer/`  |  Config: `pipeline/characters/goblin_archer/character.json`
