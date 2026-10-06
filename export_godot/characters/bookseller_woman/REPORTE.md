# APROBADO: bookseller_woman  (`bookseller_woman`)

Fecha: 2026-10-02 18:54

## Archivos de entrada

- `Meshy_AI_Adventurer_Girl_biped_Animation_Collect_Object_withSkin.glb` -> **collect_object** (animacion nueva) | huesos 28, animaciones: Collect_Object
- `Meshy_AI_Adventurer_Girl_biped_Animation_Dead_withSkin.glb` -> **dead** (animacion nueva) | huesos 28, animaciones: Dead
- `Meshy_AI_Adventurer_Girl_biped_Animation_Female_Crouch_Pick_Gun_Point_Forward_withSkin.glb` -> **female_crouch_pick_gun_point_forward** (animacion nueva) | huesos 28, animaciones: Female_Crouch_Pick_Gun_Point_Forward
- `Meshy_AI_Adventurer_Girl_biped_Animation_Idle_9_withSkin.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_9
- `Meshy_AI_Adventurer_Girl_biped_Animation_open_door_1_withSkin.glb` -> **open_door** (animacion nueva) | huesos 28, animaciones: open_door_1
- `Meshy_AI_Adventurer_Girl_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_Adventurer_Girl_biped_Animation_Sit_Cross_Legged_withSkin.glb` -> **sit_cross_legged** (animacion nueva) | huesos 28, animaciones: Sit_Cross_Legged
- `Meshy_AI_Adventurer_Girl_biped_Animation_Stand_Talking_Angry_withSkin.glb` -> **stand_talking_angry** (animacion nueva) | huesos 28, animaciones: Stand_Talking_Angry
- `Meshy_AI_Adventurer_Girl_biped_Animation_Talk_with_Left_Hand_Raised_withSkin.glb` -> **talk_with_left_hand_raised** (animacion nueva) | huesos 28, animaciones: Talk_with_Left_Hand_Raised
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walking_Woman

## Avisos

- 2 archivos para 'walk': renombrados Meshy_AI_Adventurer_Girl_biped_Animation_Walking_withSkin.glb -> walk_001.glb, Meshy_AI_Adventurer_Girl_biped_Animation_Walking_Woman_withSkin.glb -> walk_002.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- Animaciones nuevas: collect_object, dead, female_crouch_pick_gun_point_forward, open_door, sit_cross_legged, stand_talking_angry, talk_with_left_hand_raised
- Animacion OMITIDA 'dead': W: Alpha toca un borde del frame (clipping); W: Margen mínimo 0px < requerido 4px

## Validaciones

- OK  animation_audit.json
- OK  collect_object_atlas_validation.json
- OK  collect_object_render_validation.json
- OK  female_crouch_pick_gun_point_forward_atlas_validation.json
- OK  female_crouch_pick_gun_point_forward_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  model_rig_validation.json
- OK  open_door_atlas_validation.json
- OK  open_door_render_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  sit_cross_legged_atlas_validation.json
- OK  sit_cross_legged_render_validation.json
- OK  stand_talking_angry_atlas_validation.json
- OK  stand_talking_angry_render_validation.json
- OK  talk_with_left_hand_raised_atlas_validation.json
- OK  talk_with_left_hand_raised_render_validation.json
- OK  walk_002_atlas_validation.json
- OK  walk_002_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 10

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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\bookseller_woman\art\review`

- AVISO: 'CollectObject' pasa de 144 a 180 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Dead' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'FemaleCrouchPickGunPointForward' pasa de 59 a 73.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 48 a 60 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'OpenDoor' pasa de 125 a 156.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SitCrossLegged' pasa de 229 a 286.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'StandTalkingAngry' pasa de 500 a 625 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'TalkWithLeftHandRaised' pasa de 112 a 140 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 24 a 30 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/bookseller_woman/`  |  Config: `pipeline/characters/bookseller_woman/character.json`
