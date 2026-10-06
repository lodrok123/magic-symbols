# APROBADO: master_elf  (`master_elf`)

Fecha: 2026-10-02 17:01

## Archivos de entrada

- `Meshy_AI_male_elf_rigged_biped_Animation_Idle_prueba_withSkin.glb` -> **idle** (nombre de archivo) | huesos 23, animaciones: Walking
- `Meshy_AI_male_elf_rigged_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 23, animaciones: Running
- `Meshy_AI_male_elf_rigged_biped_Animation_Walking_withSkin.glb` -> **walk** (nombre de archivo) | huesos 23, animaciones: Walking

## Validaciones

- OK  animation_audit.json
- OK  idle_atlas_validation.json
- OK  idle_render_validation.json
- OK  model_rig_validation.json
- OK  run_atlas_validation.json
- OK  run_render_validation.json
- OK  walk_atlas_validation.json
- OK  walk_render_validation.json

Atlas generados: 3

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
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review\cardinal_SENW.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review\proportion_grid_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review\scale_test_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review\silhouette_8dir.png`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\model\npc_processed.glb`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\model\character_art.json`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\model\textures`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\renders`
- `C:\Users\pablo\Documents\magic-symbols\pipeline_output\master_elf\art\review`

- AVISO: 'Idle' pasa de 26 a 32.5 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 17 a 21.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 26 a 32.5 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.

Salida: `pipeline_output/master_elf/`  |  Config: `pipeline/characters/master_elf/character.json`
