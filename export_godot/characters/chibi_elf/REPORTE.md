# RECHAZADO: chibi_elf  (`chibi_elf`)

Fecha: 2026-10-05 11:27

## Por que

- build_character.py termino con codigo 2 (log: `C:\Users\paranda\Documents\magic-symbols\pipeline\inbox\_logs\chibi_elf_20261005_112713.log`)

## Archivos de entrada

- `charged_spell_cast_001.glb` -> **charged_spell_cast_001** (animacion nueva) | huesos 28, animaciones: Charged_Spell_Cast_1
- `charged_spell_cast_002.glb` -> **charged_spell_cast_002** (animacion nueva) | huesos 28, animaciones: Charged_Spell_Cast
- `idle_001.glb` -> **idle** (nombre de archivo) | huesos 28, animaciones: Idle_11
- `idle_002.glb` -> **idle** (nombre de archivo; variante -> animacion idle_002) | huesos 28, animaciones: Swim_Idle
- `mage_soell_cast_001.glb` -> **mage_soell_cast_001** (animacion nueva) | huesos 28, animaciones: mage_soell_cast_3
- `mage_soell_cast_002.glb` -> **mage_soell_cast_002** (animacion nueva) | huesos 28, animaciones: mage_soell_cast_4
- `mage_soell_cast_003.glb` -> **mage_soell_cast_003** (animacion nueva) | huesos 28, animaciones: mage_soell_cast
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Charged_Ground_Slam_withSkin.glb` -> **charged_ground_slam** (animacion nueva) | huesos 28, animaciones: Charged_Ground_Slam
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Collect_Object_withSkin.glb` -> **collect_object** (animacion nueva) | huesos 28, animaciones: Collect_Object
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Dead_withSkin.glb` -> **dead** (animacion nueva) | huesos 28, animaciones: Dead
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Face_Punch_Reaction_1_withSkin.glb` -> **face_punch_reaction** (animacion nueva) | huesos 28, animaciones: Face_Punch_Reaction_1
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_open_door_1_withSkin.glb` -> **open_door** (animacion nueva) | huesos 28, animaciones: open_door_1
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_ReadAndWrite_withSkin.glb` -> **readandwrite** (animacion nueva) | huesos 28, animaciones: 01a0e90d-b840-7220-9ee6-679f68dcbe4b, 01a0e90d-b840-7220-9ee6-679f68dcbe4b.001
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Roll_Dodge_withSkin.glb` -> **roll_dodge** (animacion nueva) | huesos 28, animaciones: Roll_Dodge
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Running_withSkin.glb` -> **run** (nombre de archivo) | huesos 28, animaciones: Running
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Stand_and_Drink_withSkin.glb` -> **stand_and_drink** (animacion nueva) | huesos 28, animaciones: Stand_and_Drink
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Stand_Talking_Angry_withSkin.glb` -> **stand_talking_angry** (animacion nueva) | huesos 28, animaciones: Stand_Talking_Angry
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_Swim_Forward_withSkin.glb` -> **swim_forward** (animacion nueva) | huesos 28, animaciones: Swim_Forward
- `Meshy_AI_Liora_the_Little_Leaf_biped_Animation_swimming_to_edge_withSkin.glb` -> **swimming_to_edge** (animacion nueva) | huesos 28, animaciones: swimming_to_edge
- `walk_001.glb` -> **walk** (nombre de archivo) | huesos 28, animaciones: Walking
- `walk_002.glb` -> **walk** (nombre de archivo; variante -> animacion walk_002) | huesos 28, animaciones: Walk_Turn_Right_Idle_Style

## Avisos

- 2 archivos para 'idle': renombrados idle_001.glb -> idle_001.glb, idle_002.glb -> idle_002.glb. 'idle' = idle_001.glb; el resto son animaciones idle_002, idle_003...
- 2 archivos para 'walk': renombrados walk_001.glb -> walk_001.glb, walk_002.glb -> walk_002.glb. 'walk' = walk_001.glb; el resto son animaciones walk_002, walk_003...
- 2 animaciones parecidas 'charged_spell_cast': charged_spell_cast_001.glb -> charged_spell_cast_001, charged_spell_cast_002.glb -> charged_spell_cast_002
- 3 animaciones parecidas 'mage_soell_cast': mage_soell_cast_001.glb -> mage_soell_cast_001, mage_soell_cast_002.glb -> mage_soell_cast_002, mage_soell_cast_003.glb -> mage_soell_cast_003
- Animaciones nuevas: charged_ground_slam, charged_spell_cast_001, charged_spell_cast_002, collect_object, dead, face_punch_reaction, mage_soell_cast_001, mage_soell_cast_002, mage_soell_cast_003, open_door, readandwrite, roll_dodge, stand_and_drink, stand_talking_angry, swim_forward, swimming_to_edge

## Validaciones


Atlas generados: 0

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
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review\cardinal_SENW.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review\proportion_grid_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review\scale_test_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review\silhouette_8dir.png`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review\sprite_8dir.png`

Entregables de arte:
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\model\npc_processed.glb`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\model\character_art.json`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\model\textures`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\renders`
- `C:\Users\paranda\Documents\magic-symbols\pipeline_output\chibi_elf\art\review`

- AVISO: 'Anim01a0e90d' pasa de 60 a 75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ChargedGroundSlam' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ChargedSpellCast001' pasa de 104 a 130 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'ChargedSpellCast002' pasa de 65 a 81.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'CollectObject' pasa de 144 a 180 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Dead' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'FacePunchReaction' pasa de 108 a 135 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle' pasa de 45 a 56.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Idle002' pasa de 72 a 90 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'MageSoellCast001' pasa de 80 a 100 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'MageSoellCast002' pasa de 53 a 66.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'MageSoellCast003' pasa de 55 a 68.75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'OpenDoor' pasa de 125 a 156.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Readandwrite' pasa de 60 a 75 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'RollDodge' pasa de 44 a 55 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Running' pasa de 16 a 20 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'StandAndDrink' pasa de 213 a 266.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'StandTalkingAngry' pasa de 500 a 625 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SwimForward' pasa de 108 a 135 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'SwimmingToEdge' pasa de 120 a 150 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walk002' pasa de 28 a 35 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- AVISO: 'Walking' pasa de 25 a 31.25 frames al exportar (x1.250). Suele ser un cambio de fps de escena en el E2E; afecta a la duracion de la animacion.
- Los atlas se generan desde el master, no desde el GLB procesado (pendiente de probar con Blender real).
- Mira las hojas de revision: las puertas detectan fallos tecnicos, no el gusto.


Salida: `pipeline_output/chibi_elf/`  |  Config: `pipeline/characters/chibi_elf/character.json`
