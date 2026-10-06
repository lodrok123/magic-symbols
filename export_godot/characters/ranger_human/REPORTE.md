# APROBADO: ranger_human  (`ranger_human`)

Fecha: 2026-10-02 18:59

## Archivos de entrada

- `Meshy_AI_medieval_ranger_remes_biped_Animation_Big_Wave_Hello_withSkin.glb` -> **big_wave_hello** (animacion nueva) | huesos 28, animaciones: Big_Wave_Hello
- `idle_001.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_03
- `idle_002.glb` -> **idle** (nombre de archivo; variante -> animacion idle_002) | huesos 28, animaciones: Idle_4
- `Meshy_AI_medieval_ranger_remes_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_medieval_ranger_remes_biped_Animation_Stand_Talking_Angry_withSkin.glb` -> **stand_talking_angry** (animacion nueva) | huesos 28, animaciones: Stand_Talking_Angry
- `Meshy_AI_medieval_ranger_remes_biped_Animation_Talk_with_Left_Hand_Raised_withSkin.glb` -> **talk_with_left_hand_raised** (animacion nueva) | huesos 28, animaciones: Talk_with_Left_Hand_Raised
- `Meshy_AI_medieval_ranger_remes_biped_Animation_Walking_withSkin.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking

## Avisos

- 2 archivos para 'idle': renombrados Meshy_AI_medieval_ranger_remes_biped_Animation_Idle_03_withSkin.glb -> idle_001.glb, Meshy_AI_medieval_ranger_remes_biped_Animation_Idle_4_withSkin.glb -> idle_002.glb. 'idle' = idle_001.glb; el resto son animaciones idle_002, idle_003...
- Animaciones nuevas: big_wave_hello, stand_talking_angry, talk_with_left_hand_raised

## Validaciones

- OK  animation_audit.json
- OK  big_wave_hello_atlas_validation.json
- OK  big_wave_hello_render_validation.json
- OK  idle_002_atlas_validation.json
- OK  idle_002_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  stand_talking_angry_atlas_validation.json
- OK  stand_talking_angry_render_validation.json
- OK  talk_with_left_hand_raised_atlas_validation.json
- OK  talk_with_left_hand_raised_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 7

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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\ranger_human\art\review`

- AVISO: 'BigWaveHello' pasa de 128 a 160 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 103 a 128.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle002' pasa de 336 a 420 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'StandTalkingAngry' pasa de 500 a 625 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'TalkWithLeftHandRaised' pasa de 112 a 140 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/ranger_human/`  |  Config: `pipeline/characters/ranger_human/character.json`
