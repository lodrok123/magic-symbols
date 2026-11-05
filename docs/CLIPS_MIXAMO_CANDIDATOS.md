# Clips de Mixamo que podríamos incluir (5/11/2026)

Sacados del índice `metadata.csv` del dataset Linzhan/Mixamo-Animations-Characters (2.317 clips con movimiento, esqueleto Y Bot de 65 huesos `mixamorig`, el mismo
que jugadora_base, elfo_base, goblin_base, marimanta y el chamán; los goblins chibi de 28 huesos también los aceptan, sin dedos). Probado el 5/11 (diario 385):
entran por `herramientas/mixamo_clips_a_glb.gd` → `ClipsFamilia.FUENTES` y la figura queda clavada a la fuente (rodillas y brazos a 0°).
Nombre = archivo de `animation_motion/` sin `.fbx`; entre corchetes, segundos. Los clips que entren al juego se bajan de mixamo.com (el dataset es un espejo «para investigación»).

Quitados de la búsqueda: deporte, armas de fuego, bailes y clips sentados o tumbados en cama (son unos 1.300 de los 2.317).

**5/11, hecho (diario 387):** los 16 en **negrita** están metidos como ALTERNATIVAS (Pablo: «las que veas buenas no las borres, déjalas porque pueden valer, como alt»):
ningún rol cambia de clip; cada uno va con su nombre `Mixamo_*` en el GLB único `arte/meshy/mixamo_clips.glb` (21 clips, bajados del espejo de Hugging Face) y se reparte por
familia en `ClipsFamilia` (jugadora → `FUENTE_CLIPS_MIXAMO`; goblins arquero y guerrero → `FUENTE_MIXAMO_GOBLIN` vía EXTRAS; Marimanta y chamán → `FUENTE_MIXAMO_ANCIANA`;
alquimista → `FUENTE_MIXAMO_NPC`). Se miran en **laboratorios/LabJugadora3D.tscn** (la jugadora: lista de clips con fuente al lado) y en **laboratorios/LabHumanoide3D.tscn**
con «COMO EL JUEGO» (que ahora se enciende solo en esos modelos). Para pasar uno a rol del juego: renombrar el destino al rol de `Pj3D.SINONIMOS` (o apuntarlo en `CLIPS_DE`).
Nombres: CastArea1/2 · Curar · GolpeGrande · MorirAtras · Incorporarse · EmpujePesado · Beber · AbrirTapa · TensarArco · Disparar · GritoGuerra · Rezar · Tabernero.
**5/11, revisión de Pablo (diario 388):** Voltereta y Beber pasan a ser los roles `roll` y `drink` de la jugadora; los casts y Curar se quedan como alternativas para otros hechizos
(muro, pilar…). Old_Man_Idle y Old_Man_Walk se RETIRAN del chamán y Marimanta (manos en la barriga: sueltan el bastón plantado y el andar parece gesticular); siguen en el GLB.

## 1. Jugadora (héroe)

