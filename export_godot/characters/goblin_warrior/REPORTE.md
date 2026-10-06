# APROBADO: goblin_warrior  (`goblin_warrior`)

Fecha: 2026-10-02 17:46

## Archivos de entrada

- `Meshy_AI_biped_Animation_Charged_Axe_Chop_withSkin.glb` -> **charged_axe_chop** (animacion nueva) | huesos 28, animaciones: Charged_Axe_Chop
- `Meshy_AI_biped_Animation_Double_Combo_Attack_withSkin.glb` -> **double_combo_attack** (animacion nueva) | huesos 28, animaciones: Double_Combo_Attack
- `Meshy_AI_biped_Animation_Electrocution_Reaction_withSkin.glb` -> **electrocution_reaction** (animacion nueva) | huesos 28, animaciones: Electrocution_Reaction
- `Meshy_AI_biped_Animation_Hit_Reaction_withSkin.glb` -> **hit_reaction** (animacion nueva) | huesos 28, animaciones: Hit_Reaction
- `Meshy_AI_biped_Animation_Idle_8_withSkin.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_8
- `Meshy_AI_biped_Animation_Left_Slash_withSkin.glb` -> **left_slash** (animacion nueva) | huesos 28, animaciones: Left_Slash
- `Meshy_AI_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_biped_Animation_Shot_and_Fall_Backward_withSkin.glb` -> **shot_and_fall_backward** (animacion nueva) | huesos 28, animaciones: Shot_and_Fall_Backward
- `Meshy_AI_biped_Animation_Thrust_Slash_withSkin.glb` -> **thrust_slash** (animacion nueva) | huesos 28, animaciones: Thrust_Slash
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Spear_Walk

## Avisos

- 2 archivos para 'walk': renombrados walk_001.glb -> walk_001.glb, walk_002.glb -> walk_002.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- Animaciones nuevas: charged_axe_chop, double_combo_attack, electrocution_reaction, hit_reaction, left_slash, shot_and_fall_backward, thrust_slash

## Validaciones

- OK  animation_audit.json
- OK  charged_axe_chop_atlas_validation.json
- OK  charged_axe_chop_render_validation.json
- OK  double_combo_attack_atlas_validation.json
- OK  double_combo_attack_render_validation.json
- OK  electrocution_reaction_atlas_validation.json
- OK  electrocution_reaction_render_validation.json
- OK  hit_reaction_atlas_validation.json
- OK  hit_reaction_render_validation.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  left_slash_atlas_validation.json
- OK  left_slash_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  shot_and_fall_backward_atlas_validation.json
- OK  shot_and_fall_backward_render_validation.json
- OK  thrust_slash_atlas_validation.json
- OK  thrust_slash_render_validation.json
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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\goblin_warrior\art\review`

- AVISO: 'ChargedAxeChop' pasa de 185 a 231.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'DoubleComboAttack' pasa de 68 a 85 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ElectrocutionReaction' pasa de 113 a 141.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'HitReaction' pasa de 40 a 50 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 192 a 240 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'LeftSlash' pasa de 77 a 96.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ShotAndFallBackward' pasa de 84 a 105 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ThrustSlash' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 27 a 33.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/goblin_warrior/`  |  Config: `pipeline/characters/goblin_warrior/character.json`
