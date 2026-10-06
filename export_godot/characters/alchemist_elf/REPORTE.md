# APROBADO: alchemist_elf  (`alchemist_elf`)

Fecha: 2026-10-05 17:28

## Archivos de entrada

- `Meshy_AI_Emberleaf_Alchemist_biped_Animation_Hand_on_Hip_Gesture_withSkin.glb` -> **hand_on_hip_gesture** (animacion nueva) | huesos 28, animaciones: Hand_on_Hip_Gesture
- `Meshy_AI_Emberleaf_Alchemist_biped_Animation_Idle_4_withSkin.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_4
- `Meshy_AI_Emberleaf_Alchemist_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_Emberleaf_Alchemist_biped_Animation_Stand_Talking_Angry_withSkin.glb` -> **stand_talking_angry** (animacion nueva) | huesos 28, animaciones: Stand_Talking_Angry
- `Meshy_AI_Emberleaf_Alchemist_biped_Animation_Walking_withSkin.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking

## Avisos

- Animaciones nuevas: hand_on_hip_gesture, stand_talking_angry

## Validaciones

- OK  animation_audit.json
- OK  hand_on_hip_gesture_atlas_validation.json
- OK  hand_on_hip_gesture_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  stand_talking_angry_atlas_validation.json
- OK  stand_talking_angry_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 5

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
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review\cardinal_SENW.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review\proportion_grid_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review\scale_test_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review\silhouette_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\model\npc_processed.glb`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\model\character_art.json`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\model\textures`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\renders`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\alchemist_elf\art\review`

- AVISO: 'HandOnHipGesture' pasa de 120 a 150 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 336 a 420 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'StandTalkingAngry' pasa de 500 a 625 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas salen del master, no de este GLB (para cambiarlo: "atlas_desde": "arte" en config/ms.json).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/alchemist_elf/`  |  Config: `pipeline/characters/alchemist_elf/character.json`