| Rol en Pj3D | Hoy | Candidatos Mixamo |
|---|---|---|
| cast (genérico) | MageSoellCast003 (Meshy) | **Two_Hand_Spell_Casting** [3,4] (ya enganchado como Mixamo_CastDosManos), Standing_2H_Magic_Attack_01 [2,7] «a dos manos hacia delante», Spell_Casting, Magic_Spell_Casting |
| cast_proyectil | MageSoellCast003 | Standing_1H_Cast_Spell_01 [2,3] «una mano hacia arriba», Standing_1H_Magic_Attack_01/02/03 [3,3] «barrido de una mano», Casting_Spell [7,7] «conjura y lanza» (largo, recortar) |
| cast_corro | ChargedGroundSlam | **Standing_2H_Magic_Area_Attack_01/02** [3,3] «recoge y estalla en área» |
| cast_columna | ChargedSpellCast002 | Wide_Arm_Spell_Casting, Standing_1H_Magic_Attack_03 «barrido hacia arriba» |
| cast_muro | MageSoellCast002 | Standing_2H_Magic_Attack_02..05 (variantes a dos manos) |
| curar / nuevo | — | **Magic_Heal** [2,7] «curación con una mano» |
| idle | Idle (Meshy) | Breathing_Idle [10], Idle_2 [16,7] «cambio de peso», Happy_Idle [3], Bored [10,7] «aburrida», Looking_2 [8] «mira a lo lejos», Yawn [8,4] «bosteza» (idles de espera para cuando el jugador no hace nada) |
| walk / run | Walking / Running | Walking_21 «estándar», Happy_Walk [1,1], Sad_Walk [1,5], Running_8 [0,7] «rápido», Jogging [2,6], Walk_Strafe_Left/Right [1,5], Standing_Walk_Back [1,2] |
| hit | FacePunchReaction | **Standing_React_Large_From_Front_2** [1,4], Standing_React_Small_From_Front [1,2], Standing_React_Large_From_Back [3,2], _From_Left / _From_Right (golpe por dirección), Hit_To_Body [1,2] |
| death | Dead | **Falling_Back_Death** [2,6], Flying_Back_Death [3,1] «sale volando hacia atrás» (para la onda expansiva), Two_Handed_Sword_Death_2 [2,6] «cae hacia delante», Dying_9 [2,6] «cae de rodillas» |
| roll | RollDodge | **Stand_To_Roll** [2,4] (enganchado como Mixamo_Voltereta; avanza ~4 alturas de cadera), Sprinting_Forward_Roll [1,2], Quick_Roll_To_Run [1,4], Dodging_Right [1,5] «esquiva lateral en el sitio», Dodging_Back [2,7] |
| swim | SwimForward | **Swimming** [4,5] (Mixamo_Nadar), Swimming_To_Edge, **Treading_Water** [3] (Mixamo_Flotar, para estar quieta en el agua), Falling_Into_Pool [2,3] «pierde el equilibrio y cae al agua» |
| empujado / levantarse | de goblin_behit_flyup | Shove_Reaction_2 [3] «empujón de pie», Knocked_Down, **Getting_Up** [2,7] «se levanta tras caer», Standing_Up_2 [1,7], Stand_Up_2 [8,3] «desde la espalda» (largo) |
| empujar (bloques) | Empujar (Meshy) | **Push** [1,7] «empuja objeto pesado» (bucle), Push_Start / Push_Stop [2,6], Pull_Heavy_Object [1,1] + Start/Stop «tira de un objeto» |
| levantar / cargar / lanzar | clips de carga (Meshy) | Lifting_Object [11,5] «levanta objeto pesado a dos manos», Picking_Up [9,6], Throw [2,2] «lanza desde pose normal», Throw_Object [7,2] «coge y lanza», Pick_Up_Item [1,2] «recoge al paso» |
| beber poción (pendiente) | — | **Drinking** [8,9] (recortar), Drinking_Fountain [10,9] |
| abrir cofre | AbrirCofre (Meshy) | **Opening_A_Lid** [9] «abre la tapa de un cofre», Opening_Door_Inwards [7,7] «abre una puerta» |
| saltos / caídas (si entran) | — | Jump [2,2] «en el sitio», Jump_3 [1] «corriendo», Jumping_Down_12 [3,3] «baja de un nivel», Falling_Idle [0,7] + Landing [2,1], Hard_Landing [2], Jumping_11 «sube a una plataforma» |
| escalar (si entra) | — | Climbing_Ladder [0,8], Climbing_Up_Wall [2], Braced_Hang [1,3] + Braced_Hang_To_Crouch [1,2] «cuelga y sube», Idle_To_Braced_Hang [1,3] |
| sigilo (si entra) | — | Sneak_Walk_2 [1,1] «ninja femenino», Crouch_Idle_2 [1,4], Crouch_Walk_Forward_2 [1,2], Standing_Idle_To_Crouch [1] |
| celebrar / emociones | cheer, saludo | Victory [8,6], Cheering, Clapping [1,2], Waving_Gesture [1,5], Thankful [3], Crying [7,4], Scared, Laughing [9,8], Shrugging [2], Pouting [3], Wiping_Sweat [2,7] «se seca el sudor» (tras cargar) |
| mano quemada / dolor | por código | Pain_Gesture [1,8] «dolor de espalda», Injured_Idle [9,4] «herida», Injured_Walk [1,7] |
| trabajo (si la jugadora lo hace) | — | Plant_A_Plant [7,6] «planta de rodillas», Pull_Plant [8,3] «arranca una planta», Pick_Fruit_2 [7,1] «recoge del suelo», Kneel [10,8] «se calienta las manos en la hoguera» |

No hay en Mixamo: **leer un libro** (Readandwrite sigue de Meshy), **ahogarse** (sigue el procedural), **mano quemada**, **trazar/clavar runas**.

## 2. Goblins (guerrero, asesino, arquero, base)

| Rol | Candidatos |
|---|---|
| attack cuerpo a cuerpo | Stable_Sword_Inward_Slash [2,2], Sword_And_Shield_Slash_3 [1,7] «cruzado», One_Hand_Club_Combo [8,3] «garrote a una mano», Two_Hand_Club_Combo [7,5], Standing_Melee_Attack_360_Low [2,5] «giro bajo con hacha», Stabbing [2,4] «puñalada» (asesino), Punching [0,9], Kicking [2,2] |
| guardia / idle de combate | Fight_Idle [2,4], Bouncing_Fight_Idle [3], Ready_Idle [2,5], Standing_Idle_3 «con hacha», Sword_And_Shield_Idle_4 [2,6] |
| idle NPC / vigilante | Standing_Torch_Idle_02/03 «mira alrededor» (el asesino lleva antorcha), Unarmed_Idle_Looking_Ver._1 [11,3], Orc_Idle [6,7] «orco» (pesado, para el guerrero) |
| sigilo (asesino) | Sneak_Walk [0,9], Sneaking_Forward [1,7], Crouch_Torch_Walk_Forward [1,1] «agachado con antorcha», Crouch_Torch_Idle_01 [6,9], Crouch_Look_Around_Corner [3] |
| arquero | **Standing_Draw_Arrow** [1,1] «carga la flecha», **Standing_Aim_Recoil** [0,8] «dispara», Standing_Aim_Walk_Back [1,5] (walk_back apuntando), Standing_Aim_Walk_Forward/Left/Right, Crouch_Idle_01 «agachado con arco», Standing_Idle_02_Looking «mira alrededor con arco», Standing_Dodge_Left/Right/Backward [1..1,7] |
| hit | Standing_React_Small_From_Front_02 «con arco», Standing_React_Large_From_Front, Standing_React_Large_Gut [1,6], Hit_To_Body_3 [1,4] |
| death | Standing_Death_Forward_01 [3,2] «con arco, hacia delante», Standing_Death_Backward_01_2 [3,1], Sword_And_Shield_Death [2,3], Falling_Back_Death_2 [2,2] |
| taunt / provocar | **Standing_Taunt_Battlecry** [7,1] «grito de guerra con hacha», Standing_Taunt_Chest_Thump [2,9] «se golpea el pecho», Taunt_2 [3,3], Insult [2,7], Shake_Fist [2,5] |
| trabajo (goblin base) | chop/dig siguen de Tripo; de Mixamo: Wheelbarrow_Walk_2 [1] «carretilla», Wheelbarrow_Dump [7,9], Lifting_Object, Pull_Plant_2 «de rodillas» |
| huir / asustarse | Running_2 [1,7] «se gira y huye en plan tonto», Running_5 [1,1] «carrera tonta», Scared [10,1], Jump_Away [2,7] «salta para esquivar una explosión» |
| bloquear (escudo) | Sword_And_Shield_Block_Idle [1,4], Standing_Block_Idle_2 «con hacha», Block [2,9] «cubre el pecho con los brazos» |
| empujado / levantarse | Livershot_Knockdown [2,8] «cae», Sweep_Fall [2,5] «le barren los pies», Getting_Up [2,7], Zombie_Stand_Up_* (torpe) |
| sacar / guardar arma | Draw_Sword_2 [0,8], Sheath_Sword_1 [1,3], Withdrawing_Sword [1,5] |

## 3. Marimanta y chamán (ancianas)

- idle: ~~Old_Man_Idle~~ [12,2] «anciano de pie» (probado 5/11 y retirado: manos en la barriga, no sujeta el bastón), Injured_Idle [9,4]
- walk: ~~Old_Man_Walk~~ [1,3] «arrastra los pies» (probado 5/11 y retirado: mismo problema, parece gesticular), Injured_Walk_2 [1,2] «cojea de la pierna derecha», Walking_22 [1,8] «cuidadoso»
- talk: Talking_2 [10,3] «conversación general», Standing_Arguing [27,4] «discute» (recortar), Head_Nod_Yes [2,6], Annoyed_Head_Shake [2,6], Pointing_3 [2,8], Dismissing_Gesture [2,3] «te despide con la mano», Angry_Point [2,5]
- pensar / tramar: Thoughtful_Head_Nod [3], Thoughtful_Head_Shake [3,1], Look_Away_Gesture [2,4] «mira a otro lado sarcástica»
- rezar / ritual (chamán): **Praying_2** [3,3] «reza de pie balanceándose», Praying_4 [2] «de rodillas», Praying_5 [6,7] «cae de rodillas», Kneeling_Down [2,8], Sword_And_Shield_Power_Up [2,4] «se carga de poder» (para el trazado de runas, sin la espada)
- cast del chamán: Standing_1H_Cast_Spell_01 «una mano arriba», Magic_Heal, Casting_Spell «conjura y lanza» (recortar a la suelta)
- dolor / cansancio: Pain_Gesture [1,8], Wiping_Sweat [2,7], Yawn [8,4]

## 4. NPC del pueblo (librera, alquimista, maestro, guardabosques, campesinos)

- idle: Breathing_Idle, Idle_2 «cambio de peso», Bored, Looking_2, Neutral_Idle [8,8], Happy [10]
- talk: Talking_2, Hands_Forward_Gesture [3,1], Happy_Hand_Gesture [3], Acknowledging [2], Agreeing_2 [1,9], Shrugging [2], Thankful [3], Quick_Formal_Bow / Quick_Informal_Bow [2,8] «reverencia»
- oficios: **Bartending** [13,6] «sirve bebidas» (alquimista), Opening [11] «abre y cierra un armario», Searching_Files_High [9,8] «rebusca en un cajón alto» (librera), Looking_Through_Files_Low [15,2], Plant_Tree [9,3], Plant_A_Plant, Pull_Plant, Pick_Fruit_3 «fruta baja», Petting_Animal [14,2] «acaricia a un animal» (guardabosques con el lince), Fishing_Cast [8,8] «pesca», Kneel «hoguera», Sleeping_Idle [6,9] «duerme», Drinking
- saludo: Waving_Gesture [1,5], Salute [2,9], Clapping
- emociones: Crying, Laughing, Angry [19,2], Yelling [7,9], Defeated [6,8] «frustración», Victory [8,6]
- maestro / tutorial: Pointing_Gesture [2], Pointing_3 «señala con el brazo doblado», Beckoning (sentado), Intercepting [2] «te para con la mano», Button_Pushing [3,3]

## 5. Lo que Mixamo no tiene

- Cuadrúpedos (loberno, lince, canouro, gato): ninguno; siguen con el esqueleto Wolf de Meshy.
- Gólem de piedra: nada «pesado de roca»; lo más parecido es Orc_Idle, Walking_16 «brutal» y Running_6 «con peso».
- Leer un libro, ahogarse, trazar y clavar runas, mano quemada, resbalar en hielo.

## Cómo meter uno (flujo probado)

1. Elegirlo aquí (o en `metadata.csv`) y bajarlo de mixamo.com «Without Skin», FBX binario, 30 fps, «In Place» si es de locomoción.
2. `tools\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://herramientas/mixamo_clips_a_glb.gd -- arte/meshy/<grupo>_clips.glb <clip1.fbx> <clip2.fbx> ...` (incluir siempre un Idle de Mixamo como «referencia»).
3. Añadir la fuente en `ClipsFamilia.FUENTES[<modelo>]` con `"referencia": "Idle"`, `"centrar"` en los que vengan desviados y `"clips": {rol: nombre}`.
4. `prueba_mixamo_clips.gd` (figura y suelo) y `captura_mixamo_clips.gd` (fotos) para comprobarlo.
